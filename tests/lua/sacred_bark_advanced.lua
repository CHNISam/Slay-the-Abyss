package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,A=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_actor')
local D=require('abyss_data');local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)fn();n=n+1;print('PASS Bark advanced '..name)end
local function fresh(id,character)
 local r=Run.new(D,42,character and {character=character,experimental=true}or nil)
 assert(Run.obtainRelic(r,'SacredBark'));assert(Run.obtainPotion(r,id));assert(Run.startCombat(r,'cultist_solo'))
 r.combat.enemies[1].hp,r.combat.enemies[1].maxHp=1000,1000;return r,r.combat
end
test('Swift draws six, Snecko draws ten but randomises once, Chaos queues six original target rolls',function()
 for _,case in ipairs({{'swift_potion',7},{'snecko_oil',10}})do
  local r,b=fresh(case[1]);while #b.hand>1 do b.discard[#b.discard+1]=table.remove(b.hand)end
  assert(Run.usePotion(r,1));eq(#b.hand,case[2]);eq(r.potions[1],nil)
  if case[1]=='snecko_oil'then for _,c in ipairs(b.hand)do local cost=C.cardDefinition(b,c).cost;assert(cost>=0 and cost<=3)end end
 end
 local r,b=fresh('distilled_chaos');b.hand,b.draw,b.discard={},{},{}
 for i=1,6 do b.draw[#b.draw+1]={uid=2000+i,cardId='defend'}end
 local rng=R.cloneState(b.cardRandomRng);for _=1,6 do R.randomInt(rng,0)end
 assert(Run.usePotion(r,1));local played=0;for _,event in ipairs(b.events)do if event.kind=='play'then played=played+1 end end
 eq(played,6);eq(b.player.block,30);eq(b.energy,3);same(R.snapshot(b.cardRandomRng),R.snapshot(rng))
end)
test('Memories returns two real identities; arbitrary-discard and exhaust choices are not repeated',function()
 local r,b=fresh('liquid_memories');b.hand={};b.discard={{uid=2201,cardId='strike'},{uid=2202,cardId='defend'},{uid=2203,cardId='bash'}}
 assert(Run.usePotion(r,1));assert(Run.chooseCard(r,b.pendingChoice.token,2201));assert(Run.chooseCard(r,b.pendingChoice.token,2202))
 eq(b.pendingChoice.required,2);assert(Run.chooseCard(r,b.pendingChoice.token,0))
 eq(#b.hand,2);eq(#b.discard,1);eq(b.hand[1].costForTurn,0);eq(b.hand[2].costForTurn,0);eq(b.pendingChoice,nil)
 for _,id in ipairs({'elixir','gamblers_brew'})do
  local owner,state=fresh(id);local size=#state.hand;assert(Run.usePotion(owner,1))
  assert(Run.chooseCard(owner,state.pendingChoice.token,0));eq(state.pendingChoice,nil);eq(#state.hand,size);eq(owner.potions[1],nil)
 end
end)
test('invalid, overflow and late failure retain all owners; Bark does not double relic post-use healing',function()
 local r,b=fresh('poison_potion');A.applyPower(b,b.enemies[1],'poison',2147483640,b.player)
 local before=C.copy(r,{[r.data]=r.data});local inv,events,deck,combat=r.potions,b.events,r.deck,b
 local ok,why=Run.usePotion(r,1,1);eq(ok,false);eq(why,'effect_overflow');same(r,before)
 eq(r.potions,inv);eq(r.combat,combat);eq(b.events,events);eq(r.deck,deck)
 eq(Run.usePotion(r,1,99),false);same(r,before)
 local fire,state=fresh('fire_potion');local prior=C.copy(fire,{[fire.data]=fire.data});local physical=fire.potions
 eq(Run.usePotion(fire,1,1,function()error('late potion fixture failure')end),false);same(fire,prior);eq(fire.potions,physical)
 local heal=Run.new(D,42);assert(Run.obtainRelic(heal,'SacredBark'));assert(Run.obtainRelic(heal,'Toy Ornithopter'))
 assert(Run.obtainPotion(heal,'energy_potion'));heal.hp=20;assert(Run.startCombat(heal,'cultist_solo'))
 assert(Run.usePotion(heal,1));eq(heal.combat.energy,7);eq(heal.hp,25)
end)
test('all eight injected class potions use true Bark ownership without repeating stance changes',function()
 for _,case in ipairs({{'focus_potion','focus',4},{'potion_of_capacity','slots',7},{'essence_of_darkness','dark',6}})do
  local r,b=fresh(case[1],'defect');assert(Run.usePotion(r,1))
  eq(case[2]=='focus'and b.player.statuses.focus or case[2]=='slots'and b.orbs.slots or b.orbChannelCounts.dark,case[3])
 end
 for _,case in ipairs({{'cunning_potion','shivs',6},{'ghost_in_a_jar','intangible',2}})do
  local r,b=fresh(case[1],'silent');local uid=b.nextUid;assert(Run.usePotion(r,1))
  eq(case[2]=='shivs'and b.nextUid-uid or b.player.statuses.intangible,case[3])
 end
 local miracle,ms=fresh('bottled_miracle','watcher');local uid=ms.nextUid;assert(Run.usePotion(miracle,1));eq(ms.nextUid-uid,4)
 local god,gs=fresh('ambrosia','watcher');local energy=gs.energy;assert(Run.usePotion(god,1));eq(gs.energy,energy+3);eq(gs.player.stance,'Divinity')
 local stance,ss=fresh('stance_potion','watcher');assert(Run.usePotion(stance,1));local pending=ss.pendingPotionChoice;eq(pending.count,1)
 assert(Run.choosePotionStance(stance,{'Calm'},pending.token,stance.combatGeneration,ss));eq(ss.player.stance,'Calm');eq(ss.pendingPotionChoice,nil)
end)
print('SACRED_BARK_ADVANCED_PASS '..n)
