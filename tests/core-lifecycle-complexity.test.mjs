import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewResponsibilityComplexity,reviewModuleSize} from '../scripts/check-lua-static.mjs';

const scopes={
 'src/lua/abyss_actor.lua':['M.status','M.applyPower','M.addStatus','M.endTurn'],
 'src/lua/abyss_combat.lua':['M.damage','draw'],
};
const row=(file,column,subject,value)=>({file,line:1,column,code:'W561',
 message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
test('core lifecycle entries and their nested callbacks enforce CC15',()=>{
 for(const [file,names]of Object.entries(scopes))for(const name of names){
  const source=`function ${name}() return function() end end`;
  const rows=[row(file,1,'main chunk',1),row(file,1,`function '${name}'`,16),
   row(file,source.indexOf('function()')+1,'function',16)];
  const errors=reviewResponsibilityComplexity(rows,{[file]:source}).errors;
  assert(errors.some(e=>e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`),name);
  assert(errors.some(e=>e.message==='Responsibility complexity 16 exceeds 15: function'),name+' nested');
  assert(reviewResponsibilityComplexity([],{[file]:source}).errors
   .some(e=>e.message===`Required responsibility entry missing or duplicated: function '${name}'`),name+' required');
 }
});
test('all Power leaf functions and nested callbacks are governed',()=>{
 const file='src/lua/abyss_actor_power_rules.lua';
 const source='local function validateAmount() return function() end end';
 const rows=[row(file,1,'main chunk',1),row(file,7,"function 'validateAmount'",15),
  row(file,source.indexOf('function()')+1,'function',16)];
 assert(reviewResponsibilityComplexity(rows,{[file]:source}).errors.some(e=>e.file===file&&e.message.includes('16 exceeds 15')));
});
test('Actor and its pure rules cannot regrow past the module size boundary',()=>{
 for(const file of ['src/lua/abyss_actor.lua','src/lua/abyss_actor_power_rules.lua']){
  assert(reviewModuleSize({[file]:Array(1001).fill('-- line').join('\n')}).errors.some(e=>e.file===file));
  assert(reviewModuleSize({}).errors.some(e=>e.file===file));
 }
});
