local F=dofile('tests/lua/support/mushrooms_fixture.lua');local Run,N,C=F.Run,F.N,F.C
local function ready(duplicate)
 local r,m=F.enter();if duplicate then assert(Run.obtainRelic(r,'odd_mushroom'))end
 assert(N.chooseEvent(r,'fight'));return r,m
end
local function rejected(r,fn)local copy=C.copy(r);local flow=r.nodeFlow;local called,ok=pcall(fn);assert(not called or not ok);F.same(r,copy);assert(r.nodeFlow==flow)end
local r=ready();local old=Run.prepareRelic
Run.prepareRelic=function()error('SPECIAL must never draw rarity or queue')end
assert(N.chooseEvent(r,'fight'));Run.prepareRelic=old
for _,e in ipairs(r.combat.enemies)do e.hp=0 end
local Cards=require('abyss_card_pool');local previous=Cards.prepareRewards
Cards.prepareRewards=function()error('late card reward failure')end
rejected(r,function()return Run.finishCombat(r)end);Cards.prepareRewards=previous;assert(Run.finishCombat(r))
assert(Run.claimRelicReward(r,1));assert(not Run.claimRelicReward(r,1))
local d=ready(true);local pool=C.copy(d.relicPool);assert(N.chooseEvent(d,'fight'));F.same(d.relicPool,pool);F.eq(d.eventCombat.relics[1].id,'circlet')
for _,e in ipairs(d.combat.enemies)do e.hp=0 end
assert(Run.finishCombat(d));assert(Run.claimRelicReward(d,1));F.eq(d.relicCounters.circlet,1)
local escape,m=ready();escape.potions[1]='smoke_bomb';assert(N.chooseEvent(escape,'fight'))
assert(Run.usePotion(escape,1));F.eq(escape.phase,'map');assert(not escape.eventCombat);assert(not F.owned(escape,'odd_mushroom'));assert(not Run.claimGoldReward(escape));assert(N.completeCombat(escape,m))
local wrong=ready();wrong.nodeFlow.event.preparedCombat.runSeed='99';rejected(wrong,function()return N.chooseEvent(wrong,'fight')end)
local late=ready();local Combat=require('abyss_combat');local start=Combat.new
Combat.new=function()error('late combat fault')end
rejected(late,function()return N.chooseEvent(late,'fight')end);Combat.new=start;assert(N.chooseEvent(late,'fight'))
local dead=ready();assert(N.chooseEvent(dead,'fight'));dead.combat.player.hp=0;dead.combat.phase='defeat'
assert(Run.finishCombat(dead));F.eq(dead.phase,'defeat');assert(not dead.rewards);assert(not F.owned(dead,'odd_mushroom'));assert(not Run.claimRelicReward(dead,1))
print('MUSHROOMS_ROLLBACK_PASS 6 groups; SPECIAL no-queue/duplicate Circlet/smoke/owner mismatch/late failures')
