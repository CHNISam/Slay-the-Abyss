package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Copy=require('abyss_copy')
local copy,measuring,allocations,copyCalls=Copy.copy,false,0,0
local function tables(value,seen)
 if type(value)~='table'or seen[value]then return 0 end
 seen[value]=true;local n=1
 for _,v in pairs(value)do n=n+tables(v,seen)end
 return n
end
Copy.copy=function(value,seen)
 if measuring then
  allocations=allocations+tables(value,type(seen)=='table'and seen or {});copyCalls=copyCalls+1
 end
 return copy(value,seen)
end
local C,D=require('abyss_combat'),require('abyss_data')
local Setup,Colorless=require('abyss_combat_enemy_setup'),require('abyss_colorless_cards')
local function same(a,b)
 assert(type(a)==type(b),'catalog value type changed')
 if type(a)~='table'then assert(a==b,'catalog scalar changed');return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'catalog key lost')end
end
local function source(registered)
 local d=C.copy(D)
 if registered then d=Colorless.withCards(d)end
 local shared={marker='caller-owned'}
 local a=C.copy(d.cards.cards[1]);a.id='catalog_alias_a';a.catalogAlias=shared
 local b=C.copy(a);b.id='catalog_alias_b';b.catalogAlias=shared
 d.cards.cards[#d.cards.cards+1]=a;d.cards.cards[#d.cards.cards+1]=b
 local duplicate=C.copy(a);duplicate.name='last duplicate wins';duplicate.catalogAlias=shared
 d.cards.cards[#d.cards.cards+1]=duplicate
 for _,id in ipairs({'catalog_alias_status_a','catalog_alias_status_b'})do
  local status=C.copy(d.statuses.statuses[1]);status.id=id;status.catalogAlias=shared
  d.statuses.statuses[#d.statuses.statuses+1]=status
 end
 local status=C.copy(d.statuses.statuses[#d.statuses.statuses-1]);status.name='last status wins';status.catalogAlias=shared
 d.statuses.statuses[#d.statuses.statuses+1]=status
 for _,enemy in ipairs(d.enemies.enemies)do
  if enemy.id=='cultist'then
   local duplicate=C.copy(enemy);duplicate.name='last enemy wins'
   d.enemies.enemies[#d.enemies.enemies+1]=duplicate;break
  end
 end
 return d,shared
end
local captures={}
local register=Setup.register
Setup.register=function(catalog)
 register(catalog);captures[#captures+1]=catalog
end
for _,registered in ipairs({false,true})do
 local d,shared=source(registered);local before=C.copy(d)
 local options={seed=42,deck={'strike','defend'},enemies={'cultist'},cardRandomSeed='42',shuffleSeed='42'}
 measuring=true;allocations=0;copyCalls=0
 local first=assert(C.new(d,options));local firstAllocations,firstCalls=allocations,copyCalls
 if ABYSS_CATALOG_OBSERVE then ABYSS_CATALOG_OBSERVE('battle-'..tostring(registered),first)end
 measuring=false;local second=assert(C.new(d,options))
 same(d,before)
 local a,b=first.catalog.cards.catalog_alias_a,first.catalog.cards.catalog_alias_b
 assert(a.name=='last duplicate wins' and a.catalogAlias==b.catalogAlias)
 assert(a.catalogAlias~=shared and first.catalog~=second.catalog)
 assert(a.catalogAlias~=second.catalog.cards.catalog_alias_a.catalogAlias)
 assert(first.catalog.cards.swift_strike~=second.catalog.cards.swift_strike)
 assert(first.catalog.cards.swift_strike.effects~=second.catalog.cards.swift_strike.effects)
 first.catalog.cards.swift_strike.effects[1].catalogProbe=true
 assert(not second.catalog.cards.swift_strike.effects[1].catalogProbe)
 assert(first.catalog.statuses.catalog_alias_status_a.catalogAlias==first.catalog.statuses.catalog_alias_status_b.catalogAlias)
 assert(first.catalog.statuses.catalog_alias_status_a.name=='last status wins')
 assert(first.catalog.enemies.cultist.name=='last enemy wins')
 -- Cross-list aliases were never retained: each list is a separate copy root.
 assert(a.catalogAlias~=first.catalog.statuses.catalog_alias_status_a.catalogAlias)
 local potion=d.potions.potions[1];assert(first.catalog.potions[potion.id]==potion)
 first.sourcePools.catalogProbe={};assert(not d.cards.sourcePools.catalogProbe and not second.sourcePools.catalogProbe)
 a.catalogAlias.marker='first battle only';assert(shared.marker=='caller-owned')
 assert(second.catalog.cards.catalog_alias_a.catalogAlias.marker=='caller-owned')
 local run=require('abyss_run').new(D,'42');local streams=require('abyss_run').roomStreams(run,2)
 local room={seed=42,roomSeed=streams.seed,roomStreams=streams,enemies={'cultist'},deck={'strike','defend'}}
 local previous=#captures
 measuring=true;allocations=0;copyCalls=0
 local prepared=C.prepareEncounter(d,room);local preparedAllocations,preparedCalls=allocations,copyCalls
 if ABYSS_CATALOG_OBSERVE then ABYSS_CATALOG_OBSERVE('prepared-'..tostring(registered),prepared)end
 measuring=false;assert(#captures==previous+1)
 local catalog=captures[#captures]
 assert(catalog.cards.catalog_alias_a.name=='last duplicate wins')
 assert(catalog.statuses.catalog_alias_status_a.name=='last status wins' and catalog.enemies.cultist.name=='last enemy wins')
 assert(catalog.cards.catalog_alias_a.catalogAlias==catalog.cards.catalog_alias_b.catalogAlias)
 assert(catalog.cards.catalog_alias_a.catalogAlias~=shared)
 assert(catalog.cards.swift_strike~=second.catalog.cards.swift_strike)
 assert(catalog.potions[potion.id]~=potion);same(catalog.potions[potion.id],potion)
 local normal=assert(C.new(d,room))
 local adopted=assert(C.new(d,{seed=42,roomSeed=streams.seed,roomStreams=streams,
  preparedEncounter=prepared,deck={'strike','defend'}}))
 if ABYSS_CATALOG_OBSERVE then ABYSS_CATALOG_OBSERVE('adopted-'..tostring(registered),adopted)end
 same(normal,adopted)
 assert(adopted.enemies~=prepared.actors and adopted.enemies[1]~=prepared.actors[1])
 same(d,before)
 local ids={};for id in pairs(adopted.catalog.cards)do ids[#ids+1]=id end;table.sort(ids)
 local actor=adopted.enemies[1]
 print('CATALOG_TRACE '..table.concat({tostring(registered),table.concat(ids,','),actor.id,actor.hp,
  actor.intents[actor.intentIndex].id,adopted.nextUid,adopted.cardRandomRng.counter,
  adopted.shuffleRng.counter,adopted.aiRng.counter,adopted.monsterHpRng.counter},'|'))
 print('CATALOG_COPY_ALLOCATIONS '..tostring(registered)..'|'..firstAllocations..'|'..preparedAllocations..'|'..firstCalls..'|'..preparedCalls)
 if ABYSS_CATALOG_PROFILE then
  local started=os.clock()
  for _=1,10 do C.prepareEncounter(d,room)end
  print('CATALOG_PREPARE_SECONDS '..tostring(registered)..'|'..(os.clock()-started))
 end
end
Setup.register=register
Copy.copy=copy
print('COMBAT_CATALOG_PASS caller/definition/pool isolation, per-list aliases, duplicate IDs, potion ownership, prepared equality')
