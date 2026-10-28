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
test('missing definitions preserve source identities and RNG without filtering or replacement',function()
 local old=C.copy(Data);old.potions.potions={}
 local basic={fire_potion=true,block_potion=true,energy_potion=true,strength_potion=true,dexterity_potion=true,regen_potion=true}
 for _,p in ipairs(Data.potions.potions)do if basic[p.id]then old.potions.potions[#old.potions.potions+1]=p end end
 local seen={};local before,after=Run.new(old,0),Run.new(Data,0)
 for seed=0,15 do
  for _,run in ipairs({before,after})do run.seed=seed;run.eventSeed=tostring(seed);run.shopRng=nil;run.potionChanceModifier=0 end
  local x,y=Shop.prepare(before),Shop.prepare(after)
  same(x.shopRng,y.shopRng)
  for i,o in ipairs(y.potions)do eq(x.potions[i].id,o.id);eq(x.potions[i].rarity,o.rarity);eq(o.unavailable,false)end
  for _=1,12 do
   local p,pr,pm=P.prepare(before,2);local q,qr,qm=P.prepare(after,2)
   same(pr,qr);eq(pm,qm);eq(p~=nil,q~=nil)
   if p then eq(p.id,q.id);eq(p.rarity,q.rarity);eq(q.unavailable,false);eq(p.unavailable,not basic[p.id]);seen[q.id]=true end
   P.commit(before,pr,pm);P.commit(after,qr,qm)
  end
 end
 for _,id in ipairs({'swift_potion','weak_potion','fear_potion','ancient_potion','liquid_bronze'})do assert(seen[id],id)end
end)
print('LUA_POTION_BASIC_FIVE_ACQUISITION_PASS 1')
