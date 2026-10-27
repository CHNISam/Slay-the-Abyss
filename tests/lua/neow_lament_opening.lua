local Run,C,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local r=Run.new(Data,'42')
assert(Run.obtainRelic(r,'NeowsBlessing'))
assert(r.relicCounters.neows_lament==3)
local function finish()
 for _=1,180 do
  if r.phase~='combat'then break end
  local target
  for i,e in ipairs(r.combat.enemies)do if e.hp>0 then target=i;break end end
  local uid
  for _,card in ipairs(r.combat.hand)do
   if C.cardDefinition(r.combat,card).type=='attack' and C.canPlay(r.combat,card.uid,target)then uid=card.uid;break end
  end
  if uid then assert(Run.play(r,uid,target))else assert(Run.endTurn(r))end
 end
 assert(r.phase=='reward')
 assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 if r.phase=='reward'then assert(Run.leaveCombatRewards(r))end
 assert(r.phase=='map')
end
for battle=1,4 do
 assert(Run.startCombat(r,'cultist_solo'))
 local enemy=r.combat.enemies[1]
 assert(enemy.maxHp>=48 and enemy.maxHp<=54)
 assert(enemy.hp==(battle<=3 and 1 or enemy.maxHp),'Lament must change current HP only in the first three battles')
 local expected=battle==1 and 2 or battle==2 and 1 or -2
 assert(r.combat.relicCounters.neows_lament==expected)
 for _,event in ipairs(r.combat.events)do
  assert(event.kind~='damage' and event.kind~='hp_loss','HP assignment must not dispatch damage hooks')
 end
 if battle<=3 then finish();assert(r.relicCounters.neows_lament==expected)end
end
print('NEOW_LAMENT_OPENING 4 battles passed')
