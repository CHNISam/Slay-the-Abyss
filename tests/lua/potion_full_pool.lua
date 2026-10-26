package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,R,P,Shop,Random,Data=require('abyss_run'),require('abyss_sts_random'),require('abyss_potion_rewards'),require('abyss_shop'),require('abyss_potion_random'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local r=Run.new(Data,42);local stock=Shop.prepare(r);local owner=Random.new(r.runSeed)
for i=1,3 do local d=Random.sample(owner);eq(stock.potions[i].id,d.id);eq(stock.potions[i].rarity,d.rarity);eq(stock.potions[i].unavailable,false)end
same(R.snapshot(stock.shopRng.potion),R.snapshot(owner.potionRng))
local seen={};local successes=0
-- Complete live production drop adapter vs independent full-pool draw owner.
-- No seed injection or reroll is used to claim these as actual map play.
for _=1,1000 do
 local expected=R.cloneState(owner.potionRng);local modifier=r.potionChanceModifier or 0
 local dropped=R.randomInt(expected,99)<40+modifier
 local selected=dropped and Random.sample({potionRng=expected})or nil
 r.shopRng={potion=R.cloneState(owner.potionRng),merchant=R.fromSeed('42')}
 local offer,nextRng,nextModifier=P.prepare(r,2)
 eq(offer~=nil,dropped);eq(nextModifier,modifier+(dropped and -10 or 10))
 if offer then eq(offer.id,selected.id);eq(offer.rarity,selected.rarity);eq(offer.unavailable,false);seen[offer.id]=true;successes=successes+1 end
 same(R.snapshot(nextRng),R.snapshot(expected));P.commit(r,nextRng,nextModifier);owner.potionRng=expected
end
for _,d in ipairs(Random.pool())do assert(seen[d.id],'unreachable production potion '..d.id)end
-- Guaranteed drops still consume their chance draw, before source sampling.
r.relics[#r.relics+1]='white_beast_statue';r.potionChanceModifier=-100
local p,rng,mod=P.prepare(r,2);assert(p);eq(mod,-110)
local q,blocked,nextmod=P.prepare(r,4);eq(q,nil);eq(nextmod,-90);eq(blocked.counter,r.shopRng.potion.counter+1)
print('LUA_POTION_FULL_POOL_PASS 33 '..successes)
