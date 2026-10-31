local Q=require('abyss_encounter_queue')
local A2=require('abyss_act2_enemies')
local function json(value)
    if type(value)=='nil' then return 'null' end
    if type(value)=='boolean' or type(value)=='number' then return tostring(value) end
    if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
        return c=='"' and '\\"' or c=='\\' and '\\\\' or string.format('\\u%04x',string.byte(c)) end)..'"' end
    local keys,n,array={},0,true
    for k in pairs(value) do keys[#keys+1]=k;n=n+1;if type(k)~='number' then array=false end end
    local result={}
    if array and #value==n then for _,v in ipairs(value) do result[#result+1]=json(v) end
        return '['..table.concat(result,',')..']' end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do result[#result+1]=json(tostring(k))..':'..json(value[k]) end
    return '{'..table.concat(result,',')..'}'
end


local result={act=2,queueSources={},bosses={},enemyDefinitions={},platform='NOT_RUN',naturalPerItem='NOT_COMPLETE'}
for _,pool in ipairs({'weak','strong','elite'})do
 for _,entry in ipairs(Q.rules(2)[pool])do
  local tier=pool=='elite'and'elite'or'normal'
  local binding=assert(A2.resolve(entry[1],tier))
  result.queueSources[#result.queueSources+1]={source=entry[1],weight=entry[2],pool=pool,id=binding.id,
   enemies=binding.enemies,dynamic=binding.sourceEncounter~=nil,entry='Run.startRoomCombat -> abyss_act2_enemies.resolve'}
 end
end
for _,source in ipairs({'Champ','Collector','Automaton'})do
 local b=assert(A2.resolve(source,'boss'));result.bosses[#result.bosses+1]={source=source,id=b.id,enemies=b.enemies,
  entry='Run.startRoomCombat -> abyss_act2_enemies.resolve',acquisition='history-qualified boss queue; fresh competition defaults Champ',platform='NOT_RUN'}
end
for _,d in ipairs(A2.enemies)do result.enemyDefinitions[#result.enemyDefinitions+1]={id=d.id,tier=d.tier,source='src/lua/abyss_act2_enemies.lua',implemented=true}end
for _,d in ipairs(require('abyss_event_combat_enemies').enemies)do
 if d.id=='bandit_pointy'or d.id=='bandit_leader'or d.id=='bandit_bear'then
 result.enemyDefinitions[#result.enemyDefinitions+1]={id=d.id,tier=d.tier,source='src/lua/abyss_event_combat_enemies.lua',implemented=true,channel='event:masked_bandits:fight'}end
end
local act1Bosses={}
for _,source in ipairs({'The Guardian','Hexaghost','Slime Boss'})do
 local b=assert(require('abyss_act1_bosses').resolve(source,'boss'))
 act1Bosses[#act1Bosses+1]={source=source,id=b.id,enemies=b.enemies,
  definitionSource=source=='The Guardian'and'data/enemies.json'or'src/lua/abyss_act1_bosses.lua',
  acquisition='history-qualified boss queue; fresh competition defaults Guardian',platform='NOT_RUN'}
end
print('M3_CONTENT '..json({act2=result,act1Bosses=act1Bosses}))
