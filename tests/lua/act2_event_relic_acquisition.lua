local H=dofile('tests/helpers/act2_event_relics.lua')
local F=dofile('tests/helpers/act2_choice_events.lua')
local eq,same,test=H.eq,H.same,H.test
local function finishTome(r)
 assert(F.Nodes.chooseEvent(r,'read'));for _=1,3 do assert(F.Nodes.chooseEvent(r,'continue'))end
 assert(F.Nodes.chooseEvent(r,'obtain'));eq(r.nodeFlow.event.stage,'reward')
end
test('Altar actual GoldenIdol slot becomes real BloodyIdol, then positive gold heals5 exactly once',function()
 local r=F.fixture('forgotten_altar',function(s)
  assert(H.Run.obtainRelic(s,'Anchor'));assert(H.Run.obtainRelic(s,'Golden Idol'));assert(H.Run.obtainRelic(s,'Lantern'));s.hp=30
 end)
 local position;for i,id in ipairs(r.relics)do if id=='golden_idol'then position=i end end
 local pool=H.C.copy(r.relicPool);assert(F.Nodes.chooseEvent(r,'offer_idol'));eq(r.relics[position],'bloody_idol')
 eq(r.relics[position-1],'anchor');eq(r.relics[position+1],'lantern');same(r.relicPool,pool)
 eq(r.hp,30);local gold=r.gold;eq(H.Run.gainGold(r,1),1);eq(r.gold,gold+1);eq(r.hp,35)
 eq(H.Run.gainGold(r,0),0);eq(r.hp,35);assert(F.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('Augmenter obtains real MutagenicStrength once; existing source identity gets actual Circlet',function()
 local r=F.fixture('drug_dealer');assert(F.Nodes.chooseEvent(r,'mutagens'));eq(r.nodeFlow.event.obtainedRelicId,'mutagenic_strength')
 assert(F.Nodes.chooseEvent(r,'leave'));local owned=false;for _,id in ipairs(r.relics)do if id=='mutagenic_strength'then owned=true end end;assert(owned)
 r=F.fixture('drug_dealer',function(s)assert(H.Run.obtainRelic(s,'MutagenicStrength'))end)
 assert(F.Nodes.chooseEvent(r,'mutagens'));eq(r.nodeFlow.event.obtainedRelicId,'circlet');eq(r.relicCounters.circlet,1)
end)
test('all THREE Tome outcomes are real source relic claims; one exact unowned candidate still draws misc once',function()
 local books={'Necronomicon','Enchiridion',"Nilry's Codex"}
 for index,wanted in ipairs(books)do
  local r=F.fixture('cursed_tome',function(s)for i,id in ipairs(books)do if i~=index then assert(H.Run.obtainRelic(s,id))end end end)
  finishTome(r);eq(r.nodeFlow.event.book.sourceId,wanted);local hp=r.hp;local rng=H.R.snapshot(r.miscRng)
  assert(F.Nodes.chooseEvent(r,'claim'));eq(r.nodeFlow.event.obtainedRelicId,({'necronomicon','enchiridion','nilrys_codex'})[index])
  eq(r.hp,hp);same(H.R.snapshot(r.miscRng),rng);assert(F.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
  local curses=0;for _,c in ipairs(r.deck)do if c.cardId=='necronomicurse'then curses=curses+1 end end;eq(curses,1)
 end
end)
test('Necronomicon actual curse obtain sees Omamori/Fish/Darkstone, not inert special-card exemption',function()
 local r=H.run({'Omamori','CeramicFish','Darkstone Periapt'});local before=#r.deck;local gold=r.gold
 assert(H.Run.obtainRelic(r,'Necronomicon'));eq(#r.deck,before);eq(r.relicCounters.omamori,1);eq(r.maxHp,80);eq(r.gold,gold)
 r=H.run({'CeramicFish','Darkstone Periapt'});gold=r.gold
 assert(H.Run.obtainRelic(r,'Necronomicon'));eq(r.deck[#r.deck].cardId,'necronomicurse');eq(r.gold,gold+9);eq(r.maxHp,86)
end)
test('missing Necronomicurse or late real acquire hook failure refuses entire book claim but not prior Tome fees',function()
 local r=F.fixture('cursed_tome',function(s)assert(H.Run.obtainRelic(s,'Enchiridion'));assert(H.Run.obtainRelic(s,"Nilry's Codex"))end)
 finishTome(r);eq(r.hp,64);local original=F.removeDefinition(r,'cards','necronomicurse')
 F.reject(r,'claim',nil,'card_content_unavailable');eq(r.hp,64);r.data=original
 local hooks=require('abyss_relic_hooks');local old=hooks.onObtainCard
 hooks.onObtainCard=function(...)old(...);return false,'late_necronomicurse'end
 F.reject(r,'claim',nil,'late_necronomicurse');hooks.onObtainCard=old
 assert(F.Nodes.chooseEvent(r,'claim'));eq(r.hp,64);eq(r.deck[#r.deck].cardId,'necronomicurse')
end)
test('permanent curse removal rebounds fresh unupgraded UID bypassing obtain hooks; unequal unequip bypass does not rebound',function()
 local r=H.run({'CeramicFish','Darkstone Periapt','Necronomicon','Omamori'});local card=r.deck[#r.deck];local gold,maxHp,counter=r.gold,r.maxHp,r.relicCounters.omamori
 local nextUid=r.nextDeckUid;assert(H.Run.removeCard(r,card.uid));local reborn=r.deck[#r.deck]
 eq(reborn.cardId,'necronomicurse');eq(reborn.uid,nextUid);eq(reborn.upgraded,false);eq(r.nextDeckUid,nextUid+1)
 eq(r.gold,gold);eq(r.maxHp,maxHp);eq(r.relicCounters.omamori,counter)
 local leaf=require('abyss_act2_event_relics');local before=#r.deck;assert(leaf.onUnequip(r,'necronomicon'));eq(#r.deck,before-1);eq(r.nextDeckUid,nextUid+1)
end)
test('real loseRelic dispatches while owned, removes only first curse without rebound, reacquires fresh curse after actual Omamori spending',function()
 local r=H.run({'Necronomicon'});assert(H.Run.obtainCard(r,'Necronomicurse'))
 local first,second=r.deck[#r.deck-1].uid,r.deck[#r.deck].uid
 assert(H.Run.obtainRelic(r,'CeramicFish'));assert(H.Run.obtainRelic(r,'Darkstone Periapt'));assert(H.Run.obtainRelic(r,'Omamori'))
 local leaf=require('abyss_act2_event_relics');local old=leaf.onUnequip;local dispatched=false
 leaf.onUnequip=function(staged,id)assert(leaf.owns(staged,'necronomicon'));dispatched=true;return old(staged,id)end
 local nextUid,gold,maxHp=r.nextDeckUid,r.gold,r.maxHp
 local ok,why=H.Run.loseRelic(r,'Necronomicon');leaf.onUnequip=old;assert(ok,why);assert(dispatched)
 eq(r.nextDeckUid,nextUid);eq(r.deck[#r.deck].uid,second);for _,c in ipairs(r.deck)do assert(c.uid~=first)end
 eq(r.gold,gold);eq(r.maxHp,maxHp);eq(r.relicCounters.omamori,2)
 assert(H.Run.obtainCard(r,'Injury'));assert(H.Run.obtainCard(r,'Injury'));eq(r.relicCounters.omamori,0)
 assert(H.Run.obtainRelic(r,'Necronomicon'));eq(r.deck[#r.deck].uid,nextUid);eq(r.deck[#r.deck].cardId,'necronomicurse')
 eq(r.gold,gold+9);eq(r.maxHp,maxHp+6)
end)
test('actual Nloth trade consumes real Necronomicon and its curse before giving real Gift',function()
 local r=F.fixture('nloth',function(staged)
  for i=#staged.relics,1,-1 do assert(H.Run.loseRelic(staged,staged.relics[i]))end
  assert(H.Run.obtainRelic(staged,'Necronomicon'));assert(H.Run.obtainRelic(staged,'Anchor'))
 end)
 local choice;for i,id in ipairs(r.nodeFlow.event.relicChoices)do if id=='necronomicon'then choice='trade_'..i end end;assert(choice)
 assert(F.Nodes.chooseEvent(r,choice));eq(r.nodeFlow.event.removedRelicId,'necronomicon');eq(r.nodeFlow.event.obtainedRelicId,'nloths_gift')
 for _,c in ipairs(r.deck)do assert(c.cardId~='necronomicurse')end
 assert(F.Nodes.chooseEvent(r,'leave'));assert(H.Run.obtainRelic(r,'Necronomicon'));eq(r.deck[#r.deck].cardId,'necronomicurse')
end)
H.finish('ACT2_EVENT_RELIC_ACQUISITION')
