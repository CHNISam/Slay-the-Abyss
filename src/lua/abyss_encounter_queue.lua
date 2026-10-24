-- Source-name Exordium queues. Not wired to Run until every content binding is legal.
-- Fixed source: aeubanks/sts@319009d5, Exordium / AbstractDungeon / MonsterInfo.
-- Uses the production STS wrapper, preserving the raw signed64 decimal seed.
local R = require("abyss_sts_random")
local M = {}
local weak = {{"Cultist",2},{"Jaw Worm",2},{"2 Louse",2},{"Small Slimes",2}}
local strong = {{"Blue Slaver",2},{"Gremlin Gang",1},{"Looter",2},{"Large Slime",2},
    {"Lots of Slimes",1},{"Exordium Thugs",1.5},{"Exordium Wildlife",1.5},
    {"Red Slaver",1},{"3 Louse",2},{"2 Fungi Beasts",2}}
local elite = {{"Gremlin Nob",1},{"Lagavulin",1},{"3 Sentries",1}}
local exclusions = {Looter={"Exordium Thugs"},["Blue Slaver"]={"Red Slaver","Exordium Thugs"},
    ["2 Louse"]={"3 Louse"},["Small Slimes"]={"Large Slime","Lots of Slimes"}}
local function copy(t)
    if type(t) ~= "table" then return t end
    local c={};for k,v in pairs(t)do c[k]=copy(v)end;return c
end
local function normalize(items)
    local sorted={}
    for _,item in ipairs(items)do
        local at=#sorted+1
        while at>1 and item[2]<sorted[at-1][2]do sorted[at]=sorted[at-1];at=at-1 end
        sorted[at]={item[1],item[2]}
    end
    local total=0
    for _,item in ipairs(sorted)do total=R.float32(total+item[2])end
    for _,item in ipairs(sorted)do item[2]=R.float32(item[2]/total)end
    return sorted
end
local pools={weak=normalize(weak),strong=normalize(strong),elite=normalize(elite)}
local normalNames,eliteNames,weakNames,strongNames={},{},{},{}
for _,items in ipairs({weak,strong})do for _,item in ipairs(items)do normalNames[item[1]]=true end end
for _,item in ipairs(elite)do eliteNames[item[1]]=true end
for _,item in ipairs(weak)do weakNames[item[1]]=true end
for _,item in ipairs(strong)do strongNames[item[1]]=true end
local function roll(rng,pool)
    local value=R.randomFloat(rng)
    assert(type(value)=="number" and value>=0 and value<1,"invalid monster RNG float")
    local threshold=0
    for _,item in ipairs(pool)do
        threshold=R.float32(threshold+item[2])
        if value<threshold then return item[1]end
    end
    error("monster pool returned source ERROR sentinel")
end
local function contains(list,value)
    for _,v in ipairs(list or {})do if v==value then return true end end
    return false
end
local function populate(rng,list,pool,count,window)
    local accepted=0
    while accepted<count do
        local name=roll(rng,pool)
        local repeated=false
        for i=math.max(1,#list-window+1),#list do if list[i]==name then repeated=true end end
        if not repeated then list[#list+1]=name;accepted=accepted+1 end
    end
end
local function plain(t,keys)
    assert(type(t)=="table" and getmetatable(t)==nil,"expected plain encounter table")
    for k in pairs(t)do assert(keys[k],"unexpected encounter field")end
end
local function queue(list,names,maximum)
    assert(type(list)=="table" and getmetatable(list)==nil,"expected plain encounter queue")
    local length,count=#list,0
    assert(length<=maximum,"encounter queue too long")
    for k,v in pairs(list)do
        assert(type(k)=="number" and k%1==0 and k>=1 and k<=length and names[v],"invalid encounter queue entry")
        count=count+1
    end
    assert(count==length,"sparse encounter queue")
end
local function validate(s)
    plain(s,{version=true,rawSeed=true,normal=true,elite=true,monsterRng=true})
    assert(s.version==1,"unsupported encounter queue version")
    R.fromSeed(s.rawSeed) -- Canonical signed64 validation; never tonumber or truncate.
    queue(s.normal,normalNames,16);queue(s.elite,eliteNames,10)
    local weakCount=math.max(0,#s.normal-13)
    for i,name in ipairs(s.normal)do
        assert((i<=weakCount and weakNames[name])or(i>weakCount and strongNames[name]),"invalid weak/strong queue boundary")
        assert(name~=s.normal[i-1] and name~=s.normal[i-2],"repeated normal queue entry")
    end
    if weakCount>0 then
        assert(not contains(exclusions[s.normal[weakCount]],s.normal[weakCount+1]),"invalid first strong boundary")
    end
    for i,name in ipairs(s.elite)do assert(name~=s.elite[i-1],"repeated elite queue entry")end
    local rng=R.snapshot(s.monsterRng)
    assert(rng.words[1]~="0000000000000000" or rng.words[2]~="0000000000000000","invalid zero monster RNG")
end
function M.new(rawSeed)
    local s={version=1,rawSeed=rawSeed,normal={},elite={},monsterRng=R.fromSeed(rawSeed)}
    populate(s.monsterRng,s.normal,pools.weak,3,2)
    -- This first strong draw uses only Exordium's boundary exclusions. Later
    -- strong draws use the ordinary two-entry repeat window.
    local forbidden=exclusions[s.normal[#s.normal]]
    local name=roll(s.monsterRng,pools.strong)
    while contains(forbidden,name)do name=roll(s.monsterRng,pools.strong)end
    s.normal[#s.normal+1]=name
    populate(s.monsterRng,s.normal,pools.strong,12,2)
    populate(s.monsterRng,s.elite,pools.elite,10,1)
    return s
end
function M.snapshot(s)
    validate(s)
    return {version=1,rawSeed=s.rawSeed,normal=copy(s.normal),elite=copy(s.elite),monsterRng=R.snapshot(s.monsterRng)}
end
function M.restore(snap)
    plain(snap,{version=true,rawSeed=true,normal=true,elite=true,monsterRng=true})
    assert(snap.version==1,"unsupported encounter queue version")
    queue(snap.normal,normalNames,16);queue(snap.elite,eliteNames,10)
    local s={version=1,rawSeed=snap.rawSeed,normal=copy(snap.normal),elite=copy(snap.elite),
        monsterRng=R.restore(snap.monsterRng)}
    validate(s);return s
end
function M.clone(s)return M.restore(M.snapshot(s))end
local function prepare(s,tier)
    if tier~="normal" and tier~="elite" then return nil,"invalid_encounter_tier" end
    local nextState=M.clone(s)
    if #nextState[tier]==0 then
        -- The pinned Exordium strong-refill path dereferences an empty tail in
        -- generateExclusions. Normal Act 1 has <=13 ordinary rooms and 16 ready
        -- entries; reject exhaustion rather than inventing a new refill rule.
        if tier=="normal" then return nil,"normal_queue_exhausted" end
        populate(nextState.monsterRng,nextState.elite,pools.elite,10,1)
    end
    return nextState
end
function M.peek(s,tier)
    validate(s)
    if tier~="normal" and tier~="elite" then return nil,"invalid_encounter_tier" end
    if #s[tier]>0 then return s[tier][1]end
    local prepared,reason=prepare(s,tier)
    if not prepared then return nil,reason end
    return prepared[tier][1]
end
-- Pure staging: the caller commits the returned replacement only after room
-- setup succeeds. Neither rejected requests nor thrown RNG/setup calls mutate s.
function M.consume(s,tier)
    validate(s)
    local nextState,reason=prepare(s,tier)
    if not nextState then return nil,nil,reason end
    return table.remove(nextState[tier],1),nextState
end
function M.rules()
    return {weak=copy(weak),strong=copy(strong),elite=copy(elite),exclusions=copy(exclusions),normalized=copy(pools)}
end
return M
