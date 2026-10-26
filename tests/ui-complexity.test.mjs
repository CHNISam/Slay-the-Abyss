import test from 'node:test';
import assert from 'node:assert/strict';
import { reviewRenderComplexity } from '../scripts/check-lua-static.mjs';

const battle = 'src/lua/abyss_battle_ui.lua';
const card = 'src/lua/abyss_battle_card_view.lua';
const shop = 'src/lua/abyss_shop_ui.lua';
const display = 'src/lua/abyss_card_display.lua';
const row = (file, subject, value, line=1, column=1) => ({file,line,column,code:'W561',
  message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
function fixture() {
  return {
    sources:{[battle]:'local self={}; function self:render() end; return self', [card]:'return {}', [shop]:'return {}', [display]:'return {}'},
    diagnostics:[row(battle,'main chunk',1),row(battle,"method 'self.render'",10,1,16),
      row(card,'main chunk',1),row(shop,'main chunk',1),row(display,'main chunk',1)],
  };
}
test('absolute render budgets reject the original 274 and shop 33 while allowing the exact limits', () => {
  const f=fixture();
  assert.deepEqual(reviewRenderComplexity(f.diagnostics,f.sources).errors,[]);
  f.diagnostics[1]=row(battle,"method 'self.render'",274,1,16);
  f.diagnostics[3]=row(shop,'main chunk',33);
  const report=reviewRenderComplexity(f.diagnostics,f.sources);
  assert.ok(report.errors.some(error=>error.file===battle&&error.message.includes('274 exceeds 10')));
  assert.ok(report.errors.some(error=>error.file===shop&&error.message.includes('33 exceeds 15')));
});
test('extracted responsibilities and anonymous functions cannot hide an excessive branch count', () => {
  const f=fixture(), helper='src/lua/abyss_battle_extra_view.lua';
  f.sources[helper]='return {draw=function() end}';
  f.diagnostics.push(row(helper,'main chunk',1),row(helper,'function',16,1,14));
  assert.ok(reviewRenderComplexity(f.diagnostics,f.sources).errors.some(error=>error.message.includes('16 exceeds 15')));
  f.diagnostics.at(-1).message='cyclomatic complexity of function is too high (15 > 0)';
  assert.deepEqual(reviewRenderComplexity(f.diagnostics,f.sources).errors,[]);
});
test('missing modules, incomplete measurements, duplicates and unknown formats fail closed', () => {
  const f=fixture();
  assert.ok(reviewRenderComplexity(f.diagnostics.filter(r=>r.file!==shop),f.sources).errors.some(e=>e.message.includes('Incomplete')));
  const missing={...f.sources}; delete missing[shop];
  assert.ok(reviewRenderComplexity(f.diagnostics,missing).errors.some(e=>e.message.includes('module missing')));
  assert.ok(reviewRenderComplexity(f.diagnostics.filter(r=>!r.message.includes('self.render')),f.sources).errors.some(e=>e.message.includes('entry measurement missing')));
  const duplicate=[...f.diagnostics]; duplicate[1]={...duplicate[0]};
  assert.ok(reviewRenderComplexity(duplicate,f.sources).errors.some(e=>e.message.includes('Duplicate')));
  const invalid=[...f.diagnostics]; invalid[0]={...invalid[0],message:'not a complexity measurement'};
  assert.ok(reviewRenderComplexity(invalid,f.sources).errors.some(e=>e.message.includes('Unrecognized')));
});
