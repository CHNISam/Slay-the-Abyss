package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run')
local Combat=require('abyss_combat')
local Data=require('abyss_data')
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok character run '..n..' - '..name) end
local function fresh(id)
 return Run.new(Data,'42',{character=id,experimental=true})
end
local specs={silent={hp=70,cards=12,hand=7,relic='ring_of_the_snake'},
 defect={hp=75,cards=10,hand=5,relic='cracked_core'},
 watcher={hp=72,cards=10,hand=6,relic='pure_water'}}
test('default run remains Ironclad and non-defaults require opt-in',function()
 local r=Run.new(Data,'42');eq(r.character,nil);eq(r.maxHp,80);eq(#r.deck,10)
 eq(pcall(Run.new,Data,'42',{character='silent'}),false)
 eq(pcall(Run.new,Data,'42',{character='unknown',experimental=true}),false)
end)
for _,id in ipairs({'silent','defect','watcher'}) do
 test(id..' starts a real source room with its own starter deck and relic',function()
  local r=fresh(id);local spec=specs[id]
  eq(r.character,id);eq(r.hp,spec.hp);eq(r.maxHp,spec.hp);eq(r.gold,99)
  eq(#r.deck,spec.cards);eq(#r.relics,1);eq(r.relics[1],spec.relic)
  for _,c in ipairs(r.deck) do assert(c.cardId~='strike' and c.cardId~='defend' and c.cardId~='bash') end
  assert(Run.startRoomCombat(r,'normal'));eq(r.phase,'combat');eq(r.combatGeneration,1)
  local s=r.combat;eq(s.player.maxHp,spec.hp);eq(#s.hand,spec.hand);eq(s.energy,3)
  if id=='defect' then
   eq(s.orbs.slots,3);eq(#s.orbs.balls,1);eq(s.orbs.balls[1].kind,'lightning')
   eq(s.cardRandomRng.counter,0)
  elseif id=='watcher' then
   eq(s.player.stance,'Neutral');local miracles=0
   for _,c in ipairs(s.hand) do if c.cardId=='miracle' then miracles=miracles+1 end end
   eq(miracles,1)
   for _,c in ipairs(r.deck) do assert(c.cardId~='miracle') end
  end
 end)
 test(id..' next turn does not repeat starting relic',function()
  local r=fresh(id);assert(Run.startRoomCombat(r,'normal'));assert(Run.endTurn(r))
  eq(r.phase,'combat');eq(r.combat.turn,2);eq(r.combat.energy,3)
  eq(#r.combat.hand,id=='watcher' and 6 or 5)
  if id=='defect' then eq(#r.combat.orbs.balls,1) end
 end)
end
test('Miracle is a temporary self-retained card with a real energy play',function()
 local r=fresh('watcher');assert(Run.startRoomCombat(r,'normal'))
 local s=r.combat;local uid
 for _,c in ipairs(s.hand) do if c.cardId=='miracle' then uid=c.uid end end
 assert(uid);assert(Run.play(r,uid));eq(s.energy,4);eq(#s.exhaust,1)
 eq(#r.deck,10);eq(s.exhaust[1].cardId,'miracle')
end)
test('battle generation protects choice commands before token matching',function()
 local r=fresh('silent');assert(Run.startRoomCombat(r,'normal'))
 local ok,reason=Run.chooseDiscard(r,{},1,0)
 eq(ok,false);eq(reason,'stale_combat_generation')
end)
-- A real first-room smoke: no HP, energy, card or enemy stat overrides.
for _, id in ipairs({'silent','defect','watcher'}) do
 test(id..' wins its first source room using only the unchanged starter',function()
  local r=fresh(id);assert(Run.startRoomCombat(r,'normal'))
  local turns=0
  while r.phase=='combat' and turns<30 do
   local plays=0
   while r.phase=='combat' and plays<50 do
    local s=r.combat
    if s.pendingDiscard then
     local picked={}
     for _,c in ipairs(s.hand) do
      if #picked<s.pendingDiscard.count then picked[#picked+1]=c.uid end
     end
     assert(Run.chooseDiscard(r,picked,s.pendingDiscard.token,r.combatGeneration))
    else
     local target
     for i,e in ipairs(s.enemies) do if e.hp>0 and not e.escaped then target=i;break end end
     local selected,best
     for _,c in ipairs(s.hand) do
      local card=Combat.cardDefinition(s,c)
      local ok=Combat.canPlay(s,c.uid,target)
      if ok then
       local score=card.cost==0 and 100 or card.id=='eruption' and 90 or card.type=='attack' and 80 or 10
       if not best or score>best then selected,best=c,score end
      end
     end
     if not selected then break end
     assert(Run.play(r,selected.uid,target))
    end
    plays=plays+1
   end
   assert(plays<50,'unexpected unbounded play loop')
   if r.phase=='combat' then assert(Run.endTurn(r)) end
   turns=turns+1
  end
  eq(r.phase,'reward');assert(r.lastResult and r.lastResult.outcome=='victory')
  assert(r.hp>0);eq(#r.deck,specs[id].cards)
  eq(r.relics[1],specs[id].relic)
  print('FIRST_ROOM_STARTER_VICTORY '..id..' '..turns..' turns hp='..r.hp)
  local hp=r.hp
  assert(Run.claimCardReward(r,0));assert(Run.leaveCombatRewards(r))
  r.floor=2 -- explicit room-entry harness; map navigation is a separate suite
  assert(Run.startRoomCombat(r,'normal'));eq(r.combatGeneration,2)
  eq(r.combat.player.hp,hp);eq(#r.combat.hand,specs[id].hand)
  if id=='defect' then eq(#r.combat.orbs.balls,1)
  elseif id=='watcher' then eq(r.combat.player.stance,'Neutral') end
  local accepted,reason=Run.chooseDiscard(r,{},1,1)
  eq(accepted,false);eq(reason,'stale_combat_generation')
 end)
end
print('CHARACTER_RUN_PASS '..n)
