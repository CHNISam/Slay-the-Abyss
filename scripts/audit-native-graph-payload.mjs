// Explicit offline compilation command. The ordinary read-only auditor is unchanged.
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { requireSourceSha, sha256 } from './native-candidate-audit.mjs';
import { decodeGraphPayload, compareGraphPayloads } from './native-graph-payload.mjs';

const usage = 'node scripts/audit-native-graph-payload.mjs --source <full-SHA> --candidate <candidate.gil> --output <new-directory> [--bgm]';
const options = {};
let output, before, mapPath;
try {
  for (let i = 2; i < process.argv.length; i++) {
    const flag = process.argv[i];
    if (flag === '--bgm') options.bgm = true;
    else if (['--source', '--candidate', '--output'].includes(flag) && process.argv[i + 1] && !process.argv[i + 1].startsWith('--')) options[flag.slice(2)] = process.argv[++i];
    else throw new Error(`Usage: ${usage}`);
  }
  const source = requireSourceSha(options.source);
  if (!options.candidate || !options.output) throw new Error(`Usage: ${usage}`);
  mapPath = resolve(options.candidate); output = resolve(options.output);
  if (/[/\\]Beyond_Local_Save_Level[/\\]/i.test(mapPath)) throw new Error('Use an exported candidate, not an official save');
  if (existsSync(output)) throw new Error('Output must be a new directory');
  const original = readFileSync(mapPath); before = sha256(original);
  mkdirSync(output, { recursive: true });
  const save = (name, data) => { writeFileSync(join(output, name), JSON.stringify(data, null, 2) + '\n'); return data; };
  const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const run = (command, args, settings = {}) => {
    const result = spawnSync(command, args, { cwd: repo, maxBuffer: 50 * 1024 * 1024, ...settings });
    if (result.status !== 0) throw new Error(`${command}: ${result.error?.message || result.stderr?.toString()}`);
    return result.stdout;
  };
  if (run('git', ['rev-parse', `${source}^{commit}`], { encoding: 'utf8' }).trim() !== source) throw new Error('Source commit mismatch');
  const toolRoot = process.env.MILIASTRA_MCP_ROOT || 'D:/MiliastraTools/genshin-miliastra-mcp';
  const load = path => import(pathToFileURL(join(toolRoot, path)));
  save('toolchain.json', { root: toolRoot,
    genshinTsVersion: JSON.parse(readFileSync(join(toolRoot, 'node_modules/genshin-ts/package.json'))).version,
    files: Object.fromEntries(['src/core.mjs', 'src/adapter.mjs',
      'node_modules/genshin-ts/dist/src/injector/proto.js',
      'node_modules/genshin-ts/dist/src/thirdparty/Genshin-Impact-Miliastra-Wonderland-Code-Node-Editor-Pack/protobuf/gia.proto',
      'node_modules/genshin-ts/dist/src/injector/binary.js',
      'node_modules/genshin-ts/dist/src/injector/node_graph.js'].map(file => [file, sha256(readFileSync(join(toolRoot, file)))])) });
  const { Client } = await load('node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js');
  const { StdioClientTransport } = await load('node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js');
  const client = new Client({ name: 'abyss-explicit-graph-payload-audit', version: '1' });
  await client.connect(new StdioClientTransport({ command: process.execPath, args: [join(toolRoot, 'src/server.mjs')],
    env: { ...process.env, MILIASTRA_WORKSPACE: output, MILIASTRA_ALLOW_LIVE_WRITE: '0' } }));
  try { for (const uri of ['miliastra://workflow', 'miliastra://platform-rules']) save(`${uri.split('//')[1]}.json`, await client.readResource({ uri })); }
  finally { await client.close(); }
  const { inspectBytes, inject } = await load('src/adapter.mjs');
  const { Service } = await load('src/core.mjs');
  const { parseMessage } = await load('node_modules/genshin-ts/dist/src/injector/binary.js');
  const { buildNodeGraphFieldIndex } = await load('node_modules/genshin-ts/dist/src/injector/node_graph.js');
  const { loadGiaProto } = await load('node_modules/genshin-ts/dist/src/injector/proto.js');
  const { nodeGraphMessage } = loadGiaProto();
  const inspected = save('inspect.json', inspectBytes(original));
  const names = [['ABYSS_SETTLEMENT', 'settlement-graph.mjs', 'settlementGraphSource']];
  if (options.bgm) names.push(['ABYSS_BGM', 'native-bgm-graph.mjs', 'nativeBgmGraphSource']);
  if (inspected.graphs.length !== names.length) throw new Error('Unexpected graph count; choose --bgm explicitly for BGM candidates');
  const snapshot = join(output, 'source'); mkdirSync(snapshot);
  run('tar', ['-xf', '-', '-C', snapshot], { input: run('git', ['archive', source, 'scripts', 'data']) });
  const sources = [];
  for (const [name, file, method] of names) {
    const graphs = inspected.graphs.filter(graph => graph.name === `_GSTS_${name}` && graph.type === 20000);
    if (graphs.length !== 1) throw new Error(`Expected one server graph _GSTS_${name}`);
    const generator = await import(pathToFileURL(join(snapshot, 'scripts', file)));
    const code = generator[method]({ id: graphs[0].id, name });
    writeFileSync(join(output, `${name}.ts`), code);
    sources.push({ graphId: graphs[0].id, code });
  }
  const service = new Service({ workspace: join(output, 'compiler'), saveRoots: [dirname(mapPath)], allowLive: false });
  let gias = await service.compileTogether(sources);
  if (!gias) {
    gias = [];
    for (const [index, graph] of sources.entries()) {
      const projectId = `graph-${index}`;
      service.createProject({ projectId, mapPath, targetGraphId: graph.graphId });
      service.updateLogic({ projectId, code: graph.code });
      const build = await service.buildProject({ projectId });
      save(`compile-${graph.graphId}.json`, build);
      gias.push(build.giaPath);
    }
  }
  if (gias.length !== sources.length || gias.some(path => !path || !existsSync(path))) throw new Error('Compiler did not produce every requested graph');
  save('compile-artifacts.json', gias);
  let expectedBytes = original;
  for (const [index, graph] of sources.entries()) expectedBytes = inject(expectedBytes, readFileSync(gias[index]), graph.graphId);
  function decode(bytes, id) {
    const payload = bytes.subarray(20, -4), fields = [];
    parseMessage(payload, 0, payload.length, 0, 0, 0, 0, 0, 0, 0, fields);
    const matches = buildNodeGraphFieldIndex(payload, fields).get(id) ?? [];
    if (matches.length !== 1) throw new Error(`Ambiguous/missing graph ${id}`);
    const raw = payload.subarray(matches[0].field.dataStart, matches[0].field.dataEnd);
    return decodeGraphPayload(raw, nodeGraphMessage);
  }
  const graphs = sources.map(({ graphId, code }, index) => {
    const actual = save(`actual-${graphId}.json`, decode(original, graphId));
    const expected = save(`expected-${graphId}.json`, decode(expectedBytes, graphId));
    return { ...compareGraphPayloads(actual, expected), sourceSha256: sha256(code), gia: gias[index], giaSha256: sha256(readFileSync(gias[index])) };
  });
  const issues = graphs.flatMap(graph => graph.issues.map(issue => ({ ...issue, graphId: graph.graphId })));
  const after = sha256(readFileSync(mapPath));
  if (before !== after) issues.push({ code: 'CANDIDATE_CHANGED', detail: 'Input hash changed during audit' });
  const report = save('graph-payload-audit.json', { ok: issues.length === 0, sourceCommit: source,
    candidate: { path: mapPath, sha256Before: before, sha256After: after }, liveWriteEnabled: false,
    graphs, issues, externalBindings: 'Signal definition IDs are resolved by the existing injector against the input. External signal definitions, stage/prefab settings and runtime behavior are not source-certified by this payload comparison.',
    writes: 'Explicit command writes source/GIA/logs and, for single-graph compilation, an input copy inside output/compiler only. Expected injection is in memory; input is never applied or written.',
    officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', audio: 'NOT_TESTED' });
  console.log(JSON.stringify({ ok: report.ok, report: join(output, 'graph-payload-audit.json'), candidate: report.candidate, issues }, null, 2));
  if (!report.ok) process.exitCode = 1;
} catch (error) {
  const report = { ok: false, sourceCommit: options.source, issues: [{ code: 'GRAPH_AUDIT_ERROR', detail: error.message }],
    candidate: { path: mapPath, sha256Before: before, sha256After: mapPath && existsSync(mapPath) ? sha256(readFileSync(mapPath)) : null },
    liveWriteEnabled: false, officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', audio: 'NOT_TESTED' };
  if (output && existsSync(output) && before) writeFileSync(join(output, 'graph-payload-audit.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2)); process.exitCode = 1;
}
