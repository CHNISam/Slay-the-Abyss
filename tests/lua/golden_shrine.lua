package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,Pool,R=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_event_pool'),require('abyss_sts_random')
local Data=require('abyss_data')
local count,failed=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b) if type(a)~='table' then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end end
local function test(name,fn) count=count+1;local ok,e=pcall(fn);if not ok then failed=failed+1 end;print((ok and 'ok ' or 'not ok ')..count..' - '..name..(ok and '' or ': '..tostring(e)))end
local function enter(seed)
 local run,map=Run.new(Data,seed or 42),Map.generate(Data,seed or 42)
 map.nodes[1].type='event';map.nodes[1].eventId='golden_shrine'
 assert(Nodes.enter(run,map,map.nodes[1].id));return run,map
end
local function battle(deck,hp)
 local data=C.copy(Data)
 -- A quiet enemy isolates card-trigger HP loss without mocking the action engine.
 local enemy=data.enemies.enemies[1];enemy.ai=nil;enemy.intents={{id='wait',kind='stunned',effects={}}}
 return C.new(data,{enemies={enemy.id},deck=deck,hp=hp or 80,seed=42})
end
test('production pool is seven complete events with Golden Shrine only in shrine category',function()
 eq(Data.rules.events.poolMode,'restricted-seven');local p=Pool.new(Data.rules.events.poolMode)
 eq(#p.act,4);eq(#p.shrine,3);eq(#p.once,0);eq(p.shrine[1],'Golden Shrine')
 eq(Pool.contentId['Golden Shrine'],'golden_shrine');local historical=Pool.new('restricted-six');eq(#historical.shrine,2)
 local full=Pool.new('full');eq(#full.act,11);eq(#full.shrine,6);eq(#full.once,13)
end)
test('source shrine selection consumes once and no eligibility or extra option RNG',function()
 local p=Pool.new('restricted-seven');p.act={};p.shrine={'Golden Shrine'};local rng=R.fromSeed('42')
 local id,kind=Pool.draw(p,{act=1,floor=1,gold=0,hp=1},rng,0);eq(id,'Golden Shrine');eq(kind,'shrine');eq(#p.shrine,0)
 local before=C.copy(rng);eq(Pool.draw(p,{act=1},rng,0),nil);same(before,rng)
 Pool.nextAct(p);eq(#p.shrine,3);eq(#p.once,0)
end)
test('pray grants A0 fixed 100 and repeat commands cannot pay again',function()
 local run,map=enter();local before=C.copy(run);local opts=Nodes.view(run,map).node.event.options
 eq(#opts,3);eq(opts[1].choice,'pray');eq(opts[2].choice,'desecrate');eq(opts[3].choice,'leave')
 assert(Nodes.chooseEvent(run,'pray'));eq(run.gold,before.gold+100);same(run.deck,before.deck);same(run.miscRng,before.miscRng);same(run.eventRng,before.eventRng);eq(run.seed,before.seed)
 before=C.copy(run);assert(not Nodes.chooseEvent(run,'desecrate'));same(run,before)
end)
test('desecrate appends one permanent fresh-UID curse and exactly 275 gold',function()
 local run,map=enter();local before=C.copy(run);assert(Nodes.chooseEvent(run,'desecrate'))
 eq(run.gold,before.gold+275);eq(#run.deck,#before.deck+1);local c=run.deck[#run.deck]
 eq(c.uid,before.nextDeckUid);eq(c.cardId,'regret');eq(c.upgraded,false);eq(run.nextDeckUid,before.nextDeckUid+1)
 eq(run.nodeFlow.event.obtainedCardUid,c.uid);same(run.miscRng,before.miscRng);same(run.eventRng,before.eventRng);eq(run.seed,before.seed)
 assert(Run.startCombat(run,'cultist_solo'));local found=0
 for _,pile in ipairs({run.combat.hand,run.combat.draw,run.combat.discard,run.combat.exhaust})do for _,v in ipairs(pile)do if v.cardId=='regret'then found=found+1 end end end;eq(found,1)
end)
test('leave and invalid options preserve all assets streams and UIDs',function()
 local run=enter();local before=C.copy(run);assert(not Nodes.chooseEvent(run,'gather'));same(run,before)
 assert(Nodes.chooseEvent(run,'leave'));eq(run.gold,before.gold);same(run.deck,before.deck);same(run.miscRng,before.miscRng);same(run.eventRng,before.eventRng);eq(run.seed,before.seed);eq(run.nextDeckUid,before.nextDeckUid)
end)
test('invalid curse UID allocation rejects atomically before gold is paid',function()
 local run=enter();run.nextDeckUid=9007199254740991.0;local before=C.copy(run)
 local ok=Nodes.chooseEvent(run,'desecrate');eq(ok,false);same(run,before)
end)
test('missing malformed or colliding curse acquisition rejects before any mutation',function()
 for _,mutate in ipairs({
  function(run) for i,c in ipairs(run.data.cards.cards)do if c.id=='regret'then table.remove(run.data.cards.cards,i);return end end end,
  function(run) for _,c in ipairs(run.data.cards.cards)do if c.id=='regret'then c.type='skill';return end end end,
  function(run) run.nextDeckUid=run.deck[1].uid end,
  function(run) run.nextDeckUid=0 end,
  function(run) run.nextDeckUid=1.5 end,
 })do local run=enter();mutate(run);local before=C.copy(run);eq(Nodes.chooseEvent(run,'desecrate'),false);same(run,before)end
end)
test('Regret is an unplayable non-upgradeable curse with empty ordinary use',function()
 local s=battle({'regret'});local d=s.catalog.cards.regret;eq(d.type,'curse');eq(d.rarity,'curse');eq(d.cost,-2);eq(#d.effects,0);eq(d.upgrade,nil);eq(d.ethereal,nil)
 local before=C.copy(s);local ok,reason=C.play(s,s.hand[1].uid);eq(ok,false);eq(reason,'unplayable_card');same(s,before)
end)
test('corrupted Regret optional fields cannot bypass acquisition preflight',function()
 for _,pair in ipairs({{'innate',true},{'repeatable',true},{'upgrade',false},{'condition',false},{'costMode',false}})do
  local run=enter();for _,c in ipairs(run.data.cards.cards)do if c.id=='regret'then c[pair[1]]=pair[2] end end
  local before=C.copy(run);eq(Nodes.chooseEvent(run,'desecrate'),false);same(run,before)
 end
end)
test('Regret counts itself and all end-turn cards before ethereal exhaust',function()
 local s=battle({'regret','dazed','defend','strike'});s.player.block=50;s.events={}
 assert(C.endTurn(s));eq(s.player.hp,76);eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'dazed')
 local loss,enemy;for i,e in ipairs(s.events)do if e.kind=='hp_loss'then loss=i;eq(e.detail.amount,4);eq(e.detail.blocked,0);eq(e.frame.player.block,50)elseif e.kind=='enemy_turn'then enemy=i end end
 assert(loss and enemy and loss<enemy)
end)
test('multiple Regret instances share captured hand size and each loses HP',function()
 local s=battle({'regret','regret','defend'});s.events={};assert(C.endTurn(s));eq(s.player.hp,74)
 local loss=0;for _,e in ipairs(s.events)do if e.kind=='hp_loss'then loss=loss+1;eq(e.detail.amount,3)elseif e.kind=='play'then error('curse trigger is not a player card play')end end;eq(loss,2)
end)
test('discarded exhausted and undrawn curses do not trigger',function()
 local s=battle({'regret','defend'});local curse
 for i,c in ipairs(s.hand)do if c.cardId=='regret'then curse=table.remove(s.hand,i);break end end
 s.discard={curse};s.exhaust={{uid=999,cardId='regret',upgraded=false}};s.draw={{uid=1000,cardId='regret',upgraded=false}};s.events={}
 assert(C.endTurn(s));eq(s.player.hp,80);for _,e in ipairs(s.events)do assert(e.kind~='hp_loss')end
end)
test('lethal curse loss resolves defeat before enemy actions or next draw',function()
 local s=battle({'regret','regret','defend'},2);s.events={};assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.turn,1)
 local loss=0;for _,e in ipairs(s.events)do assert(e.kind~='enemy_turn' and e.kind~='intent' and e.kind~='player_turn');if e.kind=='hp_loss'then loss=loss+1;eq(e.detail.amount,2)end end;eq(loss,1)
 eq(s.cardInUse.cardId,'regret');eq(#s.hand,2);eq(#s.discard,0)
 local before=C.copy(s);assert(not C.endTurn(s));same(s,before)
end)
test('curse never enters upgrade, reward, or shop pools but purifier removes its UID',function()
 local run,map=enter();assert(Nodes.chooseEvent(run,'desecrate'));local curse=run.deck[#run.deck]
 run.nodeFlow=nil;run.phase='map';map=Map.generate(Data,42);map.nodes[1].type='camp';assert(Nodes.enter(run,map,map.nodes[1].id))
 for _,card in ipairs(Nodes.view(run,map).node.upgradeCards)do assert(card.cardId~='regret')end
 assert(not Nodes.upgrade(run,curse.uid));assert(Nodes.rest(run));run.nodeFlow=nil
 map=Map.generate(Data,42);map.nodes[1].type='shop';assert(Nodes.enter(run,map,map.nodes[1].id));for _,card in ipairs(run.nodeFlow.cards)do assert(card.id~='regret')end;assert(Nodes.leaveShop(run));run.nodeFlow=nil
 assert(Run.startCombat(run,'cultist_solo'));run.combat.enemies[1].hp=0;assert(Run.finishCombat(run));for _,id in ipairs(Run.rewardOptions(run))do assert(id~='regret')end;assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run)
 map=Map.generate(Data,42);map.nodes[1].type='event';map.nodes[1].eventId='purifier';assert(Nodes.enter(run,map,map.nodes[1].id));assert(Nodes.chooseEvent(run,'pray',curse.uid));for _,card in ipairs(run.deck)do assert(card.uid~=curse.uid)end
end)
test('normal unknown-room selection reaches Golden Shrine and records one consumed shrine',function()
 local seen=false
 for seed=1,300 do
  local run,map=Run.new(Data,seed),Map.generate(Data,seed);map.nodes[1].type='event'
  assert(Nodes.enter(run,map,map.nodes[1].id))
  if run.nodeFlow.event and run.nodeFlow.event.id=='golden_shrine'then
   seen=true;eq(run.nodeFlow.event.originalId,'Golden Shrine');eq(#run.unknown.pools.shrine,2)
   local before=C.copy(run);Nodes.view(run,map);Nodes.view(run,map);same(run,before);break
  end
 end
 assert(seen,'production natural selection must reach the seventh event')
end)
test('lethal Regret halts regen temporary strength and ethereal cleanup',function()
 local s=battle({'regret','regret','dazed'},1);s.player.statuses.regen=4;s.player.statuses.strength=5;s.player.temporaryStrength=5;s.events={}
 assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.statuses.regen,4);eq(s.player.statuses.strength,5);eq(s.player.temporaryStrength,5)
 eq(#s.hand,2);eq(#s.exhaust,0);eq(#s.discard,0);assert(s.cardInUse)
 for _,e in ipairs(s.events)do assert(e.kind~='heal' and e.kind~='status')end
end)
test('permanent UID allocation crosses int32 and accepts the last advancing safe value',function()
 for _,uid in ipairs({2147483647,9007199254740990.0})do
  local run=enter();run.nextDeckUid=uid;assert(Nodes.chooseEvent(run,'desecrate'));eq(run.deck[#run.deck].uid,uid);eq(run.nextDeckUid,uid+1.0)
 end
end)
test('Regret loss ignores supported attack modifiers without triggering retaliation',function()
 local s=battle({'regret','defend','strike'});s.player.statuses.strength=40;s.player.statuses.weak=1;s.player.statuses.vulnerable=2;s.player.statuses.thorns=7
 assert(C.endTurn(s));eq(s.player.hp,77)
end)
test('real node battle defeat preserves permanent curse and blocks route advancement',function()
 local run,map=enter();assert(Nodes.chooseEvent(run,'desecrate'));local permanent=C.copy(run.deck)
 run.nodeFlow=nil;map=Map.generate(Data,42);map.nodes[1].type='combat';map.nodes[1].encounterId='cultist_solo'
 assert(Nodes.enter(run,map,map.nodes[1].id));local s=run.combat;s.hand={{uid=500,cardId='regret',upgraded=false}};s.player.hp=1
 assert(C.endTurn(s));assert(Run.finishCombat(run));eq(run.phase,'defeat');eq(run.hp,0);same(run.deck,permanent)
 eq(#Nodes.available(run,map),0);local ok,reason=Nodes.completeCombat(run,map);eq(ok,false);eq(reason,'run_defeated')
end)
print('GOLDEN_SHRINE '..count..' tests, '..failed..' failed');assert(failed==0)
