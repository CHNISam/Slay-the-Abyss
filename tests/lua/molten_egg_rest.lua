local F=dofile('tests/lua/support/toxic_egg_fixture.lua');local Run,Nodes,R=F.Run,F.Nodes,F.R
local Pool=require('abyss_card_pool')
local function camp(egg)
 local r=Run.new(F.D,42);assert(Run.obtainRelic(r,'Dream Catcher'));assert(Run.obtainRelic(r,'CeramicFish'))
 if egg then assert(Run.obtainRelic(r,'Molten Egg 2'))end
 F.enter(r,'camp');return r
end
local a,b=camp(true),camp(false)
local expected,rng,offset=Pool.prepareRewards({data=a.data,cardRng=a.cardRng,cardRarityOffset=a.cardRarityOffset,encounterTier='normal'})
local gold,uid=a.gold,a.nextDeckUid;assert(Nodes.rest(a));assert(Nodes.rest(b))
F.same(a.nodeFlow.restReward.cards,expected);F.same(R.snapshot(a.cardRng),R.snapshot(rng));F.eq(a.cardRarityOffset,offset)
local selected
for i,id in ipairs(expected)do local d=F.definition(a,id);if d.type=='attack'and next(d.upgrade or{})then selected=i;F.eq(a.nodeFlow.restReward.cardUpgrades[i],true)end end
assert(selected);F.eq(a.gold,gold);F.eq(a.nextDeckUid,uid)
-- Source direct CardRewardScreen list is not revisited by MoltenEgg2.onEquip.
local before=F.C.copy(b.nodeFlow.restReward);assert(Run.obtainRelic(b,'Molten Egg 2'));F.same(b.nodeFlow.restReward,before)
assert(Nodes.claimRestReward(a,selected));assert(Nodes.claimRestReward(b,selected))
for _,r in ipairs({a,b})do local c=r.deck[#r.deck];F.eq(c.upgraded,true);assert(not c.upgrades or c.upgrades==1);F.eq(r.gold,gold+9);F.eq(r.phase,'map');F.eq(Nodes.claimRestReward(r,selected),false)end
print('MOLTEN_EGG_REST_PASS exact ordinary generation/preview/claim; onEquip leaves existing direct rest list unchanged, obtain still upgrades it once')
