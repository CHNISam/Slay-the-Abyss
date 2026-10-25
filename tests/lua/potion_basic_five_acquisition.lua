package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local P,Shop=require('abyss_potion_rewards'),require('abyss_shop')
local Data=require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'unexpected '..tostring(k)) end
end
local function test(name,fn) fn();print('ok basic five acquisition - '..name) end
test('pending acquisition keeps every old shop/drop result and RNG trajectory unchanged; clearing it admits five',function()
 local old=C.copy(Data);old.potions.potions={}
 for _,p in ipairs(Data.potions.potions) do if not p.acquisitionPending then old.potions.potions[#old.potions.potions+1]=p end end
 local admitted=C.copy(Data)
 for _,p in ipairs(admitted.potions.potions) do p.acquisitionPending=nil end
 local seen={};local changedShop,changedDrop=false,false
 local before,after,active=Run.new(old,0),Run.new(Data,0),Run.new(admitted,0)
 for seed=0,15 do
  -- Reuse the three real Run owners; this isolated selector sweep resets only
  -- their acquisition streams, avoiding unrelated encounter initialization.
  for _,run in ipairs({before,after,active}) do
   run.seed=seed;run.eventSeed=tostring(seed);run.shopRng=nil;run.potionChanceModifier=0
  end
  same(Shop.prepare(before),Shop.prepare(after))
  for _=1,12 do
   local x,xr,xm=P.prepare(before,2);local y,yr,ym=P.prepare(after,2)
   same(x,y);same(xr,yr);eq(xm,ym);P.commit(before,xr,xm);P.commit(after,yr,ym)
  end
  local stock=Shop.prepare(active)
  for _,offer in ipairs(stock.potions) do
   for _,p in ipairs(Data.potions.potions) do if p.id==offer.id and p.acquisitionPending then seen[p.id]=true;changedShop=true end end
  end
  for _=1,12 do
   local p,r,m=P.prepare(active,2);P.commit(active,r,m)
   if p then for _,d in ipairs(Data.potions.potions) do if p.id==d.id and d.acquisitionPending then seen[p.id]=true;changedDrop=true end end end
  end
 end
 assert(changedShop and changedDrop)
 for _,id in ipairs({'swift_potion','weak_potion','fear_potion','ancient_potion','liquid_bronze'}) do assert(seen[id],id) end
end)
print('LUA_POTION_BASIC_FIVE_ACQUISITION_PASS 1')
