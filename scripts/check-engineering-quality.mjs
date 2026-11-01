import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { analyzeSources } from './check-architecture.mjs';
import { runStatic, compareDiagnostics } from './check-lua-static.mjs';
import { discoverSources, measureSources, dependencyCycles } from './lua-quality-metrics.mjs';
import { sha256 } from './evidence-files.mjs';

export const qualityContract={
  version:1,parser:'luaparse@0.3.1',luacheck:'1.2.0',
  sources:'all src/lua/**/*.lua; no exclusions; linked entries fail',
  lines:'physical lines including comments/blanks; terminal newline not an extra line',
  functionSpan:'inclusive AST span including nested bodies; all functions and main chunks',
  functionIdentity:'lexical parent/name/occurrence; correspondence is structural, not semantic proof',
  sourceHash:'sha256 UTF8 with CRLF normalized to LF',
  complexity:'Luacheck --max-cyclomatic-complexity 0 --only 561; one measurement per AST function/chunk',
  cycles:'all require edges including deferred; strongly connected components with internal edges',
  warnings:'exact file/line/column/code/message multiset; no relocation exemptions',
  watchedModules:['abyss_combat','abyss_battle_ui','abyss_node_ui','abyss_run','abyss_nodes','abyss_game_ui','abyss_feedback'],
};

export function qualitySnapshot(measurements,architecture,diagnostics) {
  const dependencies=[...new Set(architecture.edges.map(e=>`${e.from}\0${e.to}`))].sort()
    .map(key=>key.split('\0'));
  return {schemaVersion:1,mode:'report-only',contract:structuredClone(qualityContract),
    modules:measurements.modules,dependencies,
    cycles:dependencyCycles(architecture.nodes,architecture.edges),diagnostics};
}

function validateSnapshot(snapshot,label) {
  const invalid=message=>{throw new Error(`Invalid ${label} snapshot: ${message}`);};
  if(snapshot?.schemaVersion!==1||snapshot.mode!=='report-only')invalid('schema/mode');
  if(!isDeepStrictEqual(snapshot.contract,qualityContract))invalid('contract mismatch; do not refresh a baseline to hide changed measurement rules');
  if(!Array.isArray(snapshot.modules)||!Array.isArray(snapshot.diagnostics)||!Array.isArray(snapshot.dependencies)||!Array.isArray(snapshot.cycles))invalid('collections');
  const files=new Set();
  for(const m of snapshot.modules) {
    if(typeof m.file!=='string'||!/^src\/lua\/.+\.lua$/.test(m.file)||files.has(m.file)
      ||!Number.isSafeInteger(m.lines)||m.lines<0||!/^[a-f0-9]{64}$/.test(m.sha256)||!Array.isArray(m.functions)||!m.functions.length)invalid('module metrics/duplicate file');
    files.add(m.file);
    const ids=new Set();
    for(const f of m.functions) {
      if(typeof f.id!=='string'||ids.has(f.id)||typeof f.name!=='string'||!['chunk','function'].includes(f.kind)
        ||typeof f.constructorName!=='boolean'||!Number.isSafeInteger(f.complexity)||f.complexity<1
        ||!Number.isSafeInteger(f.line)||f.line<1||!Number.isSafeInteger(f.column)||f.column<1
        ||!Number.isSafeInteger(f.lines)||f.lines<0||!Number.isSafeInteger(f.endLine)||f.endLine<f.line)invalid('function metrics/duplicate identity');
      ids.add(f.id);
      if(f.kind==='function'&&(f.lines!==f.endLine-f.line+1||f.endLine>m.lines))invalid('function span inconsistent with source lines');
    }
    if(m.functions.filter(f=>f.kind==='chunk'&&f.id==='$').length!==1)invalid('main chunk missing');
  }
  for(const d of snapshot.diagnostics)if(typeof d.file!=='string'||typeof d.code!=='string'||typeof d.message!=='string'
    ||!Number.isSafeInteger(d.line)||d.line<1||!Number.isSafeInteger(d.column)||d.column<1)invalid('diagnostic');
  for(const edge of snapshot.dependencies)if(!Array.isArray(edge)||edge.length!==2||edge.some(n=>typeof n!=='string'))invalid('dependency');
  for(const cycle of snapshot.cycles)if(!Array.isArray(cycle.members)||!cycle.members.length||!Array.isArray(cycle.edges))invalid('cycle');
}

function collectionDiff(current,baseline,key=JSON.stringify) {
  const remaining=new Map();
  for(const row of baseline) {const k=key(row);remaining.set(k,[...(remaining.get(k)??[]),row]);}
  const added=[],unchanged=[];
  for(const row of current) {
    const rows=remaining.get(key(row));
    if(rows?.length){rows.pop();unchanged.push(row);}else added.push(row);
  }
  return {added,removed:[...remaining.values()].flat(),unchanged};
}

export function compareQuality(current,baseline) {
  validateSnapshot(current,'current');validateSnapshot(baseline,'baseline');
  const before=new Map(baseline.modules.map(m=>[m.file,m])),after=new Map(current.modules.map(m=>[m.file,m]));
  const modules=[],functions=[];
  for(const file of [...new Set([...before.keys(),...after.keys()])].sort()) {
    const old=before.get(file),now=after.get(file),status=!old?'added':!now?'removed':'present';
    modules.push({file,status,before:old?.lines??null,after:now?.lines??null,
      lineDelta:old&&now?now.lines-old.lines:null,sourceChanged:old&&now?old.sha256!==now.sha256:null});
    const a=new Map((old?.functions??[]).map(f=>[f.id,f])),b=new Map((now?.functions??[]).map(f=>[f.id,f]));
    for(const id of [...new Set([...a.keys(),...b.keys()])].sort()) {
      const prev=a.get(id),next=b.get(id);
      functions.push({file,id,status:!prev?'added':!next?'removed':'present',
        before:prev??null,after:next??null,lineDelta:prev&&next?next.lines-prev.lines:null,
        complexityDelta:prev&&next?next.complexity-prev.complexity:null});
    }
  }
  return {modules,functions,dependencies:collectionDiff(current.dependencies,baseline.dependencies),
    cycles:collectionDiff(current.cycles,baseline.cycles,c=>JSON.stringify(c.members)),
    diagnostics:collectionDiff(current.diagnostics,baseline.diagnostics,r=>JSON.stringify([r.file,r.line,r.column,r.code,r.message]))};
}

const readJson=file=>JSON.parse(readFileSync(file,'utf8'));
const digest=file=>sha256(readFileSync(file,'utf8').replaceAll('\r\n','\n'));
// Observational debt and the currently reviewed detector policy have different
// lifetimes. Never rewrite an old snapshot when a real responsibility moves.
export function policyErrors(inputs,policy) {
  const path='config/engineering-quality-policy.json';
  const invalid=()=>[{file:path,message:'Invalid active detection contract; no exceptions or missing pins allowed'}];
  const files=['.luacheckrc','config/lua-tools.json'];
  if(!policy||policy.schemaVersion!==1||policy.measurementContractVersion!==qualityContract.version
    ||!/^[a-f0-9]{40}$/.test(policy.sourceRevision??'')
    ||!isDeepStrictEqual(Object.keys(policy).sort(),['schemaVersion','measurementContractVersion','sourceRevision','inputs'].sort())
    ||!policy.inputs||!isDeepStrictEqual(Object.keys(policy.inputs).sort(),files)
    ||files.some(file=>!/^[a-f0-9]{64}$/.test(policy.inputs[file])))return invalid();
  return files.filter(file=>inputs[file]!==policy.inputs[file]).map(file=>({file,
    message:'Active detection contract changed; review required, do not refresh the historical baseline'}));
}
// Fresh per invocation; shared only by the combined engineering process.
export function collectEngineeringInputs({discover=discoverSources,
  policy=()=>readJson('config/architecture.json'),analyze=analyzeSources,lint=runStatic}={}) {
  const sources=discover(),byModule={};
  for(const [file,source] of Object.entries(sources)) {
    const name=file.slice('src/lua/'.length,-4).replaceAll('/','.');
    if(name in byModule)throw new Error(`Ambiguous Lua module identity: ${name}`);
    byModule[name]=source;
  }
  const architecture=analyze(byModule,policy());
  const warnings=lint([]),complexity=lint(['--max-cyclomatic-complexity','0','--only','561']);
  return {sources,byModule,architecture,warnings,complexity};
}
export function collectQuality(collected=collectEngineeringInputs()) {
  const {sources,byModule,architecture,warnings,complexity}=collected;
  if(warnings.tool.version!==qualityContract.luacheck||complexity.tool.version!==qualityContract.luacheck)throw new Error('Quality Luacheck contract mismatch');
  const measurements=measureSources(sources,complexity.diagnostics);
  const errors=[...architecture.errors,...measurements.errors];
  for(const name of qualityContract.watchedModules)if(!(name in byModule))errors.push({message:`Required watched module missing: ${name}`});
  const lintBaseline=readJson('config/luacheck-baseline.json');
  const unexpected=compareDiagnostics(warnings.diagnostics,lintBaseline.diagnostics);
  errors.push(...unexpected.map(row=>({...row,message:`Existing static gate: ${row.message}`})));
  errors.push(...warnings.diagnostics.filter(row=>/^[WE]1/.test(row.code)));
  const inputs=Object.fromEntries(['.luacheckrc','config/lua-tools.json','config/architecture.json','config/luacheck-baseline.json',
    'scripts/check-architecture.mjs','scripts/check-lua-static.mjs','scripts/lua-quality-metrics.mjs','scripts/check-engineering-quality.mjs',
    'scripts/check-engineering.mjs','package.json','package-lock.json'].map(file=>[file,digest(file)]));
  const snapshot=qualitySnapshot(measurements,architecture,warnings.diagnostics);
  return {snapshot,errors,architecture,inputs,tools:{parser:qualityContract.parser,luacheck:warnings.tool},
    coverage:{modules:measurements.modules.length,functions:measurements.modules.reduce((n,m)=>n+m.functions.length-1,0),
      measurements:complexity.diagnostics.length,expectedMeasurements:measurements.modules.reduce((n,m)=>n+m.functions.length,0)}};
}

function revision() {
  try{return execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8',windowsHide:true,timeout:10000}).trim();}
  catch{return null;}
}
const escapeCell=value=>String(value).replaceAll('|','\\|').replaceAll('\n',' ');
export function renderQuality(report) {
  const {snapshot,coverage,diff}=report;
  const ranked=snapshot.modules.flatMap(m=>m.functions.filter(f=>f.kind==='function').map(f=>({file:m.file,...f})));
  const table=(headers,rows)=>[headers,headers.map(()=> '---'),...rows].map(r=>`| ${r.map(escapeCell).join(' | ')} |`).join('\n');
  const topFunctions=[...ranked].sort((a,b)=>b.lines-a.lines||a.file.localeCompare(b.file,'en')).slice(0,15);
  const topComplexity=snapshot.modules.flatMap(m=>m.functions.map(f=>({file:m.file,...f})))
    .sort((a,b)=>b.complexity-a.complexity||a.file.localeCompare(b.file,'en')).slice(0,15);
  return `# 工程质量报告\n\n${report.status}；新增数值门槛保持 report-only，不代表工程债务已治理。\n\n`
    +`源码提交：${report.revision??'unknown'}；基线：${report.baselineRevision??'unknown'}；活动规则源：${report.activePolicy?.sourceRevision??'unknown'}。以逐模块源码摘要为实际输入身份。\n\n`
    +`覆盖 ${coverage.modules} 模块、${coverage.functions} 函数；复杂度 ${coverage.measurements}/${coverage.expectedMeasurements} 项。\n\n`
    +table(['指定模块','文件行数','最长函数跨度','最高复杂度'],qualityContract.watchedModules.map(name=>{
      const m=snapshot.modules.find(m=>m.file===`src/lua/${name}.lua`);
      return [name,m?.lines??'missing',m?Math.max(...m.functions.filter(f=>f.kind==='function').map(f=>f.lines),0):'missing',
        m?Math.max(...m.functions.map(f=>f.complexity??0)):'missing'];
    }))+'\n\n## 最长函数（含构造器完整范围）\n\n'
    +table(['文件:行','函数','跨度','复杂度'],topFunctions.map(f=>[`${f.file}:${f.line}`,f.name,f.lines,f.complexity]))
    +'\n\n## 最高复杂度\n\n'+table(['文件:行','函数/初始化块','复杂度'],topComplexity.map(f=>[`${f.file}:${f.line}`,f.name,f.complexity]))
    +`\n\n## 完整依赖环\n\n${snapshot.cycles.length} 个强连通分量（不是简单环数量），包含延迟 require；内部调用点详见 JSON。\n\n`
    +snapshot.cycles.map(c=>`- 成员：${c.members.join('、')}；${c.edges.length} 内部调用点（成员列表不是一条环路径）`).join('\n')
    +`\n\n## 相对固定基线\n\n静态告警 ${snapshot.diagnostics.length} 条：新增 ${diff?.diagnostics.added.length??'?'}、移除 ${diff?.diagnostics.removed.length??'?'}。精确坐标移动按一增一减报告，不自动豁免。\n\n`
    +`检测输入相对原基线变化：${(report.ruleChanges??[]).join('、')||'无'}。活动身份仅固定当前规则，不改写历史数据。\n\n`
    +(diff?table(['模块','状态','原行数','现行数','变化'],diff.modules.filter(m=>m.status!=='present'||m.lineDelta!==0||m.sourceChanged).map(m=>[m.file,m.status,m.before,m.after,m.lineDelta])):'无可比较基线。')
    +`\n\n函数变化、依赖边增减、环变化、逐条告警和检测输入摘要见 JSON。改名/删除/拆分不等于职责验收通过，新增辅助模块同样全量测量。\n\n`
    +`## 完整性或既有规则错误\n\n${report.errors.length?report.errors.map(e=>`- ${e.file??''}:${e.line??''} ${e.message}`).join('\n'):'无。'}\n`;
}

export function main(args=[],collect=collectEngineeringInputs) {
  const started=Date.now();
  if(args.length>1||args[0]?.startsWith('-'))throw new Error('Usage: check-engineering-quality.mjs [baseline.json]; no refresh/exclude/threshold overrides');
  const baselineFile=args[0]??'config/engineering-quality-baseline.json';
  mkdirSync('build',{recursive:true});
  const report={schemaVersion:1,status:'failed',mode:'report-only',revision:revision(),createdAt:new Date().toISOString(),errors:[]};
  try {
    Object.assign(report,collectQuality(collect()));
    const baseline=readJson(baselineFile);
    report.baselineRevision=baseline.revision;report.baselineSha256=digest(baselineFile);
    report.diff=compareQuality(report.snapshot,baseline.snapshot);
    report.ruleChanges=Object.keys(report.inputs).filter(file=>baseline.inputs?.[file]!==report.inputs[file]);
    const policy=readJson('config/engineering-quality-policy.json');
    report.activePolicy={sourceRevision:policy.sourceRevision,sha256:digest('config/engineering-quality-policy.json'),inputs:policy.inputs};
    report.errors.push(...policyErrors(report.inputs,policy));
    report.status=report.errors.length?'failed':'reported';
  } catch(error) {report.errors.push({message:error.message});}
  report.durationMs=Date.now()-started;
  writeFileSync('build/engineering-quality.json',JSON.stringify(report,null,2)+'\n');
  writeFileSync('build/engineering-quality.md',report.snapshot?renderQuality(report):`# 工程质量采集失败\n\n${report.errors.map(e=>e.message).join('\n')}\n`);
  console.log(`Quality ${report.status}: ${report.coverage?.modules??0} modules; ${report.coverage?.measurements??0}/${report.coverage?.expectedMeasurements??0} measurements; new thresholds report-only. See build/engineering-quality.{json,md}`);
  if(report.errors.length){console.error(report.errors.map(e=>`${e.file??''}: ${e.message}`).join('\n'));process.exitCode=1;}
  return report;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try{main(process.argv.slice(2));}catch(error){console.error(error.message);process.exitCode=1;}
}
