-- Two public uses share one combat source stream. Hand9 is a controlled fixture;
-- all inventory acquisition, potion use and selection dispatch real Run APIs.
local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(v,bark)
  local run=Run.new(D,v.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
  if bark then assert(Run.obtainRelic(run,'SacredBark'))end
  assert(Run.obtainPotion(run,'colorless_potion'));assert(Run.obtainPotion(run,'colorless_potion'))
  assert(Run.startCombat(run,'cultist_solo'));local s=run.combat
  while #s.hand<9 do s.hand[#s.hand+1]=assert(table.remove(s.draw))end
  local permanent=C.copy(run.deck);local energy,gold,hp,maxHp=s.energy,run.gold,run.hp,run.maxHp
  local function unrelated()
   local out={event=R.snapshot(run.eventRng),misc=R.snapshot(run.miscRng),treasure=R.snapshot(run.treasureRng),card=R.snapshot(run.cardRng),shop=run.shopRng and C.copy(run.shopRng)or false}
   for _,key in ipairs({'shuffleRng','aiRng','monsterHpRng','miscRng','cardRng','potionRng'})do if s[key]then out['combat_'..key]=R.snapshot(s[key])end end
   return out
  end
  local other=unrelated();same(R.snapshot(s.cardRandomRng),v.initial,'initial cardRandomRng')
  local function source(id)return assert(s.catalog.cards[id].sourceId)end
  local pool={};for _,id in ipairs(require('abyss_potion_discovery').pool(s,'colorless'))do pool[#pool+1]=source(id)end
  same(pool,v.pool,'complete source-ordered non-HEALING colorless pool')
  local raw,trace=R.randomInt,{}
  R.randomInt=function(owner,maximum,...)
   local before=R.snapshot(owner);local result=raw(owner,maximum,...)
   trace[#trace+1]={maximum=maximum,value=result,before=before,after=R.snapshot(owner)};return result
  end
  local stale
  for number,use in ipairs(v.uses)do
   local beforeHand,beforeDiscard,nextUid=#s.hand,#s.discard,s.nextUid
   assert(Run.usePotion(run,number));assert(run.potions[number]==nil)
   local p=assert(s.pendingChoice);assert(p.op=='discover'and #p.cards==3)
   local offers={};for _,card in ipairs(p.cards)do offers[#offers+1]=source(card.cardId);assert(not s.catalog.cards[card.cardId].healing)end
   same(offers,use.open.cards,'colorless visible offers '..number)
   same(R.snapshot(s.cardRandomRng),use.open.after,'colorless opening stream '..number)
   assert(s.catalog.cards[p.cards[use.selection].cardId].cost==use.selectedBaseCost and use.selectedBaseCost>0)
   local before=C.copy(run)
   assert(not Run.chooseCard(run,p.token,999));same(run,before,'invalid selection atomic')
   if stale then assert(not Run.chooseCard(run,stale,use.selection));same(run,before,'old token rejects new visible owner atomically')end
   local token=p.token;assert(Run.chooseCard(run,token,use.selection));assert(not s.pendingChoice)
   same(R.snapshot(s.cardRandomRng),use.retrieval.after,'colorless retrieval stream '..number)
   local amount=bark and 2 or 1
   assert(s.nextUid==nextUid+amount and #s.hand==10 and #s.discard==beforeDiscard+amount-(10-beforeHand))
   local found={}
   for _,pile in ipairs({s.hand,s.discard})do for _,card in ipairs(pile)do if card.uid>=nextUid and card.uid<nextUid+amount then
    assert(not found[card.uid]);found[card.uid]=true
    assert(source(card.cardId)==use.selectedSourceId and card.costForTurn==0 and C.cardDefinition(s,card).cost==0)
    assert(s.catalog.cards[card.cardId].cost==use.selectedBaseCost,'temporary discount must not rewrite catalog base cost')
   end end end
   for uid=nextUid,nextUid+amount-1 do assert(found[uid],'selected copy lost its unique combat UID')end
   same(run.deck,permanent,'permanent deck unchanged');assert(s.energy==energy and run.gold==gold and run.hp==hp and run.maxHp==maxHp)
   local after=C.copy(run);assert(not Run.chooseCard(run,token,use.selection));same(run,after,'consumed token atomic')
   stale=token
  end
  local expected={};for _,t in ipairs(v.trace)do local item=C.copy(t);item.phase=nil;expected[#expected+1]=item end
  same(trace,expected,'every colorless index attempt/value/owner before and after')
  same(unrelated(),other,'unrelated source streams unchanged')
  R.randomInt=raw
  print('COLORLESS_POTION_SOURCE_PASS bark='..tostring(bark)..' wrappers='..#trace)
end
