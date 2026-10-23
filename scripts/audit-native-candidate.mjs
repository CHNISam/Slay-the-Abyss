// Local offline tools only. Never calls a save mutation, import or playtest API.
import { existsSync, readFileSync, writeFileSync, mkdirSync, realpathSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve, join, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { compareNativeCandidate, requireSourceSha, sha256 } from './native-candidate-audit.mjs';

const usage = 'node scripts/audit-native-candidate.mjs --source <full-commit-SHA> --candidate <full-game.gil> --output <new-directory> [--bgm]';
function argumentsOf(args) {
  const options = {};
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (flag === '--bgm') options.bgm = true;
    else if (['--source', '--candidate', '--output'].includes(flag) && args[i + 1] && !args[i + 1].startsWith('--')) options[flag.slice(2)] = args[++i];
    else throw new Error(`Invalid argument ${flag}. Usage: ${usage}`);
  }
  requireSourceSha(options.source);
  if (!options.candidate || !options.output) throw new Error(`Usage: ${usage}`);
  return options;
}

function newOutputPath(input) {
  // Resolve the raw existing prefix first: path.resolve would erase symlink/..
  // traversal and could silently redirect evidence or miss an existing directory.
  let parent = input;
  const pending = [];
  while (!existsSync(parent)) {
    const next = dirname(parent);
    if (next === parent) throw new Error('Output has no existing parent directory');
    pending.unshift(basename(parent));
    parent = next;
  }
  if (pending.includes('..')) throw new Error('Output parent traversal must refer to existing directories');
  return join(realpathSync.native(parent), ...pending);
}

export async function auditNativeCandidate(options) {
  const sourceSha = requireSourceSha(options.source);
  const officialSave = /(?:^|[/\\])Beyond_Local_Save_Level(?:[/\\]|$)/i;
  if (officialSave.test(options.candidate)) throw new Error('Use an exported candidate copy, not an official save');
  const mapPath = realpathSync.native(options.candidate);
  if (officialSave.test(mapPath)) throw new Error('Use an exported candidate copy, not an official save');
  if (!statSync(mapPath).isFile()) throw new Error('Candidate must be a regular file');
  const output = newOutputPath(options.output);
  if (existsSync(output)) throw new Error('Output must be a new directory; existing evidence is preserved');
  const before = sha256(readFileSync(mapPath));
  mkdirSync(output, { recursive: true });
  const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const save = (name, value) => { writeFileSync(join(output, name), JSON.stringify(value, null, 2) + '\n'); return value; };
  function run(command, args, settings = {}) {
    const result = spawnSync(command, args, { cwd: repo, maxBuffer: 50 * 1024 * 1024, ...settings });
    if (result.status !== 0) throw new Error(`${command}: ${result.error?.message || result.stderr?.toString()}`);
    return result.stdout;
  }
  let report;
  try {
    const resolved = run('git', ['rev-parse', `${sourceSha}^{commit}`], { encoding: 'utf8' }).trim();
    if (resolved !== sourceSha) throw new Error('Source SHA did not resolve to that exact commit');
    const toolRoot = process.env.MILIASTRA_MCP_ROOT || 'D:/MiliastraTools/genshin-miliastra-mcp';
    const load = path => import(pathToFileURL(join(toolRoot, path)));
    const { Client } = await load('node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js');
    const { StdioClientTransport } = await load('node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js');
    const client = new Client({ name: 'abyss-candidate-readback', version: '1' });
    await client.connect(new StdioClientTransport({ command: process.execPath, args: [join(toolRoot, 'src/server.mjs')],
      env: { ...process.env, MILIASTRA_WORKSPACE: output, MILIASTRA_ALLOW_LIVE_WRITE: '0' } }));
    try {
      for (const uri of ['miliastra://workflow', 'miliastra://platform-rules']) save(`${uri.split('//')[1]}.json`, await client.readResource({ uri }));
    } finally { await client.close(); }
    const { listClientScripts, getClientUi, checkClientScripts } = await load('src/scene-save.mjs');
    const { inspectFile } = await load('src/adapter.mjs');
    const { container, fields, one } = await load('src/scene/wire.mjs');
    const scripts = save('scripts.json', listClientScripts({ mapPath, includeSource: true }));
    const ui = save('ui.json', getClientUi({ mapPath, ui: 'SlayTheAbyss' }));
    const template = save('template.json', getClientUi({ mapPath, template: 'AbyssDeckCard' }));
    const inspected = save('inspect.json', inspectFile(mapPath));
    const checked = save('static-check.json', checkClientScripts({ mapPath }));
    const uiRecord = fields(one(container(readFileSync(mapPath)), 50)).find(field => field.id === 1
      && field.wire === 2 && one(field.data, 2).toString('utf8') === 'abyss_ui');
    const records = fields(uiRecord.data).filter(field => [7, 8].includes(field.id) && field.wire === 2
      && one(field.data, 2).toString('utf8') === 'nativeBgmEnabled').map(field => ({ section: field.id,
      name: 'nativeBgmEnabled', type: Number(one(field.data, 3, 0)), code: Number(one(field.data, 10, 0)),
      value: fields(one(one(field.data, 4), 106)).some(value => value.id === 1 && value.value === 1n), encodedHex: field.raw.toString('hex') }));
    const parameters = save('parameters.json', { script: 'abyss_ui', records });
    const snapshot = join(output, 'source'); mkdirSync(snapshot);
    run('tar', ['-xf', '-', '-C', snapshot], { input: run('git', ['archive', sourceSha, 'src/lua', 'data', 'scripts', 'tools']) });
    for (const script of ['build-lua-data.mjs', 'build-ui.mjs']) writeFileSync(join(output, `${script}.log`),
      run(process.execPath, [`scripts/${script}`], { cwd: snapshot }));
    const { candidateScriptFiles } = await import(pathToFileURL(join(snapshot, 'scripts/native-candidate-scripts.mjs')));
    const deployment = candidateScriptFiles(join(snapshot, 'src/lua'), join(snapshot, 'build/lua'));
    const uiBgmParameter = deployment.find(script => script.name === 'abyss_ui')?.variables?.find(variable => variable.name === 'nativeBgmEnabled');
    const modules = deployment.map(({ name, sourceFile }) => ({ name, source: readFileSync(sourceFile, 'utf8') }));
    const expectedUi = JSON.parse(readFileSync(join(snapshot, 'build/lua/game-ui.json'), 'utf8'));
    const expectedTemplate = JSON.parse(readFileSync(join(snapshot, 'build/lua/game-ui-templates.json'), 'utf8')).find(template => template.name === 'AbyssDeckCard');
    const graphNames = [['settlement-graph.mjs', 'settlementGraphSource', 'ABYSS_SETTLEMENT']];
    if (options.bgm) graphNames.push(['native-bgm-graph.mjs', 'nativeBgmGraphSource', 'ABYSS_BGM']);
    const graphs = [];
    for (const [file, method, name] of graphNames) {
      const generator = await import(pathToFileURL(join(snapshot, 'scripts', file)));
      const source = generator[method]({ id: inspected.graphs.find(graph => graph.name === `_GSTS_${name}`)?.id || 1, name });
      graphs.push({ name: `_GSTS_${name}`, signals: [...source.matchAll(/\.onSignal\('([^']+)'/g)].map(match => match[1]), generatedSourceSha256: sha256(source) });
    }
    report = compareNativeCandidate({ actual: { scripts, ui, template, inspected, parameters, checked },
      expected: { modules, ui: expectedUi, template: expectedTemplate, graphs, uiBgmParameter }, sourceSha,
      candidateBefore: before, candidateAfter: sha256(readFileSync(mapPath)), bgm: options.bgm });
    report.expectedGraphs = graphs;
    report.graphCheckScope = 'Graph identity, server type, nonempty payload, monitored signal names and enabled mount; compiled node parameters/semantics are not certified.';
  } catch (error) {
    report = { ok: false, sourceCommit: sourceSha, issues: [{ code: 'AUDIT_ERROR', detail: error.message }],
      candidate: { sha256Before: before, sha256After: sha256(readFileSync(mapPath)) }, playtest: 'NOT_TESTED', officialImport: 'NOT_TESTED', audio: 'NOT_TESTED' };
  }
  report.candidate.path = mapPath;
  report.evidenceDirectory = output;
  report.liveWriteEnabled = false;
  report.checkedAt = new Date().toISOString();
  save('audit.json', report);
  save('sourcehash.json', { sourceCommit: sourceSha, candidate: report.candidate, modules: report.modules ?? [] });
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (process.argv.length === 3 && process.argv[2] === '--help') { console.log(usage); process.exit(0); }
  try {
    const options = argumentsOf(process.argv.slice(2));
    const report = await auditNativeCandidate(options);
    console.log(JSON.stringify({ ok: report.ok, report: join(report.evidenceDirectory, 'audit.json'), candidate: report.candidate,
      issues: report.issues, playtest: 'NOT_TESTED', audio: 'NOT_TESTED' }, null, 2));
    if (!report.ok) process.exitCode = 1;
  } catch (error) { console.log(JSON.stringify({ ok: false, issues: [{ code: 'AUDIT_INPUT_ERROR', detail: error.message }], playtest: 'NOT_TESTED' })); process.exitCode = 1; }
}
