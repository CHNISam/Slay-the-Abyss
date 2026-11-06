-- A bounded complete CardPool trace; no replacement RNG or new graph observer.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,D,P,R=require('abyss_run'),require('abyss_data'),require('abyss_card_pool'),require('abyss_sts_random')
local function eq(a,b,label)assert(a==b,'[RELIC_QUERY_REWARDS] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function snapshot(rng)
 local s=R.snapshot(rng);return table.concat(s.words,',')..':'..s.counter
end
local profiles={{},{'Question Card'},{'Busted Crown'},{'Question Card','Busted Crown'},
 {'PrismaticShard'},{'PrismaticShard','Question Card','Busted Crown'}}
local cases,draws=0,0
for _,character in ipairs({'ironclad','silent','defect','watcher'})do
 local run=Run.new(D,'42',{experimental=true,character=character})
 local pools=P.prismaticPools(run)
 eq(#pools.common,76,'Prismatic common pool');eq(#pools.uncommon,160);eq(#pools.rare,84)
 for _,tier in ipairs({'common','uncommon','rare'})do print('RELIC_QUERY_POOL '..character..' '..tier..' '..table.concat(pools[tier],','))end
 for profile,relics in ipairs(profiles)do
  for _,spec in ipairs({{act=1,tier='normal'},{act=2,tier='boss'}})do
   local owner={data=run.data,relics=relics,cardRng=R.fromSeed('42'),cardRarityOffset=5,encounterTier=spec.tier,act=spec.act}
   local expected=3+((profile==2 or profile==4 or profile==6)and 1 or 0)-((profile==3 or profile==4 or profile==6)and 2 or 0)
   eq(P.rewardCount(owner),expected,'source reward quantity')
   local initial=owner.cardRng;local before=snapshot(initial);local data=owner.data;local held=owner.relics
   local label=character..'/'..profile..'/'..spec.tier;local count=0
   local methods={'randomInt','randomLongHex','randomBooleanChance'};local original={}
   for _,method in ipairs(methods)do
    original[method]=R[method];local key=method
    R[key]=function(rng,...)
     local start=snapshot(rng);local args=table.pack(...);local value=original[key](rng,table.unpack(args,1,args.n))
     count=count+1;draws=draws+1
     print('RELIC_QUERY_RNG '..label..' '..count..' '..key..' '..tostring(args[1])..' '..tostring(value)..' '..start..' '..snapshot(rng))
     return value
    end
   end
   local result=table.pack(pcall(P.prepareRewards,owner))
   for _,method in ipairs(methods)do R[method]=original[method]end
   assert(result[1],result[2]);eq(result.n,5,'success and four return values')
   local ids,rng,offset,upgrades=result[2],result[3],result[4],result[5]
   eq(#ids,expected,'returned cards');eq(#upgrades,expected,'returned upgrade flags')
   eq(owner.cardRng,initial,'input stream identity');eq(snapshot(initial),before,'input stream untouched')
   eq(owner.cardRarityOffset,5,'offset not published');eq(owner.data,data);eq(owner.relics,held)
   assert(rng~=initial and rng.primitive~=initial.primitive,'[RELIC_QUERY_REWARDS] returned stream independently cloned')
   assert(ids~=upgrades and ids~=relics,'[RELIC_QUERY_REWARDS] independent result arrays')
   local used,flags={},{};for i,id in ipairs(ids)do assert(not used[id],'[RELIC_QUERY_REWARDS] duplicate reward');used[id]=true;flags[i]=tostring(upgrades[i])end
   print('RELIC_QUERY_RESULT '..label..' '..table.concat(ids,',')..' '..table.concat(flags,',')..' '..offset..' '..snapshot(rng)..' draws='..count..' input='..before..' aliases=fresh-arrays,fresh-stream,shared-data,shared-relics')
   cases=cases+1
  end
 end
end
eq(cases,48,'bounded complete trajectory matrix')
print('RELIC_QUERY_REWARDS_PASS '..cases..' cases '..draws..' RNG boundaries')
