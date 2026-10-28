local F=dofile('tests/lua/support/mushrooms_fixture.lua');local Run,N,C=F.Run,F.N,F.C
for _,mode in ipairs({'plain','mark','omamori','darkstone'})do
 local r=F.enter();r.hp,r.maxHp=20,83
 if mode=='mark'then assert(Run.obtainRelic(r,'mark_of_bloom'))end
 if mode=='omamori'then assert(Run.obtainRelic(r,'omamori'))end
 if mode=='darkstone'then assert(Run.obtainRelic(r,'darkstone_periapt'))end
 local before=C.copy(r);local queue=C.copy(r.encounters);local misc=C.copy(r.miscRng)
 do
  local events={};local oldHeal,oldObtain=Run.heal,Run.obtainCard
  Run.heal=function(...)events[#events+1]='heal';return oldHeal(...)end
  Run.obtainCard=function(...)events[#events+1]='obtain';return oldObtain(...)end
  assert(N.chooseEvent(r,'heal'));Run.heal,Run.obtainCard=oldHeal,oldObtain
  F.eq(table.concat(events,','),mode=='darkstone'and'heal,obtain,heal'or'heal,obtain');F.eq(r.hp,mode=='mark'and 20 or mode=='darkstone'and 46 or 40)
  F.eq(#r.deck,#before.deck+(mode=='omamori'and 0 or 1));F.eq(r.nodeFlow.event.curseBlocked,mode=='omamori')
  if mode~='omamori'then F.eq(r.deck[#r.deck].cardId,'parasite');local max=r.maxHp;assert(Run.removeCard(r,r.deck[#r.deck].uid));F.eq(r.maxHp,max-3)end
  F.same(r.encounters,queue);F.same(r.miscRng,misc);assert(not r.nodeFlow.event.preparedCombat)
  local snapshot=C.copy(r);assert(not N.chooseEvent(r,'heal'));F.same(r,snapshot)
  assert(N.chooseEvent(r,'leave'));F.eq(r.phase,'map')
 end
end
local r=F.enter();r.hp=10;local before=C.copy(r);local old=Run.obtainCard
Run.obtainCard=function()error('late obtain fault')end
local ok=N.chooseEvent(r,'heal');Run.obtainCard=old;assert(not ok);F.same(r,before);assert(N.chooseEvent(r,'heal'))
print('MUSHROOMS_HEAL_PASS 5 groups; heal before Parasite/Mark/Omamori/remove hook/late rollback')
