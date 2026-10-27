-- Cross-slice component fixture, not a natural Act3 route. Real power-card
-- plays feed the same incoming-damage hooks as the source Exploder queue.
local C=require('abyss_combat')
local Cards=require('abyss_card_actions')
local R=require('abyss_sts_random')
local data=require('abyss_character_profiles').prepare(require('abyss_data'),'defect')
local function play(state,id)
 local card=Cards.fresh(C,state,id)
 state.hand[#state.hand+1]=card
 state.energy=10
 assert(C.play(state,card.uid))
end
for _,case in ipairs({{buffer=true,block=0,lost=0,remaining=nil},
 {buffer=true,block=40,lost=0,remaining=1},
 {buffer=false,block=0,lost=30,remaining=nil}})do
 local streams={seed='1'}
 for _,id in ipairs({'aiRng','monsterHpRng','cardRandomRng','shuffleRng'})do streams[id]=R.fromSeed('1')end
 local state=C.new(data,{deck={},enemies={'exploder'},roomSeed='1',roomStreams=streams,orbSlots=3})
 assert(C.endTurn(state));assert(C.endTurn(state))
 play(state,'static_discharge')
 if case.buffer then play(state,'buffer')end
 local hp=state.player.hp
 state.player.block=case.block
 local first=#state.events+1
 assert(C.endTurn(state))
 assert(state.enemies[1].hp==0 and C.outcome(state)=='victory')
 assert(state.player.hp==hp-case.lost)
 assert(state.player.statuses.buffer==case.remaining)
 assert(#state.orbs==0,'THORNS explosion must not trigger NORMAL-only Static Discharge')
 local hits=0
 for i=first,#state.events do
  local event=state.events[i]
  if event.kind=='status_damage'and event.detail.status=='thorns'then
   hits=hits+1;assert(event.detail.amount==case.lost)
  end
 end
 assert(hits==1,'final suicide retains exactly one explosion')
end
print('ACT3_SHAPES_DEFECT_INTEGRATION_PASS Buffer and Static Discharge through final Exploder damage')
