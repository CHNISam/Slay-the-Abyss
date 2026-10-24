// Explicit audio audition candidate. Never imported or played automatically.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import { nativeBgmGraphSource, nativeBgmSignals } from './native-bgm-graph.mjs';

const [base, directory = '.artifacts/native-bgm-candidate'] = process.argv.slice(2);
if (!base) throw new Error('Usage: node scripts/build-native-bgm-candidate.mjs <full-game-base.gil> [output-directory]');
const baseMap = resolve(base), workspace = resolve(directory);
const hash = file => createHash('sha256').update(readFileSync(file)).digest('hex');
const baseSha256 = hash(baseMap);
const scripts = ['abyss_bgm', 'abyss_game_ui', 'abyss_ui'].map(name => ({ name,
  source: readFileSync(new URL(`../src/lua/${name}.lua`, import.meta.url), 'utf8'),
  ...(name === 'abyss_ui' ? { variables: [{ name: 'nativeBgmEnabled', type: 'boolean', value: true }] } : {}) }));
const toolRoot = process.env.MILIASTRA_MCP_ROOT || 'D:/MiliastraTools/genshin-miliastra-mcp';
const sdk = join(toolRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const { Client } = await import(pathToFileURL(join(sdk, 'index.js')));
const { StdioClientTransport } = await import(pathToFileURL(join(sdk, 'stdio.js')));
mkdirSync(workspace, { recursive: true });
const client = new Client({ name: 'abyss-native-bgm-candidate', version: '1' });
await client.connect(new StdioClientTransport({ command: process.execPath,
  args: [join(toolRoot, 'src/server.mjs')], env: { ...process.env,
    MILIASTRA_WORKSPACE: workspace, MILIASTRA_ALLOW_LIVE_WRITE: '0' } }));
let mapPath = baseMap;
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
    writeFileSync(join(workspace, `${uri.split('//')[1]}.json`), JSON.stringify(await client.readResource({ uri }), null, 2));
  }
  for (const name of Object.values(nativeBgmSignals)) await call('scene_add_signal', { mapPath, name, outputName: 'abyss-bgm-test' });
  for (const script of scripts) await call('scene_set_client_script', { mapPath, ...script, outputName: 'abyss-bgm-test' });
  const graph = await call('scene_add_graph', { mapPath, name: 'ABYSS_BGM', kind: 'server', outputName: 'abyss-bgm-test' });
  const code = nativeBgmGraphSource({ id: graph.graphId, name: graph.name });
  writeFileSync(join(workspace, 'bgm.ts'), code);
  const compiled = await call('write_graphs', { mapPath, graphs: [{ graphId: graph.graphId, code }] });
  if (compiled.failed || compiled.error || compiled.errors?.length || compiled.written?.length !== 1) throw new Error('BGM graph did not compile/write completely');
  const checked = await call('scene_check_client', { mapPath });
  if (!checked.ok || checked.errors) throw new Error('Candidate client check failed');
  const baseAfter = hash(baseMap);
  if (baseAfter !== baseSha256) throw new Error('Input map hash changed');
  writeFileSync(join(workspace, 'candidate.json'), JSON.stringify({ mapPath, sha256: hash(mapPath),
    baseMap, baseSha256, baseAfter, liveWriteEnabled: false, compiled, checked,
    officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', listening: 'NOT_TESTED' }, null, 2));
  console.log(`BGM candidate compiled and copy written: ${mapPath}`);
  console.log('Official import, playback and listening for this candidate are NOT TESTED.');
} finally { await client.close(); }
