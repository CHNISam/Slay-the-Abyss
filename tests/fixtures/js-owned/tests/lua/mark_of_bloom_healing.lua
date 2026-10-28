-- Real shared entry points with controlled owners; not natural event evidence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,H,P=require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks'),require('abyss_potion_health')
local Actions,Damage,Events=require('abyss_card_actions'),require('abyss_combat_effect_damage'),require('abyss_events')
local V4,V4Health=require('abyss_original_v4'),require('abyss_original_v4_health')
local Data=require('abyss_data')
local count,failures=0,{}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then count=count+1;print('ok Mark '..count..' '..name)
 else failures[#failures+1]=name..': '..tostring(why);print('not ok Mark '..failures[#failures])end
end
local function owned(id)return id=='none' and {} or {id}end
local function room(id,extra)
 local ids=owned(id);if extra then ids[#ids+1]=extra end
 return {hp=20,maxHp=80,gold=0,relics=ids,relicCounters={}}
end
local function state(id)
 local s=C.new(Data,{hp=20,maxHp=80,deck={'strike'},enemies={'cultist'}})
 H.bindBattle(s,owned(id),{});return s
end
for _,id in ipairs({'none','mark_of_bloom','Mark of the Bloom'})do
 local blocked=id~='none'
 test(id..' blood potion and fruit preserve maxHP while suppressing actual healing',function()
  local p=room(id);local ok,n=P.apply(p,'healPercent',20,p.relics,true);assert(ok);eq(n,blocked and 0 or 16)
  eq(p.hp,blocked and 20 or 36)
  ok,n=P.apply(p,'increaseMaxHp',5,p.relics,true);assert(ok);eq(p.maxHp,85);eq(n,blocked and 0 or 5)
 end)
 test(id..' Meal Ticket and outside Toy Ornithopter',function()
  local r=room(id,'meal_ticket');H.onEnterRoom(r,'shop');eq(r.hp,blocked and 20 or 35)
  r.relics[#r.relics+1]='toy_ornithopter';H.onUsePotion(r);eq(r.hp,blocked and 20 or 40)
 end)
 test(id..' Strawberry equip keeps seven maximum HP',function()
  local r=room(id);H.onEquip(r,'strawberry');eq(r.maxHp,87);eq(r.hp,blocked and 20 or 27)
 end)
 test(id..' Blood Vial real opening hook',function()
  local s=state(id);H.battleStart(s,'blood_vial');eq(s.player.hp,blocked and 20 or 22)
 end)
 test(id..' queued card/relic healing remains blocked',function()
  local s=state(id);Actions.apply(C,s,{effect={op='heal',value=5,relic='toy_ornithopter'},source=s.player})
  eq(s.player.hp,blocked and 20 or 25)
 end)
 test(id..' Reaper continuation uses the player heal gate',function()
  local s=state(id);Damage.heal({combat=C,state=s,effect={op='heal',value=13},helpers={event=Events.emit}})
  eq(s.player.hp,blocked and 20 or 33)
 end)
 test(id..' Feed keeps maximum HP but suppresses its healing',function()
  local s=state(id);local enemy=s.enemies[1]
  Actions.apply(C,s,{effect={op='feed',value=1000,maxHp=3},source=s.player,target=enemy})
  eq(enemy.hp,0);eq(s.player.maxHp,83);eq(s.player.hp,blocked and 20 or 23)
 end)
 test(id..' Regen still decays and enemy Regen is unaffected',function()
  local s=state(id);C.addStatus(s.player,'regen',3);A.endTurn(s,s.player)
  eq(s.player.hp,blocked and 20 or 23);eq(s.player.statuses.regen,2)
  local enemy=s.enemies[1];enemy.hp,enemy.maxHp=20,80;C.addStatus(enemy,'regen',3);A.endTurn(s,enemy)
  eq(enemy.hp,23);eq(enemy.statuses.regen,2)
 end)
 for _,role in ipairs({'HT','AR','FR','RD'})do
  test(id..' original '..role..' actual-heal ledger',function()
   local s=state(id);V4.init(s,role,require('abyss_original_v4_data').rules)
   local amount=V4Health.heal(s,s.player,6,role=='AR' and 'burst' or nil,'mark_component')
   eq(amount,blocked and 0 or 6);eq(s.player.hp,blocked and 20 or 26)
   eq(s.originalV4.healUsed,blocked and 0 or 6)
   if blocked then eq(s.originalV4.fan,0);eq(s.originalV4.fanGained,0)end
  end)
 end
end
assert(#failures==0,table.concat(failures,'\n'))
eq(count,36)
print('MARK_BLOOM_HEALING_PASS '..count..' no-Mark controls and both identity forms')
