-- Controlled event/next-room source inputs, but real acquisition, navigation,
-- source encounter queue and combat execution. Not natural four-act acceptance.
local H=dofile('tests/helpers/library_event.lua')
local Queue=require('abyss_encounter_queue')
local specs={{'ironclad','cleave',8},{'silent','dagger_spray',4,2},{'defect','cold_snap',6},{'watcher','consecrate',5}}
for _,spec in ipairs(specs)do
 local r,m=H.fixture(spec[1]);r.deck={};r.nextDeckUid=30;r.relics={}
 local selected
 for _,card in ipairs(H.read(r))do if card.cardId==spec[2]then selected=card end end
 assert(selected,'seeded real source offer '..spec[2]);assert(H.Nodes.chooseEvent(r,'select',selected.offerToken))
 local permanent=r.deck[1];assert(permanent.cardId==spec[2] and permanent.uid==30)
 assert(H.Nodes.chooseEvent(r,'leave'));assert(r.phase=='map')
 -- The fixture enters act2 directly, so install its real source queue rather
 -- than claiming to have naturally earned an act transition in this test.
 r.encounters=Queue.new(r.runSeed,2)
 local node=H.Map.available(m)[1];assert(node)
 for _,candidate in ipairs(m.nodes)do if candidate.id==node.id then candidate.type='combat'end end
 assert(H.Nodes.enter(r,m,node.id));assert(r.phase=='combat' and r.encounterSource)
 local state=r.combat;local card=state.hand[1]
 assert(card.cardId==spec[2] and card.deckUid==permanent.uid and not card.upgraded)
 local hp,block,flight={},{},{}
 for i,enemy in ipairs(state.enemies)do hp[i],block[i],flight[i]=enemy.hp,enemy.block,(enemy.statuses.flight or 0)>0 end
 local ok,why=H.Run.play(r,card.uid,1);assert(ok,why)
 for i,enemy in ipairs(state.enemies)do
  local targets=spec[1]~='defect' or i==1
  local damage=targets and math.floor(spec[3]*(flight[i] and .5 or 1))*(spec[4] or 1) or 0
  assert(enemy.hp==hp[i]-math.max(0,damage-block[i]),spec[1]..' source HP damage')
  assert(enemy.block==math.max(0,block[i]-damage),spec[1]..' source block damage')
 end
 if spec[1]=='defect'then assert(#state.orbs.balls==1 and state.orbs.balls[1].kind=='frost')end
end
print('LIBRARY_COMBAT 4 mapped-class actual acquisitions / next real source room / real plays passed')
