-- Real Run inventory/choice APIs with controlled inventory; no natural claim.
local F=dofile('tests/lua/support/shared_special_event_fixture.lua')
local Run,C,R=F.Run,F.C,F.R
local Data,H=require('abyss_data'),require('abyss_relic_hooks')
local Pool,CR,T=require('abyss_card_pool'),require('abyss_card_random'),require('abyss_treasure')
local function run()return Run.new(Data,'42',{experimental=true,campaign=true,character='ironclad'})end
local eq,same=F.eq,F.same
local function refuse(r,fn,reason)
 local before=F.snapshot(r);local deck,relics,counters=r.deck,r.relics,r.relicCounters
 local ok,why=fn();eq(ok,false);if reason then eq(why,reason)end;same(r,before)
 eq(r.deck,deck);eq(r.relics,relics);eq(r.relicCounters,counters)
end
F.test('all six source SPECIAL relics obtain through real API without pool or RNG draws',function()
 local r=run();local before=F.snapshot(r)
 for _,id in ipairs({'CultistMask','FaceOfCleric','GremlinMask','NlothsMask','SsserpentHead',"Nloth's Gift"})do assert(Run.obtainRelic(r,id))end
 eq(#r.relics,7);eq(r.relicCounters.nloths_mask,1)
 for _,name in ipairs({'eventRng','miscRng','cardRng','treasureRng','relicPool'})do same(r[name],before[name])end
 refuse(r,function()return Run.obtainRelic(r,'NlothsMask')end,'relic_already_owned')
end)
F.test('Gremlin gives one weak and Cultist only emits its cosmetic cue in real opening order',function()
 local r=run();assert(Run.obtainRelic(r,'CultistMask'));assert(Run.obtainRelic(r,'GremlinMask'))
 assert(Run.startCombat(r,'cultist_solo'));eq(r.combat.player.statuses.weak,1)
 eq(r.combat.player.statuses.strength,nil);local cue=0
 for _,event in ipairs(r.combat.events)do if event.kind=='relic_flavor'and event.detail.relic=='cultist_mask'then cue=cue+1 end end
 eq(cue,1);eq(r.combat.turn,1);eq(r.combat.energy,3)
end)
local function victor(relics)
 local r=run();r.deck={};r.hp=30;r.relics={}
 for _,id in ipairs(relics)do assert(Run.obtainRelic(r,id))end
 for _=1,5 do assert(Run.obtainCard(r,'bludgeon',{upgraded=true}))end
 assert(Run.obtainPotion(r,'fire_potion'));assert(Run.startCombat(r,'cultist_solo'))
 assert(Run.usePotion(r,1,1));return r
end
F.test('Face Cleric real fatal card command increases max HP once before rewards and respects Bloom',function()
 for _,relics in ipairs({{'FaceOfCleric'},{'FaceOfCleric','mark_of_bloom'}})do
  local r=victor(relics);local uid=r.combat.hand[1].uid;assert(Run.play(r,uid,1))
  eq(r.phase,'reward');eq(r.maxHp,81);eq(r.hp,#relics==2 and 30 or 31)
  refuse(r,function()return Run.finishCombat(r)end,'not_in_combat');eq(r.maxHp,81)
 end
end)
F.test('Face Cleric late victory failure rolls complete real card command back and retries once',function()
 local r=victor({'FaceOfCleric'});local uid=r.combat.hand[1].uid;local increase=Run.increaseMaxHp
 local before=F.snapshot(r);local battle,deck,relics=r.combat,r.deck,r.relics
 Run.increaseMaxHp=function(staged,n)increase(staged,n);error('late Face victory failure')end
 local called,why=pcall(Run.play,r,uid,1);Run.increaseMaxHp=increase
 eq(called,false);assert(tostring(why):find('late Face victory failure',1,true));same(r,before)
 eq(r.combat,battle);eq(r.deck,deck);eq(r.relics,relics)
 assert(Run.play(r,uid,1));eq(r.maxHp,81);eq(r.hp,31)
end)
F.test('Serpent awards50 before unknown roll and event eligibility, including converted combat',function()
 local Nodes,Map=require('abyss_nodes'),require('abyss_map')
 local r=run();r.act,r.floor,r.gold=2,17,200;assert(Run.obtainRelic(r,'SsserpentHead'))
 local m=Map.generate(r.data,'42',2);local n=Map.available(m)[1]
 for _,actual in ipairs(m.nodes)do if actual.id==n.id then actual.type,actual.eventId='event','face_trader'end end
 assert(Nodes.enter(r,m,n.id));eq(r.gold,250);eq(r.nodeFlow.event.stage,'intro')
 assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'touch'));eq(r.gold,325)
 r=run();r.relics={'ssserpent_head','ectoplasm'};local before=r.gold
 H.onEnterRoom(r,'event','enter');H.onEnterRoom(r,'event','entered');eq(r.gold,before)
 r.relics={'ssserpent_head'};H.onEnterRoom(r,'camp','entered');eq(r.gold,before)
 r.gold=25;H.onEnterRoom(r,'event','enter');eq(r.gold,75)
 assert(require('abyss_event_pool').isEligible('Designer',{act=2,gold=r.gold}))
 H.onEnterRoom(r,'event','entered');eq(r.gold,75)
 -- A controlled valid source-PC chance state fixes a combat outcome without
 -- replacing the source selector, shrinking any pool, or advancing a test RNG.
 r=run();r.act,r.floor,r.gold=2,17,200;assert(Run.obtainRelic(r,'SsserpentHead'))
 r.encounters=require('abyss_encounter_queue').new(r.runSeed,2)
 r.unknown.pools=require('abyss_event_pool').new('full',false,2);r.unknown.chances.monster=R.float32(1)
 local expected=R.cloneState(r.eventRng);local roll=R.randomFloat(expected);assert(math.floor(R.float32(roll*100))<99)
 local pools=C.copy(r.unknown.pools);m=Map.generate(r.data,'42',2);n=Map.available(m)[1]
 for _,actual in ipairs(m.nodes)do if actual.id==n.id then actual.type,actual.eventId='event',nil end end
 assert(Nodes.enter(r,m,n.id));eq(r.nodeFlow.type,'combat');eq(r.nodeFlow.sourceType,'event');eq(r.gold,250);eq(r.combat.player.gold,250)
 same(r.unknown.pools,pools);same(R.snapshot(r.eventRng),R.snapshot(expected))
end)
F.test('Nloth Mask real obtain counter removes one normal chest relic, never boss, then stays spent',function()
 local r=run();r.floor=9;assert(Run.obtainRelic(r,'NlothsMask'))
 local boss=assert(T.prepare(r,{boss=true}));eq(boss.relicCounters.nloths_mask,1)
 local prepared=assert(T.prepare(r));eq(prepared.relicCounters.nloths_mask,-2)
 local removed=0;for _,entry in ipairs(prepared.hookTrace)do if entry.sourceId=='NlothsMask'then removed=removed+1 end end;eq(removed,1)
 r.relicCounters=prepared.relicCounters;r.relicPool=prepared.relicPool;r.treasureRng=prepared.treasureRng
 prepared=assert(T.prepare(r));local relics=0;for _,item in ipairs(prepared.reward.items)do if item.kind=='relic'then relics=relics+1 end end
 eq(relics,1);eq(prepared.relicCounters.nloths_mask,-2)
end)
F.test('Gift multiplies rare weight in normal elite shop without changing common pity or RNG calls',function()
 local thresholds={normal={9,46},elite={30,70},shop={27,64}}
 for context,bounds in pairs(thresholds)do
  for roll=0,99 do for _,offset in ipairs({-40,0,5})do
   local value=roll+offset;local expected=value<bounds[1]and'rare'or value<bounds[2]and'uncommon'or'common'
   eq(Pool.rarity(roll,offset,context,{"Nloth's Gift"}),expected)
  end end
  local owner=CR.new('42');owner.relics={'nloths_gift'};local expected=R.cloneState(owner.cardRng)
  local roll=R.randomInt(expected,99)+5
  eq(CR.rollRarity(owner,context),roll<bounds[1]and'rare'or roll<bounds[2]and'uncommon'or'common')
  same(R.snapshot(owner.cardRng),R.snapshot(expected));eq(owner.cardRarityOffset,5)
 end
 eq(Pool.rarity(99,5,'boss',{'nloths_gift'}),'rare')
 local r=run();assert(Run.obtainRelic(r,"Nloth's Gift"));local expected=R.cloneState(r.cardRng)
 local adjusted=R.randomInt(expected,99)+r.cardRarityOffset
 local rarity=adjusted<27 and'rare'or adjusted<64 and'uncommon'or'common'
 local stock=require('abyss_shop').prepare(r,18);eq(stock.cards[1].rarity,rarity)
 -- prepare owns a private card stream and must not publish it on inspection.
 eq(r.cardRng.counter,0)
end)
F.test('real loseRelic keeps one-shot potion slots gold and maxHP instead of undoing equip',function()
 local r=run();assert(Run.obtainRelic(r,'Potion Belt'));local capacity=Run.potionCapacity(r)
 for i=1,capacity do r.potions[i]='block_potion'end
 assert(Run.loseRelic(r,'Potion Belt'));eq(Run.potionCapacity(r),capacity);eq(Run.potionCount(r),capacity)
 assert(Run.obtainRelic(r,'Old Coin'));local gold=r.gold;assert(Run.loseRelic(r,'old_coin'));eq(r.gold,gold)
 assert(Run.obtainRelic(r,'Mango'));local maximum,hp=r.maxHp,r.hp;assert(Run.loseRelic(r,'Mango'));eq(r.maxHp,maximum);eq(r.hp,hp)
 assert(Run.obtainRelic(r,"Nloth's Gift"));assert(Run.loseRelic(r,'NlothsGift'));assert(not H.owns(r,'nloths_gift'))
 refuse(r,function()return Run.loseRelic(r,'old_coin')end,'relic_not_owned')
end)
F.test('loseRelic removes object counter and reacquisition starts fresh without touching retained battle',function()
 local r=run();assert(Run.obtainRelic(r,'Lizard Tail'));r.relicCounters.lizard_tail=-2
 r.phase='node';r.combat={marker='historical',relics={'lizard_tail'},relicCounters={lizard_tail=-2}}
 local battle=C.copy(r.combat);assert(Run.loseRelic(r,'Lizard Tail'));eq(r.relicCounters.lizard_tail,nil);same(r.combat,battle)
 assert(Run.obtainRelic(r,'Lizard Tail'));eq(r.relicCounters.lizard_tail,-1)
 assert(Run.obtainRelic(r,'NlothsMask'));r.relicCounters.nloths_mask=-2;assert(Run.loseRelic(r,'NlothsMask'))
 assert(Run.obtainRelic(r,'NlothsMask'));eq(r.relicCounters.nloths_mask,1)
 assert(Run.obtainRelic(r,'Tiny Chest'));r.unknown.chances.tinyChestCount=3
 assert(Run.loseRelic(r,'Tiny Chest'));eq(r.unknown.chances.tinyChestCount,0)
 assert(Run.obtainRelic(r,'Tiny Chest'));eq(r.unknown.chances.tinyChestCount,0)
end)
F.test('onUnequip runs while owned and late hook refusal rolls owners back before retry',function()
 local r=run();assert(Run.obtainRelic(r,'NlothsMask'));local hook=H.onUnequip;local seen=false
 H.onUnequip=function(staged,id)seen=true;eq(id,'nloths_mask');assert(H.owns(staged,id));staged.relicCounters.nloths_mask=-2;return false,'late_unequip_refusal'end
 local ok,why=pcall(refuse,r,function()return Run.loseRelic(r,'NlothsMask')end,'late_unequip_refusal');H.onUnequip=hook;assert(ok,why);assert(seen)
 assert(Run.loseRelic(r,'NlothsMask'));eq(r.relicCounters.nloths_mask,nil)
end)
F.test('bottle unequip clears only matching physical flag and refuses ambiguous identity',function()
 local r=run();r.deck[1].inBottleFlame=true;r.deck[2].inBottleLightning=true;r.deck[3].inBottleTornado=true
 assert(H.onUnequip(r,'bottled_flame'));eq(r.deck[1].inBottleFlame,false);eq(r.deck[2].inBottleLightning,true);eq(r.deck[3].inBottleTornado,true)
 assert(H.onUnequip(r,'bottled_lightning'));eq(r.deck[2].inBottleLightning,false)
 r.deck[1].inBottleTornado=true;local before=F.snapshot(r)
 local ok,why=H.onUnequip(r,'bottled_tornado');eq(ok,false);eq(why,'bottled_card_identity_unavailable');same(r,before)
end)
F.test('active source energy relic removal changes next-turn master but does not revoke spent opening effects',function()
 local r=run();assert(Run.obtainRelic(r,'Sozu'));assert(Run.startCombat(r,'cultist_solo'))
 eq(r.combat.rules.player.energyPerTurn,4);local current=r.combat.energy
 local hook=H.onUnequip;local observed=false
 H.onUnequip=function(staged,id)
  local ok,why=hook(staged,id);observed=true;assert(H.owns(staged,id));assert(H.owns(staged.combat,id))
  eq(staged.combat.rules.player.energyPerTurn,3);return ok,why
 end
 local ok,why=Run.loseRelic(r,'Sozu');H.onUnequip=hook;assert(ok,why);assert(observed)
 eq(r.combat.rules.player.energyPerTurn,3);eq(r.combat.energy,current);assert(not H.owns(r.combat,'sozu'))
 r=run();assert(Run.obtainRelic(r,'SlaversCollar'));assert(Run.startCombat(r,'cultist_solo'))
 refuse(r,function()return Run.loseRelic(r,'SlaversCollar')end,'active_relic_unequip_content_unavailable')
 r=run();assert(Run.obtainRelic(r,'SlaversCollar'));assert(Run.loseRelic(r,'SlaversCollar'))
end)
print('SPECIAL_EVENT_RELICS '..F.count..' passed')
