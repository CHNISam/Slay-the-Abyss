import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua,buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-potion-production-channels.json','utf8'));
const setup=`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function win(run)
 for _=1,160 do
  if run.phase~='combat'then break end
  local uid
  for _,card in ipairs(run.combat.hand)do if C.canPlay(run.combat,card.uid,1)then uid=card.uid;if C.cardDefinition(run.combat,card).type=='attack'then break end end end
  if uid then assert(Run.play(run,uid,1))else assert(Run.endTurn(run))end
 end
 assert(run.phase=='reward','starter combat failed')
end
`;
function lua(body){const dir=mkdtempSync(join(tmpdir(),'potion-channels-'));try{const path=join(dir,'case.lua');writeFileSync(path,setup+body);const r=runLua(path);assert.equal(r.status,0,r.stderr||r.stdout);}finally{rmSync(dir,{recursive:true,force:true});}}
buildLuaData();
test('fixed independent oracle freezes every original potion in both acquisition channels',()=>{
 assert.equal(fixture.drops.length,33);assert.equal(fixture.shop.length,33);
 assert.equal(new Set(fixture.drops.map(p=>p.id)).size,33);
 assert.deepEqual(fixture.drops.map(p=>p.sourceId),fixture.shop.map(p=>p.sourceId));
});
for(let offset=0;offset<33;offset+=6)test(`unchanged starter combat awards, carries and uses full-pool bottles ${offset+1}-${Math.min(offset+6,33)}`,()=>{
 lua(`for _,row in ipairs(${toLua(fixture.drops.slice(offset,offset+6))})do
 local run=Run.new(Data,row.seed);assert(Run.startCombat(run,'cultist_solo'));win(run)
 assert(run.rewards.potion.id==row.id,row.id);same(R.snapshot(run.shopRng.potion),row.after)
 assert(Run.claimPotionReward(run));assert(run.potions[1]==row.id);assert(Run.claimCardReward(run,0))
 dofile('tests/lua/support/finish_combat_rewards.lua')(run);assert(run.phase=='map');assert(run.potions[1]==row.id)
 assert(Run.startCombat(run,'cultist_solo'))
 if row.id=='fairy_in_a_bottle'then
  for _=1,20 do if not run.potions[1]then break end;assert(Run.endTurn(run))end
  assert(run.potions[1]==nil and run.combat.player.hp>0)
 else
  assert(Run.usePotion(run,1,1),row.id)
  local p=run.combat.pendingChoice
  if p then assert(Run.chooseCard(run,p.token,p.multiple and 0 or 1))end
  if row.id~='entropic_brew'then assert(run.potions[1]==nil,row.id)else assert(Run.potionCount(run)>0)end
 end
 print('POTION_REAL_CHANNEL '..row.id)
end`);
});
for(let offset=0;offset<33;offset+=6)test(`normal initial shop sells original bottles ${offset+1}-${Math.min(offset+6,33)} without reroll on full inventory`,()=>{
 lua(`local Shop,Nodes=require('abyss_shop'),require('abyss_nodes')
for _,row in ipairs(${toLua(fixture.shop.slice(offset,offset+6))})do
 local run=Run.new(Data,row.seed);local flow=Shop.prepare(run);local offer=flow.potions[row.slot]
 assert(offer.id==row.id and not offer.unavailable,row.id)
 run.phase='node';flow.type='shop';run.nodeFlow=flow;run.gold=10000;run.shopRng=flow.shopRng
 for _=1,3 do assert(Run.obtainPotion(run,'block_potion'))end
 local rng=R.snapshot(run.shopRng.potion);local gold=run.gold
 assert(not Nodes.buyPotion(run,row.slot));same(R.snapshot(run.shopRng.potion),rng);assert(run.gold==gold)
 assert(Run.discardPotion(run,2));assert(Nodes.buyPotion(run,row.slot));assert(run.potions[2]==row.id)
 assert(run.gold==gold-offer.price);same(R.snapshot(run.shopRng.potion),rng)
 assert(not Nodes.buyPotion(run,row.slot));assert(run.gold==gold-offer.price)
end`);
});
