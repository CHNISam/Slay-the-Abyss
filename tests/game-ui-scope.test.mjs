import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {sha256} from '../scripts/evidence-files.mjs';
import {requireLuaTool} from '../scripts/setup-lua-static.mjs';
import {discoverSources,measureSources,reviewGameUiMeasurements} from '../scripts/lua-quality-metrics.mjs';
import {runStatic,parseDiagnostics,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';

const entry='src/lua/abyss_game_ui.lua';
const helper='src/lua/abyss_game_ui_input.lua';
const required=['overlays','view','run','lifecycle','input','menu_view'];
const row=(file,line,column,name,value=1)=>({file,line,column,code:'W561',
  message:`cyclomatic complexity of ${name} is too high (${value} > 0)`});
function fixture({constructorLines=200,callback=150,entryLines=250,helperLines=1000,helperName='M.bind'}={}) {
  const sources={},diagnostics=[];
  function add(file,source,rows=[]) {
    sources[file]=source;diagnostics.push(row(file,1,1,'main chunk'),...rows);
  }
  const code=['function M.new()',...Array(constructorLines-2).fill('-- constructor body'),'end'];
  while(code.length<entryLines)code.push('-- physical line');
  add(entry,code.join('\n')+'\n',[row(entry,1,1,"function 'M.new'")]);
  for(const name of required) {
    const file=`src/lua/abyss_game_ui_${name}.lua`;
    if(file!==helper){add(file,'return {}\n');continue;}
    const lines=[`function ${helperName}()`,...Array(callback-2).fill('-- callback body'),'end'];
    while(lines.length<helperLines)lines.push('-- physical line');
    add(file,lines.join('\n')+'\n',[row(file,1,1,`function '${helperName}'`)]);
  }
  return {sources,diagnostics};
}
const evaluate=f=>reviewGameUiMeasurements(measureSources(f.sources,f.diagnostics),f.sources);

test('exact entry constructor200/other150 and physical module limits250/1000 pass',()=>{
  const f=fixture();assert.deepEqual(evaluate(f).errors,[]);
  const crlf={...f,sources:Object.fromEntries(Object.entries(f.sources).map(([k,v])=>[k,v.replaceAll('\n','\r\n')]))};
  assert.deepEqual(evaluate(crlf),evaluate(f));
});

test('overlong complete spans and physical files fail, including helpers named new',()=>{
  for(const [options,pattern]of [
    [{constructorLines:201},/span 201 exceeds 200/],
    [{callback:151},/span 151 exceeds 150/],
    [{callback:151,helperName:'M.new'},/span 151 exceeds 150/],
    [{entryLines:251},/module length 251/],
    [{helperLines:1001},/module length 1001/],
  ])assert.ok(evaluate(fixture(options)).errors.some(e=>pattern.test(e.message)),JSON.stringify(options));
  const f=fixture({constructorLines:202,entryLines:250});
  f.sources[entry]=f.sources[entry].replace('function M.new()','function M.new()\n local hidden=function()'+ '\n-- nested body'.repeat(149)+'\n end');
  f.diagnostics.push(row(entry,2,15,'function'));
  assert.ok(evaluate(f).errors.some(e=>/span 151 exceeds 150/.test(e.message)),'anonymous complete span');
});

test('all function and chunk CC16, missing modules, malformed or stale measurements fail closed',()=>{
  const f=fixture(),measured=measureSources(f.sources,f.diagnostics);
  for(const index of [0,1]) {
    const changed=structuredClone(measured);changed.modules.find(m=>m.file===entry).functions[index].complexity=16;
    assert.ok(reviewGameUiMeasurements(changed,f.sources).errors.some(e=>/complexity 16/.test(e.message)));
  }
  for(const mutate of [
    m=>m.modules.pop(),m=>m.modules.push(m.modules[0]),
    m=>m.modules[0].functions.push(m.modules[0].functions[1]),
    m=>delete m.modules[0].functions[1].complexity,
    m=>delete m.modules[0].functions[1].endLine,
    m=>m.modules[0].functions.splice(1,1),
    m=>m.modules[0].sha256='0'.repeat(64),
    m=>m.errors.push({message:'Missing AST/W561 measurement'}),
  ]) {
    const changed=structuredClone(measured);mutate(changed);
    assert.ok(reviewGameUiMeasurements(changed,f.sources).errors.length,'malformed report rejected');
  }
  const drift={...f.sources,[helper]:f.sources[helper]+'-- drift\n'};
  assert.ok(reviewGameUiMeasurements(measured,drift).errors.some(e=>/current source/.test(e.message)));
  const missing={...f.sources};delete missing[helper];
  assert.ok(reviewGameUiMeasurements(measured,missing).errors.some(e=>/module missing/.test(e.message)));
  for(const diagnostics of [f.diagnostics.slice(1),[...f.diagnostics,f.diagnostics[1]],
    f.diagnostics.map((r,i)=>i===1?{...r,column:r.column+1}:r)])
    assert.ok(reviewGameUiMeasurements(measureSources(f.sources,diagnostics),f.sources).errors.length);
});

test('complete CardActions and GameUI include unlisted private functions and chunks in CC15',()=>{
  for(const file of [entry,'src/lua/abyss_card_actions.lua']) {
    const source='local function unlisted() return function() end end';
    const diagnostics=[row(file,1,1,'main chunk'),row(file,1,7,"function 'unlisted'",16),row(file,1,source.indexOf('function()')+1,'function',16)];
    assert.equal(reviewResponsibilityComplexity(diagnostics,{[file]:source},{[file]:[]}).errors.filter(e=>/16 exceeds 15/.test(e.message)).length,2);
    diagnostics[0]=row(file,1,1,'main chunk',16);
    assert.equal(reviewResponsibilityComplexity(diagnostics,{[file]:source},{[file]:[]}).errors.filter(e=>/16 exceeds 15/.test(e.message)).length,3);
  }
});

test('real current GameUI complete AST/W561 scope stays within absolute budgets',()=>{
  const sources=discoverSources(),measurements=measureSources(sources,runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics);
  assert.deepEqual(reviewGameUiMeasurements(measurements,sources).errors,[]);
  const menu=measurements.modules.find(m=>m.file.endsWith('/abyss_game_ui_menu_view.lua'));
  assert.ok(menu.lines<=1000);
  assert.ok(menu.functions.filter(f=>f.kind==='function').every(f=>f.lines<=150));
});

test('complete immutable old Host1004 and every prior CC hotspot are rejected by the same validator',()=>{
  const path=resolve('tests/fixtures/game-ui-host/old-host.lua');
  const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(sha256(source),'165e2ad1180cab9daf5321b46d1f87fe9c34ed6ebbcd3c3a8b495d23974e0933');
  const result=spawnSync(requireLuaTool().file,[path,'--formatter','plain','--codes','--ranges','--no-color','--max-cyclomatic-complexity','0','--only','561'],
    {encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
  assert.ifError(result.error);assert.equal(result.signal,null);assert.equal(result.status,1);assert.equal(result.stderr,'');
  const diagnostics=parseDiagnostics(result.stdout).map(r=>({...r,file:entry}));
  const measured=measureSources({[entry]:source},diagnostics);assert.deepEqual(measured.errors,[]);
  assert.equal(measured.modules[0].functions.length,143);
  const rejected=reviewGameUiMeasurements(measured,{[entry]:source});
  assert.ok(rejected.errors.some(e=>/span 1004 exceeds 200/.test(e.message)));
  assert.equal(rejected.errors.filter(e=>/complexity .* exceeds or invalid/.test(e.message)).length,11);
  assert.ok(rejected.errors.some(e=>/module length 1029/.test(e.message)));
});
