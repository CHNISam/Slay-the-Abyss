package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data,R,P=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_potion_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local n=0
for _,inCombat in ipairs({false,true})do for _,capacity in ipairs({3,5})do
 local r=Run.new(Data,42);if capacity==5 then assert(Run.obtainRelic(r,'Potion Belt'))end
 assert(Run.obtainPotion(r,'block_potion'));assert(Run.obtainPotion(r,'entropic_brew'))
 if inCombat then assert(Run.startCombat(r,'cultist_solo'))end
 local expected=P.new(r.runSeed);local ids={}
 for i=1,capacity do ids[i]=P.sample(expected,{limited=inCombat}).id end
 local preview=Run.potionView(r);eq(preview[2].canUse,true);eq(r.shopRng,nil)
 assert(Run.usePotion(r,2));eq(Run.potionCount(r),capacity);eq(r.potions[1],'block_potion')
 for slot=2,capacity do eq(r.potions[slot],ids[slot-1])end
 same(R.snapshot(r.shopRng.potion),R.snapshot(expected.potionRng));eq(Run.potionCount(r),capacity)
 if inCombat then for _,id in ipairs(ids)do assert(id~='fruit_juice')end end
 n=n+1
end end
for _,inCombat in ipairs({false,true})do
 local r=Run.new(Data,42);assert(Run.obtainPotion(r,'entropic_brew'));assert(Run.obtainRelic(r,'sozu'))
 if inCombat then assert(Run.startCombat(r,'cultist_solo'))end
 assert(Run.usePotion(r,1));eq(Run.potionCount(r),0)
 if inCombat then assert(r.shopRng.potion.counter>0)else eq(r.shopRng,nil)end
 n=n+1
end
local r=Run.new(Data,42);assert(Run.obtainPotion(r,'entropic_brew'));r.phase='node';r.nodeFlow={event={id='WeMeetAgain'}}
eq(Run.usePotion(r,1),false);eq(r.shopRng,nil);eq(r.potions[1],'entropic_brew');n=n+1
print('LUA_POTION_ENTROPIC_PASS '..n)
