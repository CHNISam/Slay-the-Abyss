import {portraitInputs,portraitModule} from './official-portraits.mjs';
import {readyArtSourceInputs,readyArtImageTemplate,readyArtGroupTemplate} from './art/ready-card-runtime.mjs';
import {backgroundInputs, backgroundModule, backgroundTemplate} from './official-background.mjs';
// Local offline tools only. Never calls a save mutation, import or playtest API.
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { compareNativeCandidate, requireSourceSha, sha256, candidateEntrySource } from './native-candidate-audit.mjs';
import { exportedCandidatePath, newEvidenceDirectory } from './native-audit-paths.mjs';
import { releaseSourceFiles } from './release-notes.mjs';

export function auditUiBuildArgs(receipt) {
  return ['scripts/build-ui.mjs',...(receipt?.readyCardArt?.enabled===false?['--no-ready-card-art']:[])];
}

const usage = 'node scripts/audit-native-candidate.mjs --source <full-commit-SHA> --candidate <full-game.gil> --output <new-directory> [--receipt <candidate.json>] [--bgm]';
function argumentsOf(args) {
  const options = {};
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (flag === '--bgm') options.bgm = true;
    else if (['--source', '--candidate', '--output', '--receipt'].includes(flag) && args[i + 1] && !args[i + 1].startsWith('--')) options[flag.slice(2)] = args[++i];
    else throw new Error(`Invalid argument ${flag}. Usage: ${usage}`);
  }
  requireSourceSha(options.source);
  if (!options.candidate || !options.output) throw new Error(`Usage: ${usage}`);
  return options;
}

export async function auditNativeCandidate(options) {
  const sourceSha = requireSourceSha(options.source);
  const mapPath = exportedCandidatePath(options.candidate);
  const output = newEvidenceDirectory(options.output);
  if (existsSync(output)) throw new Error('Output must be a new directory; existing evidence is preserved');
  const before = sha256(readFileSync(mapPath));
  const buildReceipt = options.receipt === undefined ? undefined : JSON.parse(readFileSync(options.receipt, 'utf8'));
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
    const background = scripts.scripts.some(module=>module.name===backgroundModule)
      ? save('background-template.json', getClientUi({mapPath,template:backgroundTemplate})) : undefined;
    const runtimeTemplates=scripts.scripts.some(module=>module.name==='abyss_ready_card_binding')
      ? [readyArtImageTemplate,readyArtGroupTemplate].map(name=>save(name+'.json',getClientUi({mapPath,template:name}))) : undefined;
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
    const assetInputs=run('git',['ls-tree','--name-only',sourceSha,'--',...backgroundInputs,...readyArtSourceInputs(repo),...portraitInputs],{encoding:'utf8'}).trim().split('\n').filter(Boolean);
    run('tar', ['-xf', '-', '-C', snapshot], { input: run('git', ['archive', sourceSha,
      'src/lua', 'data', 'scripts', 'tools', ...releaseSourceFiles, ...assetInputs]) });
    for (const script of ['build-lua-data.mjs', 'build-ui.mjs']) writeFileSync(join(output, `${script}.log`),
      run(process.execPath, script==='build-ui.mjs'?auditUiBuildArgs(buildReceipt):[`scripts/${script}`], { cwd: snapshot }));
    const { candidateScriptFiles } = await import(pathToFileURL(join(snapshot, 'scripts/native-candidate-scripts.mjs')));
    const deployment = candidateScriptFiles(join(snapshot, 'src/lua'), join(snapshot, 'build/lua'));
    const uiBgmParameter = deployment.find(script => script.name === 'abyss_ui')?.variables?.find(variable => variable.name === 'nativeBgmEnabled');
    if(deployment.some(module=>module.name===backgroundModule)) {
      if(buildReceipt?.sourceCommit!==sourceSha || buildReceipt?.candidate?.sha256!==before
        || buildReceipt?.officialBackground?.templateIndex!==background?.templateIndex)
        throw Error('Official background requires matching same-candidate receipt and template readback');
      const {bindBackgroundTemplate}=await import(pathToFileURL(join(snapshot,'scripts/official-background.mjs')));
      bindBackgroundTemplate(join(snapshot,'build/lua'),background,{root:snapshot});
    }
    if(deployment.some(module=>module.name==='abyss_ready_card_binding')) {
      if(buildReceipt?.sourceCommit!==sourceSha||buildReceipt?.candidate?.sha256!==before
        ||runtimeTemplates?.[0]?.templateIndex!==buildReceipt?.readyCardArt?.imageTemplateIndex
        ||runtimeTemplates?.[1]?.templateIndex!==buildReceipt?.readyCardArt?.containerTemplateIndex)
        throw Error('Ready artwork requires matching same-candidate binding and templates');
      const {bindReadyArtTemplates}=await import(pathToFileURL(join(snapshot,'scripts/art/ready-card-runtime.mjs')));
      bindReadyArtTemplates(join(snapshot,'build/lua'),{image:runtimeTemplates[0],group:runtimeTemplates[1]},{enabled:buildReceipt.readyCardArt.enabled});
    }
    if(deployment.some(module=>module.name===portraitModule)) {
      if(buildReceipt?.officialPortraits?.imageTemplateIndex!==runtimeTemplates?.[0]?.templateIndex
        ||buildReceipt?.officialPortraits?.containerTemplateIndex!==runtimeTemplates?.[1]?.templateIndex)
        throw Error('Portrait runtime requires matching same-candidate template binding');
      const {bindPortraitTemplates}=await import(pathToFileURL(join(snapshot,'scripts/official-portraits.mjs')));
      bindPortraitTemplates(join(snapshot,'build/lua'),{image:runtimeTemplates[0],container:runtimeTemplates[1]},{root:snapshot});
    }
    const modules = deployment.map(({ name, sourceFile }) => {
      const source = readFileSync(sourceFile, 'utf8');
      return { name, source: name === 'abyss_ui' ? candidateEntrySource(source, buildReceipt, before) : source };
    });
    const expectedUi = JSON.parse(readFileSync(join(snapshot, 'build/lua/game-ui.json'), 'utf8'));
    const expectedTemplates = JSON.parse(readFileSync(join(snapshot, 'build/lua/game-ui-templates.json'), 'utf8'));
    const expectedTemplate = expectedTemplates.find(template => template.name === 'AbyssDeckCard');
    const expectedRuntimeTemplates=runtimeTemplates? [readyArtImageTemplate,readyArtGroupTemplate].map((name,i)=>({
      template:expectedTemplates.find(row=>row.name===name),templateIndex:i===0?buildReceipt?.readyCardArt?.imageTemplateIndex:buildReceipt?.readyCardArt?.containerTemplateIndex})) : undefined;
    const expectedBackgroundTemplate = expectedTemplates.find(template => template.name === backgroundTemplate);
    const expectedBackground = expectedBackgroundTemplate ? {template:expectedBackgroundTemplate,
      templateIndex:buildReceipt?.officialBackground?.templateIndex} : undefined;
    const graphNames = [['settlement-graph.mjs', 'settlementGraphSource', 'ABYSS_SETTLEMENT']];
    if (options.bgm) graphNames.push(['native-bgm-graph.mjs', 'nativeBgmGraphSource', 'ABYSS_BGM']);
    const graphs = [];
    for (const [file, method, name] of graphNames) {
      const generator = await import(pathToFileURL(join(snapshot, 'scripts', file)));
      const source = generator[method]({ id: inspected.graphs.find(graph => graph.name === `_GSTS_${name}`)?.id || 1, name });
      graphs.push({ name: `_GSTS_${name}`, signals: [...source.matchAll(/\.onSignal\('([^']+)'/g)].map(match => match[1]), generatedSourceSha256: sha256(source) });
    }
    report = compareNativeCandidate({ actual: { scripts, ui, template, background, runtimeTemplates, inspected, parameters, checked },
      expected: { modules, ui: expectedUi, template: expectedTemplate, background:expectedBackground, runtimeTemplates:expectedRuntimeTemplates, graphs, uiBgmParameter }, sourceSha,
      candidateBefore: before, candidateAfter: sha256(readFileSync(mapPath)), bgm: options.bgm });
    report.expectedGraphs = graphs;
    report.graphCheckScope = 'Graph identity, server type, nonempty payload, monitored signal names and enabled mount; compiled node parameters/semantics are not certified.';
  } catch (error) {
    report = { ok: false, sourceCommit: sourceSha, issues: [{ code: 'AUDIT_ERROR', detail: error.message }],
      candidate: { sha256Before: before, sha256After: sha256(readFileSync(mapPath)) }, playtest: 'NOT_TESTED', officialImport: 'NOT_TESTED', audio: 'NOT_TESTED' };
  }
  report.candidate.path = mapPath;
  report.evidenceDirectory = output;
  if (buildReceipt) report.buildMarker = { buildId: buildReceipt.buildId, candidateSha256: before,
    receiptSha256: sha256(readFileSync(options.receipt)) };
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
