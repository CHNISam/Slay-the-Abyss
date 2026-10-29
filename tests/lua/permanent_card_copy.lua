local Run,C=require('abyss_run'),require('abyss_combat')
local Data=require('abyss_data')
assert(type(Run.obtainCardCopy)=='function','stat-equivalent permanent obtain API must exist')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS permanent copy '..n..' '..name)end

test('prepared stat snapshot is detached and ordinary obtain never inherits another card stats',function()
 local run=Run.new(Data,105);assert(Run.obtainCard(run,'ritual_dagger'))
 local source=run.deck[#run.deck];source.misc,source.costOverride=42,0
 local offer=assert(Run.prepareCardCopy(run,source.uid));source.misc=99
 assert(offer.statEquivalent.misc==42);local ok,uid=Run.commitCard(run,offer);assert(ok)
 local copied=run.deck[#run.deck];assert(copied.uid==uid and copied.misc==42 and copied.costOverride==0)
 offer.statEquivalent.misc=77;assert(copied.misc==42)
 assert(Run.obtainCard(run,'ritual_dagger'));assert(run.deck[#run.deck].misc==nil and run.deck[#run.deck].costOverride==nil)
 assert(run.deck[#run.deck-2].misc==99)
end)

test('forged copy payload cannot transfer UID, bottle binding or malformed stats',function()
 local run=Run.new(Data,105)
 local bad={{uid=999},{inBottleFlame=true},{misc=-1},{misc=.5},{misc=math.huge},{misc='42'},
  {costOverride=-3},{costOverride=.5},{costOverride=2147483648},setmetatable({misc=42},{})}
 for _,payload in ipairs(bad)do
  local offer=assert(Run.prepareCard(run,'strike'));offer.statEquivalent=payload
  local before=C.copy(run);local ok,why=Run.commitCard(run,offer)
  assert(not ok and why=='invalid_card_copy');same(run,before)
 end
end)

test('copy source selection requires one live permanent UID',function()
 local run=Run.new(Data,105)
 for _,uid in ipairs({0,-1,.5,'1',999})do
  local before=C.copy(run);assert(not Run.obtainCardCopy(run,uid));same(run,before)
 end
 run.deck[#run.deck+1]=C.copy(run.deck[1]);local before=C.copy(run)
 assert(not Run.obtainCardCopy(run,run.deck[1].uid));same(run,before)
end)

test('Ritual growth and controlled permanent cost survive on both distinct owners next combat',function()
 local run=Run.new(Data,105);assert(Run.obtainCard(run,'ritual_dagger'))
 -- Controlled model boundary, not a claim that a cost-changing event is live.
 local source=run.deck[#run.deck];source.misc,source.costOverride=42,0
 local ok,uid=Run.obtainCardCopy(run,source.uid);assert(ok)
 assert(Run.startRoomCombat(run,'normal'))
 local seen={}
 for _,pile in ipairs({run.combat.hand,run.combat.draw,run.combat.discard})do for _,card in ipairs(pile)do
  if card.deckUid==source.uid or card.deckUid==uid then
   assert(card.misc==42 and card.costOverride==0,'permanent copy stats must survive next combat')
   assert(C.combatBaseCost(run.combat,card)==0 and C.cardDefinition(run.combat,card).cost==0)
   seen[card.deckUid]=true
  end
 end end
 assert(seen[source.uid] and seen[uid] and source.uid~=uid)
end)
print('PERMANENT_CARD_COPY_PASS '..n)
