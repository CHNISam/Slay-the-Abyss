local N,Run,R,C,Data=require('abyss_neow'),require('abyss_run'),require('abyss_sts_random'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if type(a)~='table'then eq(a,b);return end
 eq(type(b),'table');for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function snap(r)return C.copy(r,{[r.data]=r.data})end
local function fixture(seed)
 local r=Run.new(Data,tostring(seed));r.phase='node';r.gold=99;r.nodeFlow={type='event',event={id='neow'}}
 assert(N.prepare(r,r.nodeFlow.event,{bossCount=1}));assert(N.choose(r,r.nodeFlow,'continue'));return r
end
local function choose(r,choice,uid)return Run.transaction(r,function(s)return N.choose(s,s.nodeFlow,choice,uid)end)end
local function reject(r,choice,uid,reason)
 local before=snap(r);local old=r.nodeFlow
 local ok,why=choose(r,choice,uid);eq(ok,false);if reason then eq(why,reason)end;same(r,before);eq(r.nodeFlow,old)
end
local function finish(r)
 eq(r.nodeFlow.event.stage,'neow_result');reject(r,'continue');reject(r,'reward_1')
 local ok,status=choose(r,'leave');assert(ok);eq(status,'complete')
end
local function sourceChoices(r,colorless,rareOnly)
 local rng=R.cloneState(r.nodeFlow.event.neowRng);local cardRng=R.cloneState(r.cardRng)
 local offers,used={},{}
 for _=1,3 do
  local rarity=R.randomFloat(rng)<0.33000001311302185 and 'uncommon' or 'common'
  if rareOnly then rarity='rare'elseif colorless and rarity=='common'then rarity='uncommon'end
  local pool=colorless and r.data.cards.sourcePools.colorlessShop[rarity]or r.data.cards.sourcePools.reward[rarity]
  local id
  repeat id=pool[R.randomInt(colorless and cardRng or rng,#pool-1)+1]until not used[id]
  used[id]=true;offers[#offers+1]={cardId=id,rarity=rarity}
 end
 return offers,rng,cardRng
end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS neow rewards '..n..' '..name)end
test('gold and maximum health costs precede the selected reward',function()
 local r=fixture(0);eq(r.nodeFlow.event.rewards[3].type,'TWO_FIFTY_GOLD')
 local before=snap(r);assert(choose(r,'reward_3'));eq(r.maxHp,72);eq(r.hp,72);eq(r.gold,349)
 same(r.miscRng,before.miscRng);same(r.cardRng,before.cardRng);eq(r.nodeFlow.event.neowRng.counter,5);finish(r)
 local p=fixture(3);p.hp=79;assert(choose(p,'reward_3'));eq(p.hp,58);eq(p.maxHp,80);eq(p.gold,349);finish(p)
 local g=fixture(3);assert(choose(g,'reward_2'));eq(g.gold,199);eq(g.hp,80);finish(g)
end)
test('curse with twenty-percent bonus uses cached ten-percent twice then cardRng curse draw',function()
 local r=fixture(2);local before=snap(r);local oracle=R.cloneState(r.cardRng)
 local curses={'Regret','Injury','Shame','Parasite','Normality','Doubt','Writhe','Pain','Decay','Clumsy'}
 local source=curses[R.randomIntBetween(oracle,0,#curses-1)+1]
 assert(choose(r,'reward_3'));eq(r.maxHp,96);eq(r.hp,96);eq(#r.deck,#before.deck+1)
 local obtained=r.deck[#r.deck];local definition
 for _,d in ipairs(r.data.cards.cards)do if d.id==obtained.cardId then definition=d end end
 eq(definition.sourceId or definition.sts_name or definition.id,source)
 same(R.snapshot(r.cardRng),R.snapshot(oracle));same(r.miscRng,before.miscRng);eq(r.nextDeckUid,before.nextDeckUid+1);finish(r)
end)
test('colored choices consume only Neow RNG, never rarity offset or upgrade draws',function()
 for _,case in ipairs({{3,1,false},{8,3,true}})do
  local r=fixture(case[1]);local before=snap(r);local expected,rng,cardRng=sourceChoices(r,false,case[3])
  assert(choose(r,'reward_'..case[2]));eq(r.nodeFlow.event.stage,'neow_card_reward')
  same(r.nodeFlow.event.cardOffers,expected);same(R.snapshot(r.nodeFlow.event.neowRng),R.snapshot(rng))
  same(R.snapshot(r.cardRng),R.snapshot(cardRng));eq(r.cardRarityOffset,before.cardRarityOffset)
  if case[3]then eq(r.gold,0)else eq(r.gold,99)end
  local nextUid=r.nextDeckUid;assert(choose(r,'claim_2'));eq(r.deck[#r.deck].cardId,expected[2].cardId);eq(r.deck[#r.deck].uid,nextUid)
  eq(r.deck[#r.deck].upgraded,false);reject(r,'claim_2');finish(r)
 end
end)
test('colorless and rare-colorless choices split rarity and identity streams exactly',function()
 for _,slot in ipairs({1,3})do
  local r=fixture(1);local expected,rng,cardRng=sourceChoices(r,true,slot==3)
  local before=snap(r);assert(choose(r,'reward_'..slot))
  same(r.nodeFlow.event.cardOffers,expected);same(R.snapshot(r.nodeFlow.event.neowRng),R.snapshot(rng));same(R.snapshot(r.cardRng),R.snapshot(cardRng))
  same(r.miscRng,before.miscRng);eq(r.cardRarityOffset,before.cardRarityOffset)
  local size=#r.deck;assert(choose(r,'skip'));eq(#r.deck,size);finish(r)
 end
end)
test('random rare is immediate, one Neow integer and next permanent UID',function()
 local r=fixture(2);local oracle=R.cloneState(r.nodeFlow.event.neowRng);local pool=r.data.cards.sourcePools.reward.rare
 local id=pool[R.randomInt(oracle,#pool-1)+1];local uid=r.nextDeckUid;local before=snap(r)
 assert(choose(r,'reward_1'));eq(r.deck[#r.deck].cardId,id);eq(r.deck[#r.deck].uid,uid)
 same(R.snapshot(r.nodeFlow.event.neowRng),R.snapshot(oracle));same(r.cardRng,before.cardRng);finish(r)
end)
test('remove two pays integer HP loss first; selections preserve identity and both removals wait for second',function()
 local r=fixture(4);r.hp=79;local first,second=r.deck[1].uid,r.deck[2].uid;local size=#r.deck
 assert(choose(r,'reward_3'));eq(r.hp,58);eq(r.nodeFlow.event.selectionTotal,2)
 assert(choose(r,'select',first));eq(#r.deck,size);same(r.nodeFlow.event.selectedUids,{first})
 reject(r,'select',first,'invalid_card');reject(r,'leave');reject(r,'select','1','invalid_card')
 assert(choose(r,'select',second));eq(#r.deck,size-2);eq(r.nodeFlow.event.stage,'neow_result');reject(r,'select',first);finish(r)
end)
test('upgrade allows bottles while purge excludes them and all views are detached',function()
 local r=fixture(4);local uid=r.deck[1].uid;r.deck[1].inBottleFlame=true
 assert(choose(r,'reward_1'));local view=C.copy(r.nodeFlow.event);N.view(r,view)
 eq(view.selection.forUpgrade,true);eq(view.purgeCards[1].uid,uid)
 view.purgeCards[1].cardId='parasite';eq(r.deck[1].cardId,'strike')
 assert(choose(r,'select',uid));eq(r.deck[1].upgraded,true);eq(r.deck[1].upgrades,1);eq(r.deck[1].inBottleFlame,true);finish(r)
 local p=fixture(17);p.deck[1].inBottleLightning=true;assert(choose(p,'reward_1'))
 reject(p,'select',p.deck[1].uid,'invalid_card');local remove=p.deck[2].uid
 assert(choose(p,'select',remove));eq(p.deck[1].inBottleLightning,true);eq(#p.deck,9);finish(p)
end)
test('single and two transforms preserve source remove/obtain ordering and unique fresh UIDs',function()
 for _,case in ipairs({{0,1,1},{15,3,2}})do
  local r=fixture(case[1]);local count=case[3];local uid,nextUid=r.deck[1].uid,r.nextDeckUid
  local ids={uid,r.deck[2].uid};local size=#r.deck;local calls={}
  assert(choose(r,'reward_'..case[2]));local oldRemove,oldObtain=Run.removeCard,Run.obtainCard
  Run.removeCard=function(s,id)calls[#calls+1]='remove';return oldRemove(s,id)end
  Run.obtainCard=function(s,id,opts)calls[#calls+1]='obtain';return oldObtain(s,id,opts)end
  for i=1,count do assert(choose(r,'select',ids[i]))end
  Run.removeCard,Run.obtainCard=oldRemove,oldObtain
  eq(#r.deck,size);eq(r.nextDeckUid,nextUid+count);eq(#calls,count*2)
  for i=1,count do eq(calls[i],'remove');eq(calls[i+count],'obtain')end
  for i=1,count do local card=r.deck[#r.deck-count+i];eq(card.uid,nextUid+i-1);eq(card.upgraded,false)end
  eq(r.nodeFlow.event.neowRng.counter,5+count);finish(r)
 end
end)
test('three potions sample uniform class pool in potionRng and remain individually claimable',function()
 local r=fixture(0);local before=snap(r);local P=require('abyss_potion_random');local pool=P.pool('ironclad');local oracle=R.fromSeed(r.runSeed);local expected={}
 for i=1,3 do expected[i]=pool[R.randomIntBetween(oracle,0,#pool-1)+1].id end
 assert(choose(r,'reward_2'));eq(r.nodeFlow.event.stage,'neow_potions');same(R.snapshot(r.shopRng.potion),R.snapshot(oracle))
 same(r.miscRng,before.miscRng);same(r.cardRng,before.cardRng);eq(r.nodeFlow.event.neowRng.counter,5)
 for i,offer in ipairs(r.nodeFlow.event.potionOffers)do eq(offer.id,expected[i]);eq(offer.claimed,false)end
 assert(choose(r,'potion_1'));eq(r.potions[1],expected[1]);reject(r,'potion_1')
 assert(choose(r,'potion_2'));eq(r.potions[2],expected[2]);assert(choose(r,'potion_3'));eq(r.potions[3],expected[3])
 assert(choose(r,'skip'));finish(r)
end)
test('reward hook failure rolls back paid drawback, all streams, inventory and event to same offer',function()
 local r=fixture(0);local before=snap(r);local original=Run.gainGold
 Run.gainGold=function(staged,value)original(staged,value);R.randomInt(staged.miscRng,99);error('Neow gain failure')end
 reject(r,'reward_3',nil,'transaction_failed');same(r,before);Run.gainGold=original
 assert(choose(r,'reward_3'));eq(r.gold,349);eq(r.hp,72);finish(r)
end)
test('unsupported permanent acquisition refuses same original card without redraw and can recover',function()
 local r=fixture(2);local oldData=r.data;r.data=C.copy(r.data);local original=Run.obtainCard
 Run.obtainCard=function(staged,id)original(staged,id);return false,'bounded_neow_refusal'end
 reject(r,'reward_1',nil,'bounded_neow_refusal');Run.obtainCard=original;r.data=oldData
 assert(choose(r,'reward_1'));eq(r.nodeFlow.event.stage,'neow_result');finish(r)
end)
print('NEOW_REWARDS '..n..' passed')
