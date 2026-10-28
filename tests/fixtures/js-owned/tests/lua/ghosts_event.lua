-- Public Nodes/Run commands, source-locked staged room inputs; not native play.
local C,Run,Map,Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local Data,Pool,R,Unknown=require('abyss_data'),require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_unknown')
local Hooks=require('abyss_relic_hooks')
local base=Run.new(Data,'42',{experimental=true,campaign=true})
local baseMap=Map.generate(base.data,'42',2)
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 if a==b then return end;path=path or 'state';eq(type(a),type(b))
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function snap(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(maxHp,hp,character,unentered)
 local r=character and Run.new(Data,'42',{experimental=true,campaign=true,character=character}) or snap(base)
 r.act,r.floor=2,17;r.unknown.pools=Pool.new('full',false,2);r.maxHp=maxHp or 80;r.hp=hp or r.maxHp
 local m=C.copy(baseMap);local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=not unentered and 'ghosts' or nil end end
 if not unentered then assert(Nodes.enter(r,m,n.id))end
 return r,m,n.id
end
local function reject(r,choice,uid,expected)
 local before=snap(r);local owners={}
 for k,v in pairs(r)do if type(v)=='table'then owners[k]=v end end
 local ok,why=Nodes.chooseEvent(r,choice,uid);eq(ok,false);eq(why,expected);same(r,before)
 for k,v in pairs(owners)do eq(r[k],v)end
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS ghosts '..count..' '..name)end

test('source options cache exact small and float32 large HP costs, detached views remain pure',function()
 eq(Pool.contentId.Ghosts,'ghosts')
 for _,pair in ipairs({{1,0},{2,1},{3,2},{49,25},{50,25},{71,36},{75,38},{80,40},{16777217,8388608},{2147483647,1073741824}})do
  local r,m=fixture(pair[1]);local before=snap(r);local e=Nodes.view(r,m).node.event
  eq(e.hpLoss,pair[2]);eq(#e.options,2);eq(e.options[1].choice,'accept');eq(e.options[2].choice,'leave')
  assert(e.options[1].description:find(tostring(pair[2]),1,true));assert(e.options[1].description:find('5',1,true))
  eq(e.selection,nil);e.hpLoss=999;e.options[1].choice='purge';same(r,before)
 end
end)
test('HP loss clamps only, never heals or kills; zero max-cost and all relative HP cases',function()
 local invalid,m,id=fixture(nil,nil,nil,true);invalid.maxHp,invalid.hp=0,0
 for _,v in ipairs(m.nodes)do if v.id==id then v.eventId='ghosts'end end
 local before,mapBefore=snap(invalid),C.copy(m);local ok,why=Nodes.enter(invalid,m,id)
 eq(ok,false);eq(why,'node_content_unavailable');same(invalid,before);same(m,mapBefore)
 for _,row in ipairs({{1,1,1,1},{2,1,1,1},{3,3,1,1},{75,10,37,10},{80,40,40,40},{80,80,40,40}})do
  local r=fixture(row[1],row[2]);local old=#r.deck;assert(Nodes.chooseEvent(r,'accept'))
  eq(r.maxHp,row[3]);eq(r.hp,row[4]);eq(#r.deck,old+5);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 end
end)
test('constructor cache survives real Fruit Juice and zero-cache later growth without repricing',function()
 for _,row in ipairs({{80,40,45},{1,0,6}})do
  local r,m=fixture(row[1]);r.potions={'fruit_juice'};assert(Run.usePotion(r,1));eq(r.maxHp,row[1]+5)
  local before=snap(r);eq(Nodes.view(r,m).node.event.hpLoss,row[2]);same(r,before)
  assert(Nodes.chooseEvent(r,'accept'));eq(r.maxHp,row[3]);eq(r.nodeFlow.event.hpLoss,row[2])
  assert(Nodes.chooseEvent(r,'leave'));eq(r.maxHp,row[3]);eq(r.phase,'map')
 end
end)
test('exactly five fresh canonical cards and post-cost before/obtain hooks, no prepared-plan reuse',function()
 local r=fixture();local old=C.copy(r);local first=r.nextDeckUid;local before,on=Hooks.beforeObtainCard,Hooks.onObtainCard
 local seen,pre,post={},0,0
 Hooks.beforeObtainCard=function(staged,definition)
  eq(staged.hp,40);eq(staged.maxHp,40);eq(definition.id,'apparition');eq(#staged.deck,#old.deck+pre)
  pre=pre+1;return before(staged,definition)
 end
 Hooks.onObtainCard=function(staged,card,definition,api)
  eq(staged.maxHp,40);eq(staged.hp,40);eq(card.uid,first+post);eq(#staged.deck,#old.deck+post)
  assert(not seen[card] and not seen[card.uid]);seen[card]=true;seen[card.uid]=true;post=post+1
  return on(staged,card,definition,api)
 end
 local ok,why=Nodes.chooseEvent(r,'accept');Hooks.beforeObtainCard,Hooks.onObtainCard=before,on;assert(ok,why)
 eq(pre,5);eq(post,5);eq(r.nextDeckUid,first+5);eq(#r.nodeFlow.event.obtainedCardUids,5);eq(r.nodeFlow.event.obtainedCardUid,nil)
 for i,card in ipairs(old.deck)do same(r.deck[i],card)end
 for i=1,5 do local card=r.deck[#old.deck+i];eq(card.uid,first+i-1);eq(card.cardId,'apparition');eq(card.upgraded,false);eq(r.nodeFlow.event.obtainedCardUids[i],card.uid)end
 same(r.data.cards.sourcePools,old.data.cards.sourcePools);same(r.eventRng,old.eventRng);same(r.miscRng,old.miscRng);same(r.cardRng,old.cardRng)
 same(r.relicPool,old.relicPool);same(r.treasureRng,old.treasureRng);eq(r.seed,old.seed)
end)
test('Ceramic Fish gets five actual obtains, Ectoplasm suppresses, curse-only hooks do not run',function()
 for _,ectoplasm in ipairs({false,true})do
  local r=fixture();r.relics={'ceramic_fish','omamori','darkstone_periapt'};r.relicCounters={omamori=2}
  if ectoplasm then r.relics[#r.relics+1]='ectoplasm'end
  local gold=r.gold;assert(Nodes.chooseEvent(r,'accept'));eq(r.gold,gold+(ectoplasm and 0 or 45));eq(r.maxHp,40)
  eq(r.relicCounters.omamori,2);eq(r.deck[#r.deck].upgraded,false)
 end
 -- Explicit missing-capability fixture, not a global catalogue-absence
 -- invariant: future legitimate Toxic Egg support must not make this fail.
 local r=fixture();r.data=C.copy(r.data)
 for i=#r.data.relics.relics,1,-1 do
  local definition=r.data.relics.relics[i]
  if definition.id=='toxic_egg' or definition.id=='Toxic Egg 2' or definition.sourceId=='Toxic Egg 2'then table.remove(r.data.relics.relics,i)end
 end
 local before=snap(r);local ok,why=Run.obtainRelic(r,'Toxic Egg 2')
 eq(ok,false);eq(why,'relic_content_unavailable');same(r,before)
end)
test('maxHP reduction is not damage/heal/Fairy/Block/HP-loss callbacks; API refuses bad health contexts',function()
 local r=fixture();r.relics={'tungsten_rod','centennial_puzzle','mark_of_bloom'};r.relicCounters={centennial_puzzle=3};r.potions={'fairy_in_a_bottle'};r.block=99
 local fairy=require('abyss_potion_fairy');local saved,fatal=fairy.outside,fairy.fatal
 fairy.outside=function()error('maxHP loss must not dispatch Fairy')end;fairy.fatal=function()error('not fatal HP loss')end
 -- Current accepted base owns HP-loss reactions separately. MaxHP cost must
 -- bypass that owner too, rather than inheriting Rupture/Puzzle/V4 callbacks.
 local hpLoss=require('abyss_hp_loss');local notify,wasHpLost=hpLoss.notify,Hooks.wasHpLost
 hpLoss.notify=function()error('not HP-loss notification')end;Hooks.wasHpLost=function()error('not HP-loss relic callback')end
 local damage,heal=Run.eventDamage,Run.heal;Run.eventDamage=function()error('not damage')end;Run.heal=function()error('not healing')end
 local ok,why=Nodes.chooseEvent(r,'accept');fairy.outside,fairy.fatal=saved,fatal
 hpLoss.notify,Hooks.wasHpLost=notify,wasHpLost;Run.eventDamage,Run.heal=damage,heal;assert(ok,why)
 eq(r.hp,40);eq(r.maxHp,40);eq(r.block,99);eq(r.relicCounters.centennial_puzzle,3);same(r.potions,{'fairy_in_a_bottle'})
 for _,mode in ipairs({'combat','retained','rewards'})do
  local other=fixture();if mode=='combat'then other.phase='combat'elseif mode=='retained'then other.combat={player={hp=80,maxHp=80}}else other.pendingCombatRewards={combat={}}end
  local before=snap(other);local good,reason=Run.decreaseMaxHp(other,0);eq(good,false);eq(reason,'max_hp_health_context_unavailable');same(other,before)
  if mode~='combat'then reject(other,'accept',nil,'max_hp_health_context_unavailable')end
 end
 for _,value in ipairs({-1,0.5,'1',math.huge,2147483648.0})do local other=fixture();local before=snap(other);local good,reason=Run.decreaseMaxHp(other,value);eq(good,false);eq(reason,'invalid_max_hp');same(other,before)end
 local other=fixture(3);assert(Run.decreaseMaxHp(other,99));eq(other.maxHp,1);eq(other.hp,1)
end)
test('missing or capability-rejected Apparition atomically refuses and recovers',function()
 for _,mode in ipairs({'missing','unsupported'})do
  local r=fixture();local original=r.data;r.data=C.copy(r.data)
  for i=#r.data.cards.cards,1,-1 do local d=r.data.cards.cards[i];if d.id=='apparition'then
   if mode=='missing'then table.remove(r.data.cards.cards,i)else d.effects={{op='ghosts_unsupported'}}end
  end end
  reject(r,'accept',nil,'card_content_unavailable');r.data=original;assert(Nodes.chooseEvent(r,'accept'));eq(r.maxHp,40)
 end
end)
test('later UID collision/overflow and Ceramic Fish overflow roll back all HP/resources/owners',function()
 local r=fixture();r.nextDeckUid=9007199254740988.0;reject(r,'accept',nil,'invalid_deck_uid')
 r=fixture();r.deck[#r.deck+1]={uid=r.nextDeckUid+3,cardId='strike'};reject(r,'accept',nil,'invalid_deck_uid')
 r=fixture();r.relics={'ceramic_fish'};r.gold=2147483620;reject(r,'accept',nil,'transaction_failed')
 eq(r.hp,80);eq(r.maxHp,80);eq(r.nodeFlow.event.hpLoss,40)
end)
test('late explicit hook refusal or exception rolls back entire graph and recovers',function()
 for _,throws in ipairs({false,true})do
  local r=fixture();local original=Hooks.onObtainCard;local calls=0
  Hooks.onObtainCard=function(staged,card,definition,api)
   calls=calls+1;eq(staged.maxHp,40);eq(card.uid,base.nextDeckUid+calls-1)
   original(staged,card,definition,api)
   if calls==4 then
    staged.gold=999;staged.relicCounters={omamori=0};staged.potions={};R.randomInt(staged.miscRng,99);R.randomInt(staged.cardRng,99)
    R.randomInt(staged.eventRng,99);staged.unknown.pools.act={};staged.nodeFlow.event.hpLoss=1
    if throws then error('late Ghosts hook')end;return false,'ghosts_late_refusal'
   end
   return true
  end
  reject(r,'accept',nil,throws and 'transaction_failed' or 'ghosts_late_refusal');Hooks.onObtainCard=original;eq(calls,4)
  assert(Nodes.chooseEvent(r,'accept'));eq(r.nextDeckUid,base.nextDeckUid+5)
 end
end)
test('malformed/repeated actions reject; accept and decline each require distinct result Leave',function()
 for _,choice in ipairs({'accept','leave'})do
  local r,m=fixture();local before=snap(r)
  for _,bad in ipairs({'purge','confirm','decline',true,1,{}})do reject(r,bad,nil,'invalid_event_choice')end
  reject(r,choice,7,'invalid_event_choice');reject(r,choice,false,'invalid_event_choice')
  assert(Nodes.chooseEvent(r,choice));eq(r.phase,'node');eq(r.nodeFlow.complete,false);eq(r.nodeFlow.event.stage,'result')
  if choice=='leave'then eq(r.hp,before.hp);eq(r.maxHp,before.maxHp);same(r.deck,before.deck);eq(r.gold,before.gold)end
  eq(#Nodes.view(r,m).node.event.options,1);reject(r,'accept',nil,'invalid_event_choice');reject(r,'leave',1,'invalid_event_choice')
  assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true);reject(r,'leave',nil,'no_pending_node')
 end
end)
test('full13 source/order and real unknown selection remove Ghosts once with no action RNG draws',function()
 same(Pool.new('full',false,2).act,{'Addict','Back to Basics','Beggar','Colosseum','Cursed Tome','Drug Dealer','Forgotten Altar','Ghosts','Masked Bandits','Nest','The Library','The Mausoleum','Vampires'})
 local counter
 for n=0,127 do
  local rng=R.atCounter(base.eventSeed,n);local nextRng=R.cloneState(rng)
  if Unknown.advancePc(Unknown.newPc(),R.randomFloat(nextRng),{})=='event'then
   local id=Pool.draw(Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},R.atCounter(base.eventSeed,nextRng.counter))
   if id=='Ghosts'then counter=n;break end
  end
 end
 assert(counter,'bounded Ghosts selection input missing')
 local broken,bmap,bid=fixture(nil,nil,nil,true);broken.maxHp,broken.hp=0,0;broken.eventRng=R.atCounter(broken.eventSeed,counter)
 local prior,mapPrior=snap(broken),C.copy(bmap);local owners={deck=broken.deck,unknown=broken.unknown,eventRng=broken.eventRng}
 local good,reason=Nodes.enter(broken,bmap,bid);eq(good,false);eq(reason,'node_content_unavailable');same(broken,prior);same(bmap,mapPrior)
 for key,value in pairs(owners)do eq(broken[key],value)end
 for _,choice in ipairs({'accept','leave'})do
  local r,m,id=fixture(nil,nil,nil,true);r.eventRng=R.atCounter(r.eventSeed,counter);assert(Nodes.enter(r,m,id))
  eq(r.nodeFlow.event.originalId,'Ghosts');eq(r.nodeFlow.event.id,'ghosts');eq(#r.unknown.pools.act,12)
  eq(r.eventRng.counter,counter+1);eq(r.nodeFlow.selectionRng.counter,counter+3)
  local before=snap(r);assert(Nodes.chooseEvent(r,choice));assert(Nodes.chooseEvent(r,'leave'))
  for _,key in ipairs({'eventRng','miscRng','cardRng','treasureRng','relicPool','unknown'})do same(r[key],before[key])end
 end
 local p=Pool.new('restricted-seven');eq(#p.act+#p.shrine+#p.once,7)
 for _,list in ipairs({p.act,p.shrine,p.once})do for _,id in ipairs(list)do assert(id~='Ghosts')end end
end)
test('all eight actual profiles retain private catalogues and acquired cards work in real next combat',function()
 for _,character in ipairs({'ironclad','silent','defect','watcher','HT','AR','FR','RD'})do
  local r,m=fixture(80,80,character);local other=fixture(80,80,character);local untouched=C.copy(other);local first=#r.deck+1
  assert(Nodes.chooseEvent(r,'accept'));eq(#r.nodeFlow.event.obtainedCardUids,5);same(other,untouched)
  local view=Nodes.view(r,m);view.node.event.obtainedCardUids[1]=999;eq(r.nodeFlow.event.obtainedCardUids[1],r.deck[first].uid)
  assert(Nodes.chooseEvent(r,'leave'));r.deck={C.copy(r.deck[first]),C.copy(r.deck[first+1])}
  r.floor=19;r.encounters=require('abyss_encounter_queue').new(r.runSeed,2)
  assert(Run.startRoomCombat(r,'normal'));local s=r.combat;eq(s.player.maxHp,40)
  local played,found=nil,0;for _,card in ipairs(s.hand)do if card.cardId=='apparition'then found=found+1;played=played or card.uid end end;eq(found,2)
  assert(C.play(s,played));eq(s.player.statuses.intangible,1);eq(s.exhaust[1].uid,played)
  local hp=s.player.hp;C.damage(s,s.enemies[1],s.player,100);eq(s.player.hp,hp-1)
  assert(C.endTurn(s));local exhausted=0;for _,card in ipairs(s.exhaust)do if card.cardId=='apparition'then exhausted=exhausted+1 end end;eq(exhausted,2)
  for _,pile in ipairs({s.discard,s.hand,s.draw})do for _,card in ipairs(pile)do assert(card.cardId~='apparition')end end
  eq(r.deck[1].upgraded,false);same(other,untouched)
 end
end)
print('GHOSTS_EVENT '..count..' passed')
