import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {reviewNodeUiSize} from '../scripts/check-lua-static.mjs';
const files=readdirSync('src/lua').filter(n=>/^abyss_node_ui(?:_.+)?\.lua$/.test(n));
const sources=Object.fromEntries(files.map(n=>['src/lua/'+n,readFileSync('src/lua/'+n,'utf8')]));
test('all Node UI modules and extracted functions respect the size contract',()=>{
 const report=reviewNodeUiSize(sources);assert.deepEqual(report.errors,[]);
 assert.ok(report.measurements.some(r=>r.file==='src/lua/abyss_node_ui.lua'&&r.functionLines));
});
test('size gate rejects a large constructor and a large extracted helper',()=>{
 for(const file of ['src/lua/abyss_node_ui.lua','src/lua/abyss_node_ui_rewards.lua']){
  const report=reviewNodeUiSize({...sources,[file]:'local function oversized()\n'+ '\n'.repeat(350)+'end\n'});
  assert.ok(report.errors.some(r=>r.file===file&&r.message.includes('350')));
 }
 assert.ok(reviewNodeUiSize({...sources,'src/lua/abyss_node_ui.lua':'-- header\n'.repeat(1001)}).errors.some(r=>r.message.includes('1000')));
});
