import test from 'node:test';
import assert from 'node:assert/strict';
import { reviewResponsibilityComplexity } from '../scripts/check-lua-static.mjs';

const file = 'src/lua/abyss_effects.lua';
const roots = {[file]: ["function 'M.apply'"]};
const row = (path, line, column, subject, value) => ({file:path,line,column,code:'W561',
  message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
function fixture() {
  const lines = ['local message="汉字"', 'function M.apply()', ' local hidden=function() end', 'end',
    'local function legacy() end', 'return M'];
  return {sources:{[file]:lines.join('\n')}, diagnostics:[row(file,1,1,'main chunk',1),
    row(file,2,1,"function 'M.apply'",15), row(file,3,lines[2].indexOf('function')+1,'function',15),
    row(file,5,7,"function 'legacy'",88)]};
}
test('scoped responsibility budgets include nested callbacks and preserve unrelated hotspots', () => {
  const f=fixture();
  assert.deepEqual(reviewResponsibilityComplexity(f.diagnostics,f.sources,roots).errors,[]);
  f.diagnostics[2]=row(file,3,15,'function',16);
  assert.ok(reviewResponsibilityComplexity(f.diagnostics,f.sources,roots).errors.some(e=>e.message.includes('16 exceeds 15')));
  for (const old of [244,189,246,191,147,289,139,143,97,141]) {
    f.diagnostics[1]=row(file,2,1,"function 'M.apply'",old);
    assert.ok(reviewResponsibilityComplexity(f.diagnostics,f.sources,roots).errors.some(e=>e.message.includes(`${old} exceeds 15`)));
  }
});
test('every extracted helper and anonymous function receives the same budget', () => {
  const f=fixture(), helper='src/lua/abyss_effects_extra.lua', source='return {run=function() end}';
  f.sources[helper]=source;
  f.diagnostics.push(row(helper,1,1,'main chunk',1),row(helper,1,source.indexOf('function')+1,'function',16));
  assert.ok(reviewResponsibilityComplexity(f.diagnostics,f.sources,roots).errors.some(e=>e.file===helper&&e.message.includes('16 exceeds 15')));
  f.diagnostics.at(-1).message='cyclomatic complexity of function is too high (15 > 0)';
  assert.deepEqual(reviewResponsibilityComplexity(f.diagnostics,f.sources,roots).errors,[]);
});
test('potion candidate helpers cannot move branching outside the responsibility budget', () => {
  const helper='src/lua/abyss_run_potion_candidate.lua';
  const source='local function prepare() return function() end end; return prepare';
  const diagnostics=[row(helper,1,1,'main chunk',1),
    row(helper,1,7,"function 'prepare'",15),
    row(helper,1,source.indexOf('function()')+1,'function',16)];
  assert.ok(reviewResponsibilityComplexity(diagnostics,{[helper]:source},{}).errors
    .some(error=>error.file===helper&&error.message.includes('16 exceeds 15')));
  diagnostics[2].message='cyclomatic complexity of function is too high (15 > 0)';
  assert.deepEqual(reviewResponsibilityComplexity(diagnostics,{[helper]:source},{}).errors,[]);
});

test('every extracted exhaustion helper is required and bounded with its nested functions',()=>{
  const path='src/lua/abyss_card_actions.lua';
  const names=['exhaustRandom','fiendFire','exhaustNonAttacks','exhaustSpecific'];
  const source=names.map(name=>`local function ${name}() return function() end end`).join('\n');
  const diagnostics=[row(path,1,1,'main chunk',1)];
  for(const [i,name] of names.entries()){
    diagnostics.push(row(path,i+1,7,`function '${name}'`,15));
    diagnostics.push(row(path,i+1,source.split('\n')[i].indexOf('function()')+1,'function',1));
  }
  const report=()=>reviewResponsibilityComplexity(diagnostics,{[path]:source});
  assert.equal(report().errors.filter(e=>e.file===path).length,0);
  for(const diagnostic of diagnostics.slice(1)){
    const original=diagnostic.message;
    diagnostic.message=original.replace(/\(\d+ > 0\)/,'(16 > 0)');
    assert.ok(report().errors.some(e=>e.file===path&&e.message.includes('16 exceeds 15')));
    diagnostic.message=original;
  }
  for(const name of names){
    const removed=diagnostics.filter(d=>!d.message.includes(`'${name}'`));
    assert.ok(reviewResponsibilityComplexity(removed,{[path]:source}).errors
      .some(e=>e.file===path&&e.message.includes('entry missing')));
  }
});
test('restoring the original Run potion candidate hotspot fails the production policy', () => {
  const run='src/lua/abyss_run.lua',source='local function potionCandidate() end';
  const diagnostics=[row(run,1,1,'main chunk',1),row(run,1,7,"function 'potionCandidate'",53)];
  const report=reviewResponsibilityComplexity(diagnostics,{[run]:source});
  assert.ok(report.errors.some(error=>error.file===run&&error.message.includes('53 exceeds 15')));
  assert.ok(report.errors.some(error=>error.file==='src/lua/abyss_run_potion_candidate.lua'
    &&error.message.includes('Required responsibility module missing')));
});
test('missing entries, missing measurements, duplicate positions and unknown formats fail closed', () => {
  const f=fixture(), review=(d=f.diagnostics,s=f.sources)=>reviewResponsibilityComplexity(d,s,roots).errors;
  assert.ok(review(f.diagnostics,{}).some(e=>e.message.includes('module missing')));
  assert.ok(review(f.diagnostics.slice(1)).some(e=>e.message.includes('Incomplete')));
  const missing=f.diagnostics.map(r=>({...r})); missing[1].message="cyclomatic complexity of function 'renamed' is too high (1 > 0)";
  assert.ok(review(missing).some(e=>e.message.includes('entry missing')));
  const duplicate=[...f.diagnostics];duplicate[2]={...duplicate[1]};
  assert.ok(review(duplicate).some(e=>e.message.includes('Duplicate')));
  const malformed=f.diagnostics.map(r=>({...r}));malformed[2].message='unexpected tool output';
  assert.ok(review(malformed).some(e=>e.message.includes('Unrecognized')));
});
test('each AST function needs its own measurement even when counts remain equal', () => {
  for (const [line,column] of [[6,1],[5,8]]) {
    const f=fixture(); f.diagnostics[2]=row(file,line,column,'function',16);
    const errors=reviewResponsibilityComplexity(f.diagnostics,f.sources,roots).errors;
    assert.ok(errors.some(e=>e.message.includes('no corresponding AST')));
    assert.ok(errors.some(e=>e.message.includes('Incomplete AST')));
  }
});
test('Luacheck Unicode codepoint columns map to the byte AST on the same line', () => {
  // Positions independently measured with pinned Luacheck 1.2.0 stdin.
  for (const [label,entry,callback] of [['汉字',19,45],['😀',18,44],['e\u0301',19,45]]) {
    const source=`local label="${label}"; function M.apply() return function() if true then return 1 end end end`;
    const diagnostics=[row(file,1,1,'main chunk',1),row(file,1,entry,"function 'M.apply'",1),row(file,1,callback,'function',2)];
    assert.deepEqual(reviewResponsibilityComplexity(diagnostics,{[file]:source},roots).errors,[],label);
  }
});
test('main chunk and a function at the first source position are distinct measurements', () => {
  const source='function M.apply() end';
  const diagnostics=[row(file,1,1,'main chunk',88),row(file,1,1,"function 'M.apply'",1)];
  assert.deepEqual(reviewResponsibilityComplexity(diagnostics,{[file]:source},roots).errors,[]);
});
test('the extracted wording formatter is required and restoring the old local hotspot is also budgeted', () => {
  const adapter='src/lua/abyss_character_presentation.lua', formatter='src/lua/abyss_character_presentation_text.lua';
  const policy={[adapter]:[],[formatter]:["function 'fragments'"]};
  const sources={[adapter]:"local fragments=require('abyss_character_presentation_text').fragments",[formatter]:'local function fragments() end; return {fragments=fragments}'};
  const diagnostics=[row(adapter,1,1,'main chunk',1),row(formatter,1,1,'main chunk',1),row(formatter,1,7,"function 'fragments'",15)];
  assert.deepEqual(reviewResponsibilityComplexity(diagnostics,sources,policy).errors,[]);
  sources[adapter]='local function fragments() end';
  diagnostics.push(row(adapter,1,7,"function 'fragments'",289));
  assert.ok(reviewResponsibilityComplexity(diagnostics,sources,policy).errors.some(e=>e.message.includes('289 exceeds 15')));
  assert.ok(reviewResponsibilityComplexity(diagnostics.filter(r=>r.file!==formatter),{[adapter]:sources[adapter]},policy).errors.some(e=>e.message.includes('module missing')));
});
