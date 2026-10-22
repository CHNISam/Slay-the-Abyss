// Run after build:data and build:ui. Only the MCP workspace copy is written.
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { requireStartupEvidence } from './native-playtest-evidence.mjs';

const [baseMap, output = '.artifacts/native-candidate', mode] = process.argv.slice(2);
if (!baseMap) throw new Error('Usage: node scripts/build-native-candidate.mjs <base.gil> [output-directory]');
const workspace = resolve(output);
const toolRoot = process.env.MILIASTRA_MCP_ROOT || 'D:/MiliastraTools/genshin-miliastra-mcp';
const sdk = join(toolRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const { Client } = await import(pathToFileURL(join(sdk, 'index.js')));
const { StdioClientTransport } = await import(pathToFileURL(join(sdk, 'stdio.js')));
const layout = JSON.parse(readFileSync('build/lua/game-ui.json', 'utf8'));
function checkTree(control) {
  if ((control.children ?? []).length > 60) throw new Error(`MCP child limit: ${control.name}`);
  for (const child of control.children ?? []) checkTree(child);
}
layout.controls.forEach(checkTree);
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
  if (data.mapPath) mapPath = data.mapPath;
  return data;
}
try {
  for (const uri of ['miliastra://workflow', 'miliastra://platform-rules']) {
    const resource = await client.readResource({ uri });
    writeFileSync(join(workspace, `${uri.split('//')[1]}.json`), JSON.stringify(resource, null, 2));
  }
  for (const directory of ['src/lua', 'build/lua']) {
    for (const file of readdirSync(directory).filter(file => file.endsWith('.lua') &&
      !['abyss_ui_layout.lua', 'abyss_map_controls.lua'].includes(file))) {
      await call('scene_set_client_script', { mapPath, name: basename(file, '.lua'),
        sourceFile: resolve(directory, file), outputName: 'abyss-full-game-test' });
    }
  }
  await call('scene_add_client_ui', { ...layout, mapPath, outputName: 'abyss-full-game-test' });
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
      screenshotsAt: [2, 8], clientScriptLog: true });
    const deadline = Date.now() + 240000;
    let status;
    do {
      status = await call('playtest_status', { runId: started.runId, waitSeconds: 15 });
    } while (status.state === 'running' && Date.now() < deadline);
    requireStartupEvidence(status, startedAt);
    console.log('Official run and client log collected. Review its screenshots and gameplay before accepting smoke.');
  }
} finally { await client.close(); }
