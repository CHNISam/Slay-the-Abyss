return function(first,last)
 local Run,D,N,Map,C=require('abyss_run'),require('abyss_data'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
 local count=0
 for seed=first,last do
  local r=Run.new(D,seed)
  -- A fixed event destination isolates reward RNG; no relic queue or RNG edits.
  local m=Map.generate(D,seed);local id=Map.available(m)[1].id
  for _,n in ipairs(m.nodes)do if n.id==id then n.type='event';n.eventId='big_fish' end end
  assert(N.enter(r,m,id))
  local expected,pool=Run.prepareRelic(r,{channel='event',screenless=true,room='event'})
  assert(expected,'seed '..seed..' cannot prepare original event relic: '..tostring(pool))
  local before=#r.deck;local ok,why=N.chooseEvent(r,'box')
  assert(ok,'seed '..seed..' box failed: '..tostring(why))
  local e=r.nodeFlow.event
  assert(e.relicOffer.sourceId==expected.sourceId,'changed selected source identity')
  assert(e.obtainedRelicId==expected.id,'selected relic was not granted')
  assert(#r.deck==before+1 and r.deck[#r.deck].cardId=='regret','box curse was not granted')
  assert(#r.relicPool.queues[expected.tier]==#pool.queues[expected.tier],'wrong queue consumption')
  assert(not N.chooseEvent(r,'box'),'duplicate box consumed twice')
  assert(N.chooseEvent(r,'leave'));assert(r.phase=='map','box cannot return to map')
  count=count+1
 end
 print('NATURAL_EVENT_RELICS_PASS '..first..' '..last..' '..count)
end
