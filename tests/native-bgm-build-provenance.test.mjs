import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { fileRecord, sha256 } from '../scripts/evidence-files.mjs';
import { nativeUiVariables } from '../scripts/native-candidate-scripts.mjs';
import { requireStartupEvidence } from '../scripts/native-playtest-evidence.mjs';

const builder = fileURLToPath(new URL('../scripts/build-native-bgm-candidate.mjs', import.meta.url));
const sdk = `
import {readFileSync,writeFileSync,appendFileSync} from 'node:fs';
const state=JSON.parse(readFileSync(process.env.BGM_SCENARIO,'utf8'));
const scripts=new Map(state.scripts.map(row=>[row.name,row.source]));
export class Client {
 async connect() {} async close() {} async readResource(){return {contents:[]};}
 async callTool({name,arguments:args}) {
  appendFileSync(process.env.BGM_CALLS,JSON.stringify({name,args})+'\\n');
  if(name==='scene_set_client_script')scripts.set(args.name,args.source);
  writeFileSync(state.output,JSON.stringify([...scripts]));
  let data={mapPath:state.output};
  if(name==='scene_add_graph')Object.assign(data,{graphId:7,name:'ABYSS_BGM'});
  if(name==='write_graphs')data.written=[7];
  if(name==='scene_check_client')Object.assign(data,{ok:true,errors:0,checked:[...scripts.keys()]});
  if(name==='scene_list_client_scripts')data.scripts=[...scripts].map(([name,source])=>({name,source:
   state.corrupt===name ? source.replace(/^print\\([^\\n]+\\)\\n/,'')+'stale' : source}));
  return {structuredContent:data};
 }
}
`;
function fixture(t, corrupt) {
  const root = mkdtempSync(join(tmpdir(), 'abyss-bgm-marker-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const put = (file, text) => { const path = join(root, file); mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, text); return path; };
  const buildId = 'fe4ad995-c98b-4ed1-981a-04abbc4bfad9';
  const sources = { abyss_bgm: 'return {bgm=true}', abyss_game_ui: 'return {view=true}',
    abyss_ui: `print("ABYSS_BUILD ${buildId}")\n-- exact full-build instrumentation\nreturn {}`, abyss_narrative: 'return {codeVersion="v0.1.0"}' };
  const moduleDigests = Object.fromEntries(Object.entries(sources).map(([name, source]) => {
    put(`full/payload/${name}.lua`, source); return [name, sha256(source)];
  }));
  const base = put('full/candidate.gil', 'full pre-audio candidate');
  const sourceReceipt = put('full/candidate.json', JSON.stringify({ buildId, candidate: fileRecord(base), moduleDigests, officialBackground:{templateIndex:1470123456,peakDynamicControls:13201} }));
  const tool = join(root, 'tool');
  put('tool/package.json', '{"type":"module","version":"fixture"}');
  put('tool/node_modules/@modelcontextprotocol/sdk/package.json', '{"type":"module"}');
  put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js', sdk);
  put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js', `export class StdioClientTransport {constructor(options){if(options.env.MILIASTRA_ALLOW_LIVE_WRITE!=='0')throw Error('live writes');}}`);
  const calls = put('calls.jsonl', '');
  const scenario = put('scenario.json', JSON.stringify({ scripts: Object.entries(sources).map(([name, source]) => ({ name, source })), output: join(root, 'mcp-returned-outside-audio.gil'), corrupt }));
  const output = join(root, 'audio');
  const run = spawnSync(process.execPath, [builder, base, output, sourceReceipt], { encoding: 'utf8',
    env: { ...process.env, MILIASTRA_MCP_ROOT: tool, BGM_SCENARIO: scenario, BGM_CALLS: calls } });
  return { root, sources, base, buildId, output, run, calls: readFileSync(calls, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) };
}
test('real BGM CLI preserves exact packaged startup marker and all entry parameters, then binds final adjacent artifact', t => {
  const f = fixture(t); assert.equal(f.run.status, 0, f.run.stderr);
  const entry = f.calls.find(row => row.name === 'scene_set_client_script' && row.args.name === 'abyss_ui');
  assert.equal(entry.args.source, f.sources.abyss_ui, 'raw repository entry cannot replace the packaged marker/instrumentation');
  assert.deepEqual(entry.args.variables, nativeUiVariables().map(row => row.name === 'nativeBgmEnabled' ? { ...row, value: true } : row));
  assert(f.calls.some(row => row.name === 'scene_list_client_scripts' && row.args.includeSource));
  const receipt = JSON.parse(readFileSync(join(f.output, 'candidate.json')));
  assert.equal(receipt.mapPath, join(f.output, 'candidate.gil'));
  assert.deepEqual(receipt.candidate, fileRecord(receipt.mapPath));
  assert.deepEqual(receipt.officialBackground,{templateIndex:1470123456,peakDynamicControls:13201});
  assert.equal(receipt.buildId, f.buildId); assert.equal(receipt.sha256, receipt.candidate.sha256);
  assert.notEqual(receipt.candidate.sha256, fileRecord(f.base).sha256);
  assert.equal(receipt.officialImport, 'NOT_TESTED'); assert.equal(receipt.playtest, 'NOT_TESTED');

  // The existing startup verifier must bind a NEW run to the FINAL audio map,
  // while recognizing the unchanged original full-build startup marker.
  const runId = 'final-audio-run', runDir = join(f.output, runId); mkdirSync(runDir);
  const prints = [{ clientScript: true, text: `ABYSS_BUILD ${receipt.buildId}` }, { clientScript: true, text: 'ABYSS_UI ready' }];
  const log = join(runDir, 'raw.json'); writeFileSync(log, JSON.stringify(prints));
  writeFileSync(join(runDir, 'request.json'), JSON.stringify({ clientScriptLog: true, runDir, mapPath: receipt.mapPath }));
  const expected = { runId, runDir, mapPath: receipt.mapPath, candidateHash: receipt.candidate.sha256, buildId: receipt.buildId, startedAt: Date.now() - 1000 };
  const status = { state: 'succeeded', runId, runDir, steps: [{ step: 'log-subscribed', clientScripts: true }], log: { file: log, prints } };
  const decoder = { parserVersion: 'fixture-raw-json', decodeLog: bytes => ({ sourceHash: sha256(bytes), prints: JSON.parse(bytes) }) };
  assert.equal(requireStartupEvidence(status, expected, decoder).candidateHash, receipt.candidate.sha256);
  assert.throws(() => requireStartupEvidence(status, { ...expected, candidateHash: fileRecord(f.base).sha256 }, decoder), /Request does not match/);
  assert.throws(() => requireStartupEvidence(status, { ...expected, buildId: 'another-build' }, decoder), /startup never reached ready/);
});
for (const corrupt of ['abyss_ui', 'abyss_narrative']) test(`BGM final readback rejects corrupted ${corrupt} instead of inheriting pre-audio provenance`, t => {
  const f = fixture(t, corrupt); assert.notEqual(f.run.status, 0);
  assert.match(f.run.stderr, /Final audio script readback differs/);
  assert.equal(existsSync(join(f.output, 'candidate.json')), false);
});
