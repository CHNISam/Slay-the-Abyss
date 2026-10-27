-- Source-name Exordium queues owned by Run; accepted room entry commits consume.
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
local later = {
    [2]={weak={{'Spheric Guardian',2},{'Chosen',2},{'Shell Parasite',2},{'3 Byrds',2},{'2 Thieves',2}},
        strong={{'Chosen and Byrds',2},{'Sentry and Sphere',2},{'Snake Plant',6},{'Snecko',4},
            {'Centurion and Healer',6},{'Cultist and Chosen',3},{'3 Cultists',3},{'Shelled Parasite and Fungi',3}},
        elite={{'Gremlin Leader',1},{'Slavers',1},{'Book of Stabbing',1}},
        exclusions={['Spheric Guardian']={'Sentry and Sphere'},['3 Byrds']={'Chosen and Byrds'},
            Chosen={'Chosen and Byrds','Cultist and Chosen'}},weakCount=2},
    [3]={weak={{'3 Darklings',2},{'Orb Walker',2},{'3 Shapes',2}},
        strong={{'Spire Growth',1},{'Transient',1},{'4 Shapes',1},{'Maw',1},{'Sphere and 2 Shapes',1},
            {'Jaw Worm Horde',1},{'3 Darklings',1},{'Writhing Mass',1}},
        elite={{'Giant Head',2},{'Nemesis',2},{'Reptomancer',2}},
        exclusions={['3 Darklings']={'3 Darklings'},['Orb Walker']={'Orb Walker'},['3 Shapes']={'4 Shapes'}},weakCount=2},
    [4]={weak={},strong={},elite={{'Shield and Spear',1}},exclusions={},weakCount=0},
}
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
local function settings(act)
    local rules=act==1 and {weak=weak,strong=strong,elite=elite,exclusions=exclusions,weakCount=3} or later[act]
    assert(rules,'invalid encounter act')
    return rules
end
local function names(items)
    local result={};for _,item in ipairs(items)do result[item[1]]=true end;return result
end
local function poolsFor(act)
    local r=settings(act)
    return {weak=normalize(r.weak),strong=normalize(r.strong),elite=normalize(r.elite)}
end
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
local function queue(list,allowedNames,maximum)
    assert(type(list)=="table" and getmetatable(list)==nil,"expected plain encounter queue")
    local length,count=#list,0
    assert(length<=maximum,"encounter queue too long")
    for k,v in pairs(list)do
        assert(type(k)=="number" and k%1==0 and k>=1 and k<=length and allowedNames[v],"invalid encounter queue entry")
        count=count+1
    end
    assert(count==length,"sparse encounter queue")
end
local function validate(s)
    plain(s,{version=true,act=true,rawSeed=true,normal=true,elite=true,monsterRng=true})
    assert((s.version==1 and s.act==nil) or (s.version==2 and type(s.act)=='number' and s.act>=2 and s.act<=4 and s.act%1==0),"unsupported encounter queue version")
    local act=s.act or 1
    local rules=settings(act)
    local weakNames,strongNames,eliteNames=names(rules.weak),names(rules.strong),names(rules.elite)
    local normalNames=names(rules.weak);for name in pairs(strongNames)do normalNames[name]=true end
    if act==4 then normalNames['Shield and Spear'],strongNames['Shield and Spear']=true,true end
    R.fromSeed(s.rawSeed) -- Canonical signed64 validation; never tonumber or truncate.
    queue(s.normal,normalNames,act==4 and 3 or rules.weakCount+13);queue(s.elite,eliteNames,act==4 and 3 or 10)
    local weakCount=math.max(0,#s.normal-13)
    for i,name in ipairs(s.normal)do
        assert((i<=weakCount and weakNames[name])or(i>weakCount and strongNames[name]),"invalid weak/strong queue boundary")
        -- The first strong draw has only the chapter exclusion list. In Act3
        -- it can legally repeat the first weak Darklings (source seed 10).
        assert(act==4 or i==weakCount+1 or (name~=s.normal[i-1] and name~=s.normal[i-2]),"repeated normal queue entry")
    end
    if weakCount>0 then
        assert(not contains(rules.exclusions[s.normal[weakCount]],s.normal[weakCount+1]),"invalid first strong boundary")
    end
    for i,name in ipairs(s.elite)do assert(act==4 or name~=s.elite[i-1],"repeated elite queue entry")end
    local rng=R.snapshot(s.monsterRng)
    assert(rng.words[1]~="0000000000000000" or rng.words[2]~="0000000000000000","invalid zero monster RNG")
end
function M.new(rawSeed,act,monsterRng)
    if act==nil then act=1 end
    local rules,pools=settings(act),poolsFor(act)
    R.fromSeed(rawSeed)
    local s={version=act==1 and 1 or 2,rawSeed=rawSeed,normal={},elite={},
        monsterRng=monsterRng and R.cloneState(monsterRng) or R.fromSeed(rawSeed)}
    if act~=1 then s.act=act end
    if act==4 then
        s.normal={'Shield and Spear','Shield and Spear','Shield and Spear'}
        s.elite={'Shield and Spear','Shield and Spear','Shield and Spear'}
        return s
    end
    populate(s.monsterRng,s.normal,pools.weak,rules.weakCount,2)
    local forbidden=rules.exclusions[s.normal[#s.normal]]
    local name=roll(s.monsterRng,pools.strong)
    while contains(forbidden,name)do name=roll(s.monsterRng,pools.strong)end
    s.normal[#s.normal+1]=name
    populate(s.monsterRng,s.normal,pools.strong,12,2)
    populate(s.monsterRng,s.elite,pools.elite,10,1)
    return s
end
function M.snapshot(s)
    validate(s)
    return {version=s.version,act=s.act,rawSeed=s.rawSeed,normal=copy(s.normal),elite=copy(s.elite),monsterRng=R.snapshot(s.monsterRng)}
end
function M.restore(snap)
    plain(snap,{version=true,act=true,rawSeed=true,normal=true,elite=true,monsterRng=true})
    local s={version=snap.version,act=snap.act,rawSeed=snap.rawSeed,normal=copy(snap.normal),elite=copy(snap.elite),
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
        if s.act==4 then return nil,"elite_queue_exhausted" end
        populate(nextState.monsterRng,nextState.elite,poolsFor(s.act or 1).elite,10,1)
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
function M.rules(act)
    if act==nil then act=1 end
    local r=settings(act)
    if act==4 then return {weak={},strong={},elite={},exclusions={},normalized={},
        fixedNormal={'Shield and Spear','Shield and Spear','Shield and Spear'},
        fixedElite={'Shield and Spear','Shield and Spear','Shield and Spear'}} end
    return {weak=copy(r.weak),strong=copy(r.strong),elite=copy(r.elite),exclusions=copy(r.exclusions),normalized=poolsFor(act)}
end
-- Initializes after encounter queues, sharing the persistent monsterRng owner.
-- The returned queue is staged; failed room/transition setup commits no draws.
function M.initializeBoss(s,seen)
    local nextState=M.clone(s)
    local act=s.act or 1
    if act==1 then
        seen=seen or {};assert(type(seen)=='table','invalid boss history')
        if not seen.GUARDIAN then return {profile='guardian-unseen',bossList={'The Guardian','The Guardian'}},nextState end
        if not seen.GHOST then return {profile='source-history',bossList={'Hexaghost','Hexaghost'}},nextState end
        if not seen.SLIME then return {profile='source-history',bossList={'Slime Boss','Slime Boss'}},nextState end
        local list={'The Guardian','Hexaghost','Slime Boss'}
        R.shuffle(nextState.monsterRng,list)
        return {profile='source-unlocked',bossList=list},nextState
    end
    if act==4 then return {profile='ending',bossList={'The Heart','The Heart','The Heart'}},nextState end
    seen=seen or {}
    assert(type(seen)=='table','invalid boss history')
    local order=act==2 and {{'CHAMP','Champ'},{'AUTOMATON','Automaton'},{'COLLECTOR','Collector'}}
        or {{'CROW','Awakened One'},{'DONUT','Donu and Deca'},{'WIZARD','Time Eater'}}
    for _,entry in ipairs(order)do
        if not seen[entry[1]] then return {profile='source-history',bossList={entry[2],entry[2]}},nextState end
    end
    local list=act==2 and {'Automaton','Collector','Champ'} or {'Awakened One','Time Eater','Donu and Deca'}
    R.shuffle(nextState.monsterRng,list)
    return {profile='source-unlocked',bossList=list},nextState
end
return M
