import {verifyArtFeatureReceipt,artFeaturesSource,artFeatureModule} from './art-features.mjs';
// Explicit audio audition candidate. Never imported or played automatically.
import { readFileSync, mkdirSync, writeFileSync, copyFileSync, constants } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import { nativeBgmGraphSource, nativeBgmSignals } from './native-bgm-graph.mjs';
import { fileRecord } from './evidence-files.mjs';
import { nativeUiVariables } from './native-candidate-scripts.mjs';

const [base, directory = '.artifacts/native-bgm-candidate', sourceReceiptFile] = process.argv.slice(2);
if (!base) throw new Error('Usage: node scripts/build-native-bgm-candidate.mjs <full-game-base.gil> [output-directory] [full-candidate.json]');
const baseMap = resolve(base), workspace = resolve(directory);
const hash = file => createHash('sha256').update(readFileSync(file)).digest('hex');
const baseSha256 = hash(baseMap);
const full = sourceReceiptFile ? JSON.parse(readFileSync(sourceReceiptFile, 'utf8')) : undefined;
if (full && (full.candidate?.sha256 !== baseSha256 || typeof full.buildId !== 'string' || !full.buildId))
  throw new Error('Full candidate receipt does not match the audio base/build');
if(full){
 const flags=verifyArtFeatureReceipt(full.artFeatures),source=readFileSync(join(dirname(resolve(sourceReceiptFile)),'payload',artFeatureModule+'.lua'),'utf8');
 if(source!==artFeaturesSource(flags)||createHash('sha256').update(source).digest('hex')!==full.moduleDigests?.[artFeatureModule])throw Error('Full candidate art feature configuration mismatch');
}
const scripts = ['abyss_bgm', 'abyss_game_ui', 'abyss_ui'].map(name => ({ name,
  source: readFileSync(full ? join(dirname(resolve(sourceReceiptFile)), 'payload', `${name}.lua`)
    : new URL(`../src/lua/${name}.lua`, import.meta.url), 'utf8'),
  ...(name === 'abyss_ui' ? { variables: nativeUiVariables().map(row => row.name === 'nativeBgmEnabled' ? { ...row, value: true } : row) } : {}) }));
if (full) for (const script of scripts) {
  if (createHash('sha256').update(script.source).digest('hex') !== full.moduleDigests?.[script.name]
    || script.name === 'abyss_ui' && !script.source.startsWith(`print("ABYSS_BUILD ${full.buildId}")\n`))
    throw new Error(`Full packaged source/marker mismatch: ${script.name}`);
}
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
  if (full) {
    const readback = await call('scene_list_client_scripts', { mapPath, includeSource: true });
    const expected = Object.keys(full.moduleDigests).sort();
    if (!Array.isArray(readback.scripts) || JSON.stringify(readback.scripts.map(row => row.name).sort()) !== JSON.stringify(expected)
      || readback.scripts.some(row => typeof row.source !== 'string'
        || createHash('sha256').update(row.source).digest('hex') !== full.moduleDigests[row.name]))
      throw new Error('Final audio script readback differs from the full candidate');
  }
  const baseAfter = hash(baseMap);
  if (baseAfter !== baseSha256) throw new Error('Input map hash changed');
  const finalMap = join(workspace, 'candidate.gil');
  if (resolve(mapPath) !== finalMap) copyFileSync(mapPath, finalMap, constants.COPYFILE_EXCL);
  mapPath = finalMap;
  writeFileSync(join(workspace, 'candidate.json'), JSON.stringify({ mapPath, sha256: hash(mapPath),
    candidate: fileRecord(mapPath), ...(full ? { buildId: full.buildId, artFeatures:full.artFeatures, moduleDigests: full.moduleDigests,
      ...(full.officialPortraits ? {officialPortraits:full.officialPortraits} : {}),
    ...(full.readyCardArt ? {readyCardArt:full.readyCardArt} : {}),
    ...(full.officialBackground ? {officialBackground:full.officialBackground} : {}) } : {}),
    baseMap, baseSha256, baseAfter, liveWriteEnabled: false, compiled, checked,
    officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', listening: 'NOT_TESTED' }, null, 2));
  console.log(`BGM candidate compiled and copy written: ${mapPath}`);
  console.log('Official import, playback and listening for this candidate are NOT TESTED.');
} finally { await client.close(); }
