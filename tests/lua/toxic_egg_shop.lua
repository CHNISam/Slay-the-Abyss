local F=dofile('tests/lua/support/toxic_egg_fixture.lua');local Run,Nodes=F.Run,F.Nodes
local Shop=require('abyss_shop');local H=require('abyss_relic_hooks')
local a,b=Run.new(F.D,42),Run.new(F.D,42)
for _,r in ipairs({a,b})do assert(Run.obtainRelic(r,'courier'));Run.gainGold(r,3000)end
assert(Run.obtainRelic(a,'Toxic Egg 2'));assert(Run.obtainRelic(a,'CeramicFish'))
F.enter(a,'shop');F.enter(b,'shop')
local slot
for i,offer in ipairs(a.nodeFlow.cards)do
 local other=b.nodeFlow.cards[i];local d=F.definition(a,offer.id)
 F.eq(offer.id,other.id);F.eq(offer.price,other.price)
 local eligible=d.type=='skill'and next(d.upgrade or{})~=nil
 F.eq(offer.upgraded==true,eligible);if eligible then slot=i;F.eq(offer.upgrades,1)end
end
assert(slot);F.same(a.cardRng,b.cardRng);F.same(a.shopRng.merchant,b.shopRng.merchant);F.same(a.shopRng.potion,b.shopRng.potion)
local gold=a.gold;local offer=F.C.copy(a.nodeFlow.cards[slot]);local uid=a.nextDeckUid
assert(Nodes.buyCardSlot(a,slot));F.eq(a.gold,gold-offer.price+9);F.eq(a.deck[#a.deck].uid,uid);F.eq(a.deck[#a.deck].upgrades,1)
local fresh=a.nodeFlow.cards[slot];assert(not fresh.sold);local d=F.definition(a,fresh.id)
F.eq(fresh.upgraded==true,d.type=='skill'and next(d.upgrade or{})~=nil)
-- Use the same core path for b without Egg. Both ordinary restock streams agree.
assert(Nodes.buyCardSlot(b,slot));F.eq(fresh.id,b.nodeFlow.cards[slot].id);F.eq(fresh.price,b.nodeFlow.cards[slot].price)
F.same(a.cardRng,b.cardRng);F.same(a.shopRng.merchant,b.shopRng.merchant)
-- Existing shelf is a source snapshot, not part of ToxicEgg2.onEquip.
local shelf=F.C.copy(b.nodeFlow.cards);assert(Run.obtainRelic(b,'Toxic Egg 2'));F.same(b.nodeFlow.cards,shelf)
local existing
for i,c in ipairs(shelf)do if c.type=='skill'then existing=i;break end end;assert(existing)
assert(Nodes.buyCardSlot(b,existing));F.eq(b.deck[#b.deck].upgraded,true);F.eq(b.deck[#b.deck].upgrades,1)
local colored=b.nodeFlow.cards[existing];F.eq(colored.color,'colored');F.eq(colored.upgraded,true);F.eq(colored.upgrades,1)
local snapshot=F.C.copy(a);local original=H.onObtainCard;local reached=false
local entropy=require('abyss_external_random');local beforeEntropy=entropy.snapshot()
H.onObtainCard=function(owner,card,def)original(owner,card,def);reached=true;error('AFTER_TOXIC_OBTAIN')end
local ok=Nodes.buyCardSlot(a,3);H.onObtainCard=original
F.eq(ok,false);assert(reached);F.same(a,snapshot);F.same(entropy.snapshot(),beforeEntropy)
assert(Shop.owns(a,'toxic_egg'))
print('TOXIC_EGG_SHOP_PASS initial/restock exact cards/prices/source RNG, private once upgrades/CeramicFish, old shelf unchanged then obtain upgrade, late purchase rollback')
