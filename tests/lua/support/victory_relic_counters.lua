local Run,C,D,View=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_relic_view_ui')
local M={}
local battleIds={'letter_opener','kunai','shuriken','ornamental_fan','stone_calendar','captains_wheel','pocketwatch'}
local function unchanged(root)
 local objects={}
 local function remember(value)
  if type(value)~='table'or objects[value]then return end
  local fields={};objects[value]=fields
  for key,entry in pairs(value)do fields[key]=entry;remember(key);remember(entry)end
 end
 remember(root)
 return function()
  for object,fields in pairs(objects)do
   for key,value in pairs(fields)do assert(object[key]==value,'original graph field changed: '..tostring(key))end
   for key in pairs(object)do assert(fields[key]~=nil,'new graph field: '..tostring(key))end
  end
 end
end
local function card(r,id)
 for _,c in ipairs(r.combat.hand)do if c.cardId==id then return c end end
 error('missing actual hand card '..id)
end
local function play(r,id)assert(Run.play(r,card(r,id).uid,1))end
local function start(encounter,formal)
 local r=Run.new(D,'42',{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
 local deck=C.copy(r.deck);for _,c in ipairs(deck)do assert(Run.removeCard(r,c.uid))end
 for _,id in ipairs({'defend','defend','strike','strike','deep_breath'})do assert(Run.obtainCard(r,id))end
 for _,id in ipairs(battleIds)do assert(Run.obtainRelic(r,id))end
 for _,id in ipairs({'sundial','ink_bottle','happy_flower','incense_burner','neows_lament','omamori','winged_greaves','matryoshka','meat_on_the_bone','face_of_cleric'})do assert(Run.obtainRelic(r,id))end
 r.hp=40 -- explicit pre-battle health precondition for healing-order boundary
 if encounter then r.floor=4 end
 if formal then assert(Run.startRoomCombat(r,'normal'));assert(r.combat.roomSeed,'real source-room transaction')
 else assert(Run.startCombat(r,encounter or 'cultist_solo'))end
 assert(r.combat.enemies[1].hp==1,'actual Neow effect provides lethal public encounter')
 play(r,'defend');play(r,'deep_breath')
 assert(r.combat.relicCounters.sundial==1,'actual Deep Breath shuffle advances permanent Sundial')
 return r
end
local function persistent(r,owner,second)
 local expected={sundial=1,ink_bottle=3,happy_flower=second and 2 or 1,incense_burner=second and 2 or 1,
  neows_lament=second and 1 or 2,omamori=2,winged_greaves=3,matryoshka=2}
 for id,value in pairs(expected)do assert(owner[id]==value,'persistent counter changed: '..id..' '..tostring(owner[id]))end
end
local function hidden(r)
 for _,id in ipairs(battleIds)do
  assert(r.relicCounters[id]==-1,'source victory counter must hide '..id..': '..tostring(r.relicCounters[id]))
  if r.combat then assert(r.combat.relicCounters[id]==-1,'combat victory owner must hide '..id)end
  assert(View.status(r,id)==nil,'reward/map public detail must not expose stale '..id)
 end
end
function M.lifecycle()
 local r=start();local heals={};local rawHeal=Run.heal
 Run.heal=function(owner,value)heals[#heals+1]={value,owner.hp};return rawHeal(owner,value)end
 play(r,'strike');Run.heal=rawHeal
 assert(r.phase=='reward');hidden(r);persistent(r,r.relicCounters)
 assert(#heals==3 and heals[1][1]==12 and heals[1][2]==40 and heals[2][1]==6 and heals[2][2]==52 and heals[3][1]==1 and heals[3][2]==58,'Meat/BurningBlood/Cleric order changed')
 assert(r.hp==59 and r.maxHp==81 and r.victories==1)
 local stable=unchanged(r);assert(not Run.finishCombat(r));stable()
 assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 assert(r.phase=='map');hidden(r);persistent(r,r.relicCounters)
 stable=unchanged(r);assert(not Run.finishCombat(r));stable()
 assert(Run.startCombat(r,'cultist_solo'))
 local counters=r.combat.relicCounters
 for _,id in ipairs({'letter_opener','kunai','shuriken','ornamental_fan','pocketwatch'})do assert(counters[id]==0 and View.status(r,id)=='计数 0','next battle resets '..id)end
 assert(counters.stone_calendar==1 and counters.captains_wheel==1,'real first-turn hooks follow battle reset')
 persistent(r,counters,true)
 play(r,'defend');assert(r.combat.relicCounters.letter_opener==1 and r.combat.relicCounters.pocketwatch==1)
 assert(View.status(r,'letter_opener')=='计数 1','next battle counts real cards again')
 print('VICTORY_RELIC_COUNTER_LIFECYCLE_PASS 7')
end
function M.rollback()
 local r=start(nil,true);local s=r.combat;local strike=card(r,'strike');local stable=unchanged(r)
 local Pool=require('abyss_card_pool');local raw=Pool.prepareRewards;local reached=false
 Pool.prepareRewards=function(owner,...)
  local results={raw(owner,...)}
  reached=true;hidden(owner);assert(owner.hp==59 and owner.maxHp==81,'late failure follows all victory healing')
  error('injected after victory reward sampling')
 end
 local called,why=pcall(Run.play,r,strike.uid,1);Pool.prepareRewards=raw
 assert(reached and not called and tostring(why):find('injected after victory reward sampling',1,true),tostring(why))
 stable();assert(r.phase=='combat' and r.combat==s and r.hp==40 and r.maxHp==80 and r.victories==0)
 assert(r.combat.relicCounters.letter_opener==2 and r.combat.relicCounters.kunai==0,'rollback restored original battle counters')
 assert(Run.play(r,strike.uid,1));assert(r.phase=='reward');hidden(r);persistent(r,r.relicCounters)
 assert(r.hp==59 and r.maxHp==81 and r.victories==1,'retry commits healing once')
 stable=unchanged(r);assert(not Run.finishCombat(r));stable()
 print('VICTORY_RELIC_COUNTER_ROLLBACK_PASS')
end
function M.otherOutcomes()
 for _,outcome in ipairs({'escape','defeat'})do
  local r=start();local before=C.copy(r.combat.relicCounters)
  if outcome=='escape'then
   assert(Run.obtainPotion(r,'smoke_bomb'));assert(Run.usePotion(r,1));assert(r.phase=='map' and r.lastResult.outcome=='escaped')
  else
   C.damage(r.combat,r.combat.enemies[1],r.combat.player,1000,true)
   assert(Run.finishCombat(r));assert(r.phase=='defeat')
  end
  if outcome=='escape'then
   hidden(r)
   for id,value in pairs(before)do
    local battleOnly=false;for _,battleId in ipairs(battleIds)do if battleId==id then battleOnly=true end end
    if not battleOnly then assert(r.relicCounters[id]==value,'escape changed permanent counter: '..id)end
   end
   assert(r.hp==40 and r.maxHp==80 and r.rewards==nil and r.victories==0,'counter cleanup must not alter existing Smoke resources/rewards')
  else
   for id,value in pairs(before)do assert(r.relicCounters[id]==value,'defeat changed existing counter: '..id)end
  end
  local stable=unchanged(r);assert(not Run.finishCombat(r));stable()
 end
 print('VICTORY_RELIC_COUNTER_OTHER_OUTCOMES_PASS')
end
function M.enemyEscape()
 local r=start('looter_solo');local raw=Run.finishCombat;local settled=false
 Run.finishCombat=function(owner)
  local before=C.copy(owner.combat.relicCounters);local results={raw(owner)}
  if results[1]then
   settled=true;hidden(owner)
   for id,value in pairs(before)do
    local battleOnly=false;for _,battleId in ipairs(battleIds)do if battleId==id then battleOnly=true end end
    if not battleOnly then assert(owner.relicCounters[id]==value,'enemy escape altered permanent counter '..id)end
   end
  end
  return table.unpack(results)
 end
 for _=1,6 do if r.phase~='combat'then break end;assert(Run.endTurn(r))end
 Run.finishCombat=raw
 assert(settled and r.phase=='reward' and r.lastResult.allEnemiesEscaped==true,'real Looter escape reaches endBattle')
 hidden(r);assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 assert(r.phase=='map');hidden(r)
 print('VICTORY_RELIC_COUNTER_ENEMY_ESCAPE_PASS')
end
return M
