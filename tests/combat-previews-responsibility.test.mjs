import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {baseline,sha256,revision} from './helpers/combat-previews-source.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const file='src/lua/abyss_combat.lua';
const hash=s=>createHash('sha256').update(s).digest('hex');
assert.equal(revision,'a308edbfde7792485cbe79b5650c17e1c7de98cc');
assert.equal(sha256,'03f028b6dfd90d867beca29a820bd5221377bf688c4ec5dfe0b00a3e69f55a1a');
assert.equal(hash(baseline),sha256);
function execute(source){
 const dir=mkdtempSync(join(tmpdir(),'combat-previews-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/combat_previews_responsibility.lua').replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:64*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('complete frozen Combat/new preview independent VM differential and input graph',t=>{
 const before=execute(baseline),after=execute(readFileSync(file,'utf8'));
 for(const r of [before,after]){assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/COMBAT_PREVIEWS_PASS /);}
 assert.equal(after.stdout,before.stdout,'full results, errors/return counts, input graph/aliases and all RNG');
 t.diagnostic(`complete old source ${sha256}; output ${hash(after.stdout)} (${Buffer.byteLength(after.stdout)} bytes)`);
});
test('preview semantic mutations are rejected at real boundary assertions',()=>{
 const source=readFileSync(file,'utf8');
 const mutations=[
  ['sparse effect positions','if slot then result[i]=slot','if slot then result[#result+1]=slot'],
  ['neutral aimed cannot borrow live enemy','local targeted = Actors.isActive(aimed)','local targeted = Actors.isActive(aimed) or Actors.isActive(state.enemies[2])'],
  ['AOE display first physical slot','value = targets[1]','value = targets[2]'],
  ['random engine neutral receiving modifiers','Actors.attackAmount(state,player,{statuses={}},effect.value)','Actors.attackAmount(state,player,aimed,effect.value)'],
  ['Halt separate floors','amount=amount+Actors.blockAmount(state,player,effect.wrathValue)','amount=Actors.blockAmount(state,player,effect.value+effect.wrathValue)'],
  ['Spirit Shield UID equality','held.uid==instance.uid','held==instance'],
  ['dynamic op cannot be cached','for i,effect in ipairs(effects)do','for i,effect in ipairs(effects)do\n            effect=setmetatable({op=effect.op},{__index=effect})'],
  ['nil effects retain failure','return previews(state, player, aimed, instance, card.effects)','return previews(state, player, aimed, instance, card.effects or {})'],
 ];
 for(const [label,before,after]of mutations){
  assert.equal(source.split(before).length-1,1,`${label}: exact mutation site`);
  const r=execute(source.replace(before,after));
  assert.notEqual(r.status,0,`${label}: survived`);
  assert.match(r.stdout+r.stderr,/\[COMBAT_PREVIEWS\]/,`${label}: real assertion failure`);
 }
});
