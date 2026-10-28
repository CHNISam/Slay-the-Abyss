import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { measureSources, dependencyCycles, discoverSources } from '../scripts/lua-quality-metrics.mjs';
import { analyzeSources } from '../scripts/check-architecture.mjs';
import { qualitySnapshot, compareQuality, qualityContract, renderQuality, main } from '../scripts/check-engineering-quality.mjs';
import { beforeQualityArtifacts, qualityWindowsUpload, qualityPosixPaths } from './helpers/quality-workflow.mjs';
import { preRetirementSource, retirementSources } from './helpers/presentation-announcement-retirement.mjs';

const row = (file,line,column,subject,value=1) => ({file:`src/lua/${file}.lua`,line,column,code:'W561',
  message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
const source = 'local M={}\nfunction M.new()\n -- 中文\n local callback=function() end\n return callback\nend\nreturn M\n';
const measured = () => measureSources({'src/lua/a.lua':source},[
  row('a',1,1,'main chunk'),row('a',2,1,"function 'M.new'",2),row('a',4,17,'function',3),
]);

test('physical lines and inclusive function spans include comments, blank lines and nested bodies',()=>{
  const report=measured();
  assert.deepEqual(report.errors,[]);
  assert.equal(report.modules[0].lines,7);
  assert.equal(report.modules[0].functions.length,3);
  const constructor=report.modules[0].functions.find(f=>f.name==='M.new');
  assert.equal(constructor.lines,5);
  assert.equal(constructor.constructorName,true);
  assert.equal(constructor.complexity,2);
  const renamed=source.replace('M.new','M.assemble');
  const changed=measureSources({'src/lua/a.lua':renamed},[
    row('a',1,1,'main chunk'),row('a',2,1,"function 'M.assemble'",2),row('a',4,17,'function',3),
  ]);
  assert.deepEqual(changed.errors,[]);
  assert.equal(changed.modules[0].functions.find(f=>f.name==='M.assemble').lines,5);
});

test('CRLF and LF have identical canonical metrics and source hashes',()=>{
  const lf=measured();
  const crlf=measureSources({'src/lua/a.lua':source.replaceAll('\n','\r\n')},[
    row('a',1,1,'main chunk'),row('a',2,1,"function 'M.new'",2),row('a',4,17,'function',3),
  ]);
  assert.deepEqual(crlf,lf);
});

test('every function and chunk needs exactly one matching Luacheck coordinate',()=>{
  const code='function M.new() return function() end end';
  const valid=[row('a',1,1,'main chunk'),row('a',1,1,"function 'M.new'"),row('a',1,25,'function')];
  assert.deepEqual(measureSources({'src/lua/a.lua':code},valid).errors,[]);
  for(const bad of [valid.slice(0,2),[...valid,valid[2]],
    [valid[0],valid[1],{...valid[2],column:24}],
    [valid[0],valid[1],{...valid[2],message:'unknown format'}],
    [valid[0],valid[1],{...valid[2],message:'cyclomatic complexity of something unknown is too high (1 > 0)'}],
    [...valid,row('missing',1,1,'main chunk')],
    [valid[0],valid[1],{...valid[2],message:'cyclomatic complexity of function is too high (NaN > 0)'}]]) {
    assert.ok(measureSources({'src/lua/a.lua':code},bad).errors.length,JSON.stringify(bad));
  }
  assert.ok(measureSources({'src/lua/a.lua':'local ='},[]).errors.length);
  assert.ok(measureSources({},[]).errors.length);
});

test('Unicode codepoint columns map to UTF8 AST bytes, including emoji and combining marks',()=>{
  for(const [label,first,second] of [['汉字',19,45],['😀',18,44],['e\u0301',19,45]]) {
    const code=`local label="${label}"; function M.apply() return function() if true then return 1 end end end`;
    assert.deepEqual(measureSources({'src/lua/a.lua':code},[
      row('a',1,1,'main chunk'),row('a',1,first,"function 'M.apply'"),row('a',1,second,'function',2),
    ]).errors,[],label);
  }
});

test('all files and extracted helpers are discovered recursively; empty scans fail',()=>{
  const root=mkdtempSync(join(tmpdir(),'quality-discovery-'));
  try {
    mkdirSync(join(root,'src/lua/nested'),{recursive:true});
    assert.throws(()=>discoverSources(root),/No Lua/);
    writeFileSync(join(root,'src/lua/main.lua'),'return {}');
    writeFileSync(join(root,'src/lua/nested/helper.lua'),'return {}');
    assert.deepEqual(Object.keys(discoverSources(root)),['src/lua/main.lua','src/lua/nested/helper.lua']);
  } finally {rmSync(root,{recursive:true,force:true});}
});

test('full graph reports reviewed deferred cycles, self cycles and disjoint SCCs deterministically',()=>{
  const sources={a:'return function() return require("b") end',b:'return require("a")',c:'return require("c")',d:'return {}'};
  const policy={layers:{a:'core',b:'core',c:'core',d:'core'},deferredImports:[{from:'a',to:'b'}]};
  const arch=analyzeSources(sources,policy,{});
  const cycles=dependencyCycles(arch.nodes,arch.edges);
  assert.deepEqual(cycles.map(c=>c.members),[['a','b'],['c']]);
  assert.equal(cycles[0].edges.length,2);
  assert.equal(cycles[0].edges.filter(e=>e.reviewedDeferred).length,1);
  assert.deepEqual(dependencyCycles([...arch.nodes].reverse(),[...arch.edges].reverse()),cycles);
  assert.deepEqual(dependencyCycles(['a','b'],[{from:'a',to:'b'}]),[]);
});

const warning={file:'src/lua/a.lua',line:3,column:1,code:'W211',message:"unused variable 'x'"};
function snapshot() {
  return qualitySnapshot(measured(),{nodes:['a'],edges:[],errors:[]},[warning]);
}

test('baseline diff keeps full metrics, exact warning multiplicity and changed/deleted/new modules visible',()=>{
  const baseline=snapshot(), current=structuredClone(baseline);
  current.modules[0].lines++;
  current.modules[0].functions[1].complexity=99;
  current.diagnostics.push({...warning});
  let diff=compareQuality(current,baseline);
  assert.equal(diff.modules[0].lineDelta,1);
  assert.equal(diff.functions.find(f=>f.id===current.modules[0].functions[1].id).complexityDelta,97);
  assert.deepEqual(diff.diagnostics.added,[warning]);
  assert.deepEqual(diff.diagnostics.removed,[]);
  current.diagnostics=[{...warning,line:4}];
  diff=compareQuality(current,baseline);
  assert.deepEqual(diff.diagnostics.added,current.diagnostics);
  assert.deepEqual(diff.diagnostics.removed,[warning]);
  current.modules=[];
  assert.equal(compareQuality(current,baseline).modules[0].status,'removed');
  current.modules=[{...baseline.modules[0],file:'src/lua/helper.lua'}];
  assert.deepEqual(compareQuality(current,baseline).modules.map(m=>m.status).sort(),['added','removed']);
});

test('baseline contract/tool/scope mismatch and malformed snapshots cannot be treated as improvement',()=>{
  const baseline=snapshot();
  assert.deepEqual(baseline.contract,qualityContract);
  assert.equal(baseline.mode,'report-only');
  for(const mutate of [b=>b.contract.version++,b=>b.contract.luacheck='other',
    b=>b.contract.watchedModules.pop(),b=>delete b.modules,b=>b.modules.push(b.modules[0]),
    b=>delete b.modules[0].functions[0].complexity,b=>b.modules[0].lines=-1,
    b=>b.modules[0].functions[1].lines--]) {
    const bad=structuredClone(baseline);mutate(bad);
    assert.throws(()=>compareQuality(baseline,bad),/baseline|contract|snapshot/i);
  }
});

test('JSON object key ordering does not create false warning changes or contract mismatches',()=>{
  const baseline=snapshot(),current=structuredClone(baseline);
  current.contract=Object.fromEntries(Object.entries(current.contract).reverse());
  current.diagnostics=current.diagnostics.map(r=>Object.fromEntries(Object.entries(r).reverse()));
  const diff=compareQuality(current,baseline);
  assert.deepEqual(diff.diagnostics.added,[]);
  assert.deepEqual(diff.diagnostics.removed,[]);
});

test('all new numeric metrics remain report-only, including high complexity and new helper hotspots',()=>{
  const baseline=snapshot(), current=structuredClone(baseline);
  const helper=structuredClone(current.modules[0]);helper.file='src/lua/a_helper.lua';
  helper.functions[1].complexity=999;helper.functions[1].lines=9999;
  helper.functions[1].endLine=helper.functions[1].line+9998;
  helper.lines=10001;helper.functions[0].lines=10001;helper.functions[0].endLine=10001;
  current.modules.push(helper);
  const diff=compareQuality(current,baseline);
  assert.equal(diff.functions.filter(f=>f.file===helper.file).length,helper.functions.length);
  const text=renderQuality({snapshot:current,coverage:{modules:2,functions:4,measurements:6,expectedMeasurements:6},
    diff,errors:[],status:'reported'});
  assert.match(text,/report-only/);
  assert.match(text,/a_helper\.lua/);
  assert.match(text,/9999/);
  assert.match(text,/999/);
  assert.throws(()=>main(['--refresh']),/no refresh/);
  assert.throws(()=>main(['--exclude=a.lua']),/no refresh/);
});

test('the frozen baseline covers every recorded module/function and is not an exemption configuration',()=>{
  const baseline=JSON.parse(readFileSync('config/engineering-quality-baseline.json','utf8'));
  const diff=compareQuality(baseline.snapshot,baseline.snapshot);
  assert.equal(baseline.revision,'1f260a71972b03dae5b63e8d6f12d055973a4c83');
  assert.equal(baseline.snapshot.modules.length,baseline.coverage.modules);
  assert.equal(baseline.snapshot.modules.reduce((n,m)=>n+m.functions.length,0),baseline.coverage.measurements);
  assert.equal(baseline.coverage.measurements,baseline.coverage.expectedMeasurements);
  assert.equal(diff.functions.length,baseline.coverage.measurements);
  assert.deepEqual(diff.diagnostics.added,[]);
  assert.ok(qualityContract.watchedModules.every(n=>baseline.snapshot.modules.some(m=>m.file===`src/lua/${n}.lua`)));
});

test('dependency and cycle changes are visible even when total module and warning counts stay equal',()=>{
  const before=snapshot(),after=structuredClone(before);
  after.dependencies=[['a','a']];after.cycles=[{members:['a'],edges:[{from:'a',to:'a',line:2}]}];
  const diff=compareQuality(after,before);
  assert.deepEqual(diff.dependencies.added,[['a','a']]);
  assert.equal(diff.cycles.added.length,1);
  assert.deepEqual(diff.diagnostics.added,[]);
});

test('quality reports are collected by the existing gate and uploaded on failed runs without changing older CI guards',()=>{
  const scripts=JSON.parse(readFileSync('package.json','utf8')).scripts;
  assert.equal(scripts['check:quality'],'node scripts/check-engineering-quality.mjs');
  assert.equal(scripts['check:engineering'],'npm run check:quality && npm run check:architecture && npm run check:lua-static && npm run check:test-strength && npm run check:native-ui-contract');
  const workflow=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
  assert.equal(workflow.split(qualityWindowsUpload).length,2);
  assert.equal(workflow.split(qualityPosixPaths).length,2);
  assert.ok(workflow.includes('        if: always() && matrix.shard == 1\n        with:\n          name: engineering-'));
  const restored=beforeQualityArtifacts(workflow);
  assert.ok(!restored.includes('build/engineering-quality.json'));
  for(const old of ['build/architecture.json','build/lua-static.json','build/lua-complexity.json','build/ui-complexity.json','build/test-strength/*/report.json'])assert.ok(restored.includes(old));
  // Inversion must not erase accidental changes in new upload scope or paths.
  for(const bad of [workflow.replace('build/engineering-quality.md','build/other.md'),
    workflow.replace('if-no-files-found: warn','if-no-files-found: error')]) {
    assert.ok(beforeQualityArtifacts(bad).includes('engineering-quality-windows-'));
  }
});

test('historical package replay inverts only the exact quality entry and gate wiring without changing its old hash',()=>{
  const live=readFileSync('package.json','utf8').replaceAll('\r\n','\n');
  const entry='    "check:quality": "node scripts/check-engineering-quality.mjs",\n';
  const before=retirementSources.beforeSources['package.json'];
  assert.equal(preRetirementSource('package.json',live),before);
  assert.equal(preRetirementSource('package.json',live.replaceAll('\n','\r\n')),before);
  const moved=live.replace(entry,'').replace('    "setup:lua-static":',entry+'    "setup:lua-static":');
  for(const bad of [live.replace(entry,''),live.replace(entry,entry+entry),moved,
    live.replace('node scripts/check-engineering-quality.mjs','node scripts/other.mjs'),
    live.replace('npm run check:quality && npm run check:architecture','npm run check:architecture'),
    live.replace('npm run check:lua-static && ','').replace('npm run check:quality && ',''),
    live+'\n',live.replace('"private": true','"private": false')]) {
    assert.notEqual(bad,live);
    assert.throws(()=>preRetirementSource('package.json',bad),/unreviewed integrated retirement source drift/);
  }
});
