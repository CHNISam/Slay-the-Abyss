local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b,label)
 label=label or 'value';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
local M={}
function M.snecko(sample,deck)
 local run=Run.new(D,sample.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
 local old=C.copy(run.deck);for _,c in ipairs(old)do assert(Run.removeCard(run,c.uid))end
 local uids={}
 for _,source in ipairs(deck)do
  local id;for _,d in ipairs(run.data.cards.cards)do if d.sourceId==source or d.sts_name==source then id=d.id;break end end
  assert(id,'missing source card '..source);local ok,uid=Run.obtainCard(run,id);assert(ok,uid);uids[#uids+1]=uid
 end
 assert(Run.obtainRelic(run,'snecko_eye'));assert(Run.obtainPotion(run,'swift_potion'))
 local raw=R.randomInt;local trace={}
 R.randomInt=function(owner,maximum,...)
  local before=R.snapshot(owner);local value=raw(owner,maximum,...)
  trace[#trace+1]={maximum=maximum,value=value,before=before,after=R.snapshot(owner)};return value
 end
 assert(Run.startCombat(run,'cultist_solo'));local s=run.combat
 assert(#s.hand==7 and s.player.statuses.confusion==1)
 local function check(step,start)
  same(R.snapshot(s.cardRandomRng),step.after,step.phase..' full stream')
  for i,e in ipairs(step.cards)do
   local c=s.hand[start+i-1];assert(c.deckUid==uids[e.deckIndex],'source shuffled draw identity')
   local d=s.catalog.cards[c.cardId];assert((d.sourceId or d.sts_name)==e.sourceId)
   assert(C.combatBaseCost(s,c)==e.cost,'combat cost')
   assert(c.costForTurn==e.turnCost,'temporary turn cost')
   assert((c.costOverride~=nil)==e.modified,'only differing roll modifies cost')
   assert((c.freeToPlayOnce==true)==e.free,'free once semantics')
  end
 end
 check(sample.steps[1],1)
 -- Explicit temporary-cost/free-once precondition, no effect or RNG hook is
 -- replaced. The subsequent draw itself is real public potion dispatch.
 for _,c in ipairs(s.draw)do c.costForTurn=0;c.freeToPlayOnce=true end
 assert(Run.usePotion(run,1));assert(#s.hand==10)
 check(sample.steps[2],8);same(trace,sample.trace,'every Confusion draw bound/value/words/counter')
 R.randomInt=raw
 print('SNECKO_INDEPENDENT_PASS '..sample.seed)
end
function M.insect(samples)
 for _,e in ipairs(samples)do
  local d=C.copy(D)
  for _,enemy in ipairs(d.enemies.enemies)do if enemy.id=='cultist'then enemy.hp=e.maximum;enemy.hpRange=nil end end
  for _,encounter in ipairs(d.enemies.encounters)do if encounter.id=='cultist_solo'then
   encounter.tier=e.tier;encounter.eliteTrigger=e.eliteTrigger;encounter.minFloor=1
  end end
  local run=Run.new(d,'42',{experimental=true,character='ironclad'})
  if e.neow then assert(Run.obtainRelic(run,'neows_lament'))end
  assert(Run.obtainRelic(run,'preserved_insect'));assert(Run.startCombat(run,'cultist_solo'))
  local enemy=run.combat.enemies[1]
  assert(enemy.hp==e.hp,'source binary32 HP '..e.maximum..' '..e.tier..': '..enemy.hp..' ~= '..e.hp)
  assert(enemy.maxHp==e.maximum,'Insect must preserve max HP')
 end
 print('INSECT_INDEPENDENT_PASS '..samples[1].maximum)
end
return M
