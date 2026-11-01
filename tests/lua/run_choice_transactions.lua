-- Controlled public continuations, not natural play/platform acceptance.
-- Real constructor/card/selection/retained Beat/finishCombat paths; only health,
-- physical piles and the explicit post-finish false/throw fault are controlled.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Cards,Hooks=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_relic_hooks')
local D=require('abyss_data')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
-- Every original edge is checked, including aliases, UID owners, nested RNG
-- words, physical potion slot->ID tables and objects replaced during commit.
local function unchanged(root)
 local saved={}
 local function visit(value)
  if type(value)~='table'or saved[value]then return end
  local fields={};saved[value]=fields
  for key,entry in pairs(value)do fields[key]=entry;visit(key);visit(entry)end
 end
 visit(root)
 return function()
  for object,fields in pairs(saved)do
   for key,value in pairs(fields)do eq(object[key],value,'original edge '..tostring(key))end
   for key in pairs(object)do assert(fields[key]~=nil,'new field survived rollback '..tostring(key))end
  end
 end
end
local function fresh(kind,fairy)
 local run=Run.new(D,42,{experimental=true,character='watcher'})
 if kind=='pile'then assert(Run.obtainRelic(run,'lizard_tail'))end
 assert(Run.obtainPotion(run,fairy and 'fairy_in_a_bottle'or 'block_potion'));assert(Run.obtainPotion(run,'fire_potion'))
 assert(Run.startCombat(run,'cultist_solo'))
 run.maxHp,run.hp=fairy and 3 or 7,1
 local s=C.new(run.data,{seed=42,enemies={'corrupt_heart'},deck={},hp=1,maxHp=run.maxHp,enableStances=true,
  beforeOpeningDraw=function(state)Hooks.bindBattle(state,run.relics,run.relicCounters);return true end})
 run.combat=s;s.combatGeneration=run.combatGeneration
 s.potionInventory=C.copy(run.potions);s.potionCapacity=Run.potionCapacity(run)
 local id=({pile='omniscience',discard='acrobatics',scry='cut_through_fate',hand='burning_pact'})[kind]
 local played,selected=Cards.fresh(C,s,id),Cards.fresh(C,s,kind=='pile'and 'empty_fist'or 'defend')
 s.hand={played};s.draw={selected};s.discard={};s.energy=20
 if kind=='pile'then s.enemies[1].hp=1 end
 if kind=='hand'then s.hand[#s.hand+1]=selected;s.hand[#s.hand+1]=Cards.fresh(C,s,'strike');s.draw={}end
 if kind=='discard'then
  s.hand[#s.hand+1]=Cards.fresh(C,s,'strike');s.draw[#s.draw+1]=Cards.fresh(C,s,'defend')
 end
 assert(Run.play(run,played.uid,kind=='scry'and 1 or nil))
 local field=({pile='pendingPileChoice',discard='pendingDiscard',scry='pendingScry',hand='pendingHandChoice'})[kind]
 local pending=assert(s[field],'genuine '..kind..' choice must pause')
 if kind=='discard'then selected=s.hand[1]end
 local choose=Run[({pile='choosePile',discard='chooseDiscard',scry='chooseScry',hand='chooseHand'})[kind]]
 run.choiceTransactionAliases={battle=s,player=s.player,pending=pending,selected=selected,played=played,
  counters=s.relicCounters,inventory=s.potionInventory,draw=s.draw,hand=s.hand,events=s.events}
 return run,s,field,pending,choose,{selected.uid}
end
local slice=... or 'pile'
local fairy=slice=='pile_fairy'
local kind=fairy and 'pile'or slice
assert(kind=='pile'or kind=='discard'or kind=='scry'or kind=='hand','invalid continuation slice')
for _,mode in ipairs({'false','throw'})do
 test('public '..slice..' continuation '..mode..' restores complete graph and retries once',function()
  local run,s,field,pending,choose,uids=fresh(kind,fairy)
  local verify=unchanged(run)
  local accepted=choose(run,uids,pending.token,run.combatGeneration+1)
  eq(accepted,false);verify()
  accepted=choose(run,uids,pending.token+1,run.combatGeneration)
  eq(accepted,false);verify()
  local original=Run.finishCombat
  local thrown={marker='EXACT_LATE_CHOICE_ERROR',kind=kind}
  local calls=0
  Run.finishCombat=function(owner)
   calls=calls+1;eq(owner,run);eq(C.outcome(s),kind=='pile'and 'victory'or 'defeat','actual terminal continuation')
   if kind=='pile'then eq(s.relicCounters.lizard_tail,-2);eq(run.relicCounters.lizard_tail,-2)end
   if fairy then eq(s.potionInventory[1],nil,'physical Fairy consumed');eq(run.potions[1],nil,'Fairy removal published')end
   local ok,why=original(owner);assert(ok,why)
   eq(run.phase,kind=='pile'and 'reward'or 'defeat','production finish must actually complete')
   if mode=='throw'then error(thrown,0)end
   return false,'late_choice_finish_refused'
  end
  local called,ok,why=pcall(choose,run,uids,pending.token,run.combatGeneration)
  Run.finishCombat=original
  eq(calls,1,'late failure injection reached')
  if mode=='throw'then eq(called,false);eq(ok,thrown,'exact thrown value')
  else eq(called,true);eq(ok,false);eq(why,'late_choice_finish_refused')end
  verify();eq(run.combat,s);eq(s[field],pending);eq(run.phase,'combat')
  eq(run.potions[1],fairy and 'fairy_in_a_bottle'or 'block_potion');eq(run.potions[2],'fire_potion')
  if kind=='pile'then eq(run.relicCounters.lizard_tail,-1);eq(s.relicCounters.lizard_tail,-1)end
  assert(choose(run,uids,pending.token,run.combatGeneration))
  eq(run.phase,kind=='pile'and 'reward'or 'defeat');eq(s[field],nil)
  if fairy then eq(s.potionInventory[1],nil);eq(run.potions[1],nil);eq(run.potions[2],'fire_potion')end
  if kind=='pile'then eq(run.victories,1);eq(run.relicCounters.lizard_tail,-2);eq(s.relicCounters.lizard_tail,-2)end
  local committed=unchanged(run)
  eq(choose(run,uids,pending.token,run.combatGeneration),false);committed()
 end)
end
if slice=='pile'then
 -- Retained full-source Watcher rooms in Act1/2, not competition admission.
 -- Watcher's Omniscience is outside the two-role competition roster. Deck acquisition,
 -- constructor, Omniscience selection and reward preparation are real; chapter
 -- placement, physical pile arrangement and near-lethal damage are controlled.
 -- These are component rollback cases, not natural runs or platform evidence.
 local Q,Pool,R=require('abyss_encounter_queue'),require('abyss_card_pool'),require('abyss_sts_random')
 for _,act in ipairs({1,2})do
  test('controlled full-source Watcher Act'..act..' reward preparation restores pile choice and retries once',function()
   local run=Run.new(D,'0',{experimental=true,character='watcher',campaign=true,campaignProfile='full-source'})
   local remove={};for _,card in ipairs(run.deck)do remove[#remove+1]=card.uid end
   for _,uid in ipairs(remove)do assert(Run.removeCard(run,uid))end
   assert(Run.obtainCard(run,'omniscience'));assert(Run.obtainCard(run,'empty_fist'))
   assert(Run.obtainPotion(run,'energy_potion'))
   run.act,run.floor,run.encounters=act,act==1 and 1 or 18,Q.new(run.runSeed,act)
   assert(Run.startRoomCombat(run,'normal'));assert(Run.usePotion(run,1))
   local s=run.combat;assert(s.roomSeed,'actual source room required')
   local played,selected
   for i=#s.hand,1,-1 do
    local card=s.hand[i]
    if card.cardId=='omniscience'then played=card
    elseif card.cardId=='empty_fist'then selected=table.remove(s.hand,i);s.draw[#s.draw+1]=selected end
   end
   assert(played and selected,'acquired physical cards must be drawn')
   for i,enemy in ipairs(s.enemies)do
    C.damage(s,s.player,enemy,enemy.hp+enemy.block-(i==#s.enemies and 1 or 0),true)
   end
   assert(Run.play(run,played.uid));local pending=assert(s.pendingPileChoice)
   local verify=unchanged(run)
   local original=Pool.prepareRewards;local reached=0
   local thrown={marker='EXACT_ACT_SOURCE_REWARD_ERROR',act=act}
   Pool.prepareRewards=function(owner)
    local cards,rng,offset,upgrades=original(owner)
    eq(owner.act,act);eq(owner.combat,s);eq(C.outcome(s),'victory')
    eq(#cards,3);assert(R.snapshot(rng).counter>R.snapshot(owner.cardRng).counter)
    assert(type(offset)=='number'and #upgrades==#cards)
    reached=reached+1;error(thrown,0)
   end
   local called,why=pcall(Run.choosePile,run,{selected.uid},pending.token,run.combatGeneration)
   Pool.prepareRewards=original
   eq(reached,1,'real reward preparation reached');eq(called,false);eq(why,thrown,'exact thrown value')
   verify();eq(run.combat,s);eq(s.pendingPileChoice,pending);eq(run.phase,'combat')
   assert(Run.choosePile(run,{selected.uid},pending.token,run.combatGeneration))
   eq(run.phase,'reward');eq(run.victories,1);eq(s.pendingPileChoice,nil);eq(#run.rewards.cards,3)
   eq(run.act,act);eq(run.campaignProfile,'full-source')
   local committed=unchanged(run)
   eq(Run.choosePile(run,{selected.uid},pending.token,run.combatGeneration),false);committed()
  end)
 end
end
print('RUN_CHOICE_TRANSACTIONS '..slice..' '..count..' groups; '..failed..' failed')
assert(failed==0)
