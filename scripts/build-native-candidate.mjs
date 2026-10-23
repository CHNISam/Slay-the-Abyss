// Run after build:data and build:ui. Only the MCP workspace copy is written.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { requireStartupEvidence } from './native-playtest-evidence.mjs';
import { settlementGraphSource } from './settlement-graph.mjs';
import { candidateScriptFiles } from './native-candidate-scripts.mjs';

const [baseMap, output = '.artifacts/native-candidate', mode] = process.argv.slice(2);
if (!baseMap) throw new Error('Usage: node scripts/build-native-candidate.mjs <base.gil> [output-directory]');
const workspace = resolve(output);
const toolRoot = process.env.MILIASTRA_MCP_ROOT || 'D:/MiliastraTools/genshin-miliastra-mcp';
const sdk = join(toolRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const { Client } = await import(pathToFileURL(join(sdk, 'index.js')));
const { StdioClientTransport } = await import(pathToFileURL(join(sdk, 'stdio.js')));
const layout = JSON.parse(readFileSync('build/lua/game-ui.json', 'utf8'));
const templates = JSON.parse(readFileSync('build/lua/game-ui-templates.json', 'utf8'));
function checkTree(control) {
  if ((control.children ?? []).length > 60) throw new Error(`MCP child limit: ${control.name}`);
  for (const child of control.children ?? []) checkTree(child);
}
layout.controls.forEach(checkTree);
templates.forEach(checkTree);
const scripts = candidateScriptFiles(); // Preflight before any workspace or tool writes.
mkdirSync(workspace, { recursive: true });
const client = new Client({ name: 'abyss-native-candidate', version: '1.0' });
await client.connect(new StdioClientTransport({ command: process.execPath,
  args: [join(toolRoot, 'src/server.mjs')], env: { ...process.env,
    MILIASTRA_WORKSPACE: workspace, MILIASTRA_ALLOW_LIVE_WRITE: '0' } }));
let mapPath = resolve(baseMap);
async function call(name, args) {
  const result = await client.callTool({ name, arguments: args }, undefined, { timeout: 120000 });
  writeFileSync(join(workspace, `${name}-${args.name || 'result'}.json`), JSON.stringify(result, null, 2));
  if (result.isError) throw new Error(JSON.stringify(result));
  const data = result.structuredContent ?? JSON.parse(result.content.find(item => item.type === 'text').text);
  if (data.error) throw new Error(JSON.stringify(data));
  if (data.mapPath) mapPath = data.mapPath;
  return data;
}
try {
  for (const uri of ['miliastra://workflow', 'miliastra://platform-rules']) {
    const resource = await client.readResource({ uri });
    writeFileSync(join(workspace, `${uri.split('//')[1]}.json`), JSON.stringify(resource, null, 2));
  }
  for (const script of scripts) {
    await call('scene_set_client_script', { mapPath, ...script, outputName: 'abyss-full-game-test' });
  }
  for (const template of templates) {
    await call('scene_add_client_template', { template, mapPath, replace: true, outputName: 'abyss-full-game-test' });
  }
  await call('scene_add_client_ui', { ...layout, mapPath, replace: true, outputName: 'abyss-full-game-test' });
  await call('scene_set_player_count', { mapPath, min: 1, max: 1, outputName: 'abyss-full-game-test' });
  // Read the workspace copy after script/UI writes, so inspect_map's configured
  // root restriction also works when the input was an external saved map.
  const inspected = await call('inspect_map', { mapPath });
  const listedSignals = await call('scene_list_signals', { mapPath });
  if (!Array.isArray(inspected.graphs) || !Array.isArray(listedSignals.signals)
      || listedSignals.signals.some(name => typeof name !== 'string')) {
    throw new Error('Cannot read settlement graph and signal inventory; refusing to infer missing resources');
  }
  const matches = inspected.graphs.filter(graph => graph.name === '_GSTS_ABYSS_SETTLEMENT');
  if (matches.length > 1 || matches.some(graph => graph.type !== 20000 || !graph.writable
      || !Number.isSafeInteger(graph.id) || graph.id <= 0 || graph.id > 0xffffffff)) {
    throw new Error('Existing settlement graph is ambiguous, incompatible or not writable');
  }
  for (const name of ['ABYSS_WIN', 'ABYSS_LOSE']) {
    if (!listedSignals.signals.includes(name)) {
      await call('scene_add_signal', { mapPath, name, outputName: 'abyss-full-game-test' });
    }
  }
  const graph = matches.length
    ? { graphId: matches[0].id, name: matches[0].name }
    : await call('scene_add_graph', { mapPath, name: 'ABYSS_SETTLEMENT', kind: 'server', outputName: 'abyss-full-game-test' });
  const code = settlementGraphSource({ id: graph.graphId, name: graph.name });
  writeFileSync(join(workspace, 'settlement.ts'), code);
  const compiled = await call('write_graphs', { mapPath, graphs: [{ graphId: graph.graphId, code }] });
  if (compiled.failed || compiled.error || compiled.errors?.length || compiled.written?.length !== 1) {
    throw new Error('Settlement graph did not compile/write completely; see write_graphs-result.json');
  }
  const checked = await call('scene_check_client', { mapPath });
  if (!checked.ok || checked.errors) throw new Error('Candidate failed client checks; see scene_check_client-result.json');
  writeFileSync(join(workspace, 'candidate.json'), JSON.stringify({ mapPath,
    liveWriteEnabled: false, errors: checked.errors, warnings: checked.warnings,
    officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED' }, null, 2));
  console.log(`Full game candidate: ${mapPath}`);
  console.log('Copy written and statically checked. Official import and playtest remain required.');
  if (mode === '--playtest') {
    // Subscription is per imported save. Always request it; never ask the user
    // to remember a checkbox or treat a run without log evidence as passed.
    const startedAt = Date.now();
    const started = await call('playtest_start', { mapPath, durationSeconds: 12,
      screenshotsAt: [2, 8], clientScriptLog: true, graphName: graph.name });
    const deadline = Date.now() + 240000;
    let status;
    do {
      status = await call('playtest_status', { runId: started.runId, waitSeconds: 15 });
    } while (status.state === 'running' && Date.now() < deadline);
    requireStartupEvidence(status, startedAt);
    console.log('Official run and client log collected. Review its screenshots and gameplay before accepting smoke.');
  }
} finally { await client.close(); }
