-- Same-run map navigation only; no platform storage, UI or combat dependencies.
local Rooms = require("abyss_map_rooms")
local Seed = require("abyss_run_seed")
local Acts = require('abyss_acts')
local Emerald = require('abyss_emerald_elite')
local SourceRandom = require('abyss_sts_random')
local M = {}
local equal
local kinds = { "combat", "elite", "camp", "shop", "event", "treasure", "boss" }
-- Actual encounters belong to the Run queue. Optional burning-elite state owns
-- only mapRng selection/boost; restore privately replays that exact stream.

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
end

local function integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
end

local function array(value, limit)
    if type(value) ~= "table" or getmetatable(value)~=nil then return false end
    local length, count = #value, 0
    if length > limit then return false end
    for key in pairs(value) do
        if not integer(key) or key < 1 or key > length then return false end
        count = count + 1
    end
    return count == length
end

local function id(floor, lane) return string.format('f%d_l%d',floor,lane) end

local function configuration(data)
    assert(type(data) == "table" and type(data.rules) == "table" and type(data.rules.map) == "table",
        "missing map rules")
    local rules = data.rules.map
    assert(rules.floors == 17 and rules.generatedRows == 15 and rules.bossFloor == 16
        and rules.bossTreasureFloor == 17 and rules.restFloor == 15 and rules.treasureFloor == 9,
        "map requires 15 generated rows, treasure 9, camp 15, Boss 16 and Boss treasure 17")
    assert(array(rules.nodeTypes, 7) and #rules.nodeTypes == 7, "map requires seven node types")
    local seen = {}
    for _, kind in ipairs(rules.nodeTypes) do
        assert(type(kind) == "string" and not seen[kind], "duplicate or invalid node type")
        seen[kind] = true
    end
    for _, kind in ipairs(kinds) do assert(seen[kind], "missing node type " .. kind) end
    assert(type(data.enemies) == "table" and array(data.enemies.encounters, 10000), "missing encounters")
    local encounters, ids = {}, {}
    for _, entry in ipairs(data.enemies.encounters) do
        assert(type(entry) == "table" and type(entry.id) == "string" and entry.id:match("^[a-z][a-z0-9_]*$")
            and not ids[entry.id], "invalid or duplicate encounter id")
        assert(entry.tier == "normal" or entry.tier == "elite" or entry.tier == "boss", "invalid encounter tier")
        assert(integer(entry.minFloor) and integer(entry.maxFloor) and entry.minFloor >= 1
            and entry.maxFloor <= 16 and entry.minFloor <= entry.maxFloor, "invalid encounter floor range")
        ids[entry.id] = true
        encounters[#encounters + 1] = { id = entry.id, tier = entry.tier,
            minFloor = entry.minFloor, maxFloor = entry.maxFloor }
    end
    table.sort(encounters, function(a, b) return a.id < b.id end)
    local signature = { "map-v3:sts-a0-319009d5:15x7x6:boss16:chest17:run-source-queue-v1" }
    for _, entry in ipairs(encounters) do
        signature[#signature + 1] = entry.id .. ":" .. entry.tier .. ":" .. entry.minFloor .. ":" .. entry.maxFloor
    end
    return encounters, table.concat(signature, "|")
end

local function emeraldContext(context)
    if context==nil then return end
    assert(type(context)=='table' and getmetatable(context)==nil
        and type(context.endingUnlocked)=='boolean' and type(context.emeraldOwned)=='boolean',
        'invalid trusted emerald context')
    for key in pairs(context)do
        assert(key=='endingUnlocked' or key=='emeraldOwned','unexpected trusted emerald context field')
    end
end

local function markEmerald(map,context)
    if not context or not context.endingUnlocked or context.emeraldOwned then return end
    local selection,rng,reason=Emerald.select(map,SourceRandom.restore(map.randomState),context)
    assert(selection,reason)
    map.emeraldSelection,map.mapRng=selection,SourceRandom.snapshot(rng)
    for _,node in ipairs(map.nodes)do if node.id==selection.nodeId then node.hasEmeraldKey=true end end
end

function M.generate(data, seed, act, trustedContext)
    emeraldContext(trustedContext)
    if act==nil then act=1 end
    local chapter=Acts.get(act)
    local _, signature = configuration(data)
    local runSeed=Seed.normalize(seed)
    if act==4 then
        local map={version=4,act=4,firstFloor=52,terminalFloor=55,seed=runSeed,runSeed=runSeed,
            mapSeed=Acts.mapSeed(runSeed,4),sourceSignature='map-v4:sts-a0-319009d5:TheEnding:fixed-52-55:'..signature,
            floor=51,path={},nodes={}}
        for row,kind in ipairs({'camp','shop','elite','boss'}) do
            local floor=51+row
            map.nodes[row]={id=id(floor,4),floor=floor,localFloor=row,lane=4,type=kind,
                nextIds=row<4 and {id(floor+1,4)} or {}}
        end
        return map
    end
    local generated=Rooms.generate(runSeed,act)
    local offset=chapter.first-1
    if act~=1 then signature='map-v4:sts-a0-319009d5:'..chapter.id..':'..signature end
    -- seed preserves the Nodes map-identity ABI; both identities are immutable
    -- raw run strings. mapSeed is the distinct raw+actNum source RNG seed.
    local map = { version = 3, seed = runSeed, runSeed=runSeed, mapSeed=generated.mapSeed,
        topologyState=copy(generated.topologyState),randomState=copy(generated.randomState),
        sourceSignature = signature,
        floor = 0, path = {}, nodes = {} }
    if act~=1 then
        map.version,map.act,map.firstFloor,map.terminalFloor=4,act,chapter.first,chapter.last
        map.floor=offset
    end
    for _,source in ipairs(generated.nodes)do
        local row=source.y+1
        local node={id=id(offset+row,source.x+1),floor=offset+row,lane=source.x+1,type=source.type,nextIds={}}
        if act~=1 then node.localFloor=row end
        map.nodes[#map.nodes+1]=node
    end
    local boss={id=id(chapter.boss,4),floor=chapter.boss,lane=4,type='boss',nextIds={id(chapter.last,4)}}
    local terminal={id=id(chapter.last,4),floor=chapter.last,lane=4,
        type=act==3 and 'event' or 'treasure',roomKind=chapter.terminal,nextIds={}}
    if act~=1 then boss.localFloor,terminal.localFloor=16,17 end
    map.nodes[#map.nodes+1],map.nodes[#map.nodes+2]=boss,terminal
    local nodesById={};for _,node in ipairs(map.nodes)do nodesById[node.id]=node end
    for _,edge in ipairs(generated.edges)do
        local source=assert(nodesById[id(offset+edge.src_y+1,edge.src_x+1)])
        source.nextIds[#source.nextIds+1]=id(offset+edge.dst_y+1,edge.dst_x+1)
    end
    for _,node in ipairs(map.nodes)do
        if node.floor==chapter.camp then node.nextIds={id(chapter.boss,4)}end
    end
    markEmerald(map,trustedContext)
    return map
end

local function index(map)
    local result = {}; for _, node in ipairs(map.nodes) do result[node.id] = node end; return result
end

function M.available(map)
    if map.floor == (map.terminalFloor or 17) then return {} end
    local nodes, result = index(map), {}
    if map.floor == (map.firstFloor or 1)-1 then
        for _, node in ipairs(map.nodes) do if node.floor == (map.firstFloor or 1) then result[#result + 1] = copy(node) end end
    else
        for _, nextId in ipairs(nodes[map.currentNodeId].nextIds) do result[#result + 1] = copy(nodes[nextId]) end
    end
    return result
end

function M.choose(map, nodeId)
    if map.floor == (map.terminalFloor or 17) then return false, "map_complete" end
    if type(nodeId) ~= "string" or not index(map)[nodeId] then return false, "invalid_node" end
    for _, node in ipairs(M.available(map)) do
        if node.id == nodeId then
            map.floor, map.currentNodeId = node.floor, node.id
            map.path[#map.path + 1] = node.id
            return true
        end
    end
    return false, "node_unavailable"
end

local function emeraldNode(map,nodeId)
    if type(map)~='table' or getmetatable(map)~=nil or map.emeraldBoost~=nil
        or not array(map.nodes,107) or type(map.emeraldSelection)~='table' then return end
    local selection,found=map.emeraldSelection,nil
    local act=map.act
    if act==nil then act=1 end
    if getmetatable(selection)~=nil or selection.version~=1 or not integer(selection.act)
        or selection.act<1 or selection.act>3 or not integer(selection.x) or not integer(selection.y)
        or selection.x<0 or selection.x>6 or selection.y<0 or selection.y>14
        or nodeId~=selection.nodeId or selection.act~=act
        or type(map.runSeed)~='string' or map.seed~=map.runSeed
        or type(map.sourceSignature)~='string' or map.sourceSignature=='' then return end
    local ok,mapSeed=pcall(Acts.mapSeed,map.runSeed,selection.act)
    if not ok or map.mapSeed~=mapSeed then return end
    for _,node in ipairs(map.nodes)do
        if type(node)~='table' then return end
        if node.hasEmeraldKey~=nil and (node.hasEmeraldKey~=true or node.id~=nodeId) then return end
        if node.id==nodeId then
            if found or node.type~='elite' or node.hasEmeraldKey~=true
                or node.lane~=selection.x+1 or node.floor~=(map.firstFloor or 1)+selection.y then return end
            found=node
        end
    end
    return found
end

local function prepareEmerald(map,nodeId)
    local node=emeraldNode(map,nodeId)
    if not node then return nil,nil,'invalid_emerald_map_owner' end
    local ok,rng=pcall(SourceRandom.restore,map.mapRng)
    if not ok then return nil,nil,'invalid_map_rng' end
    local effect,nextRng,reason=Emerald.prepare(map.emeraldSelection,rng)
    if not effect then return nil,nil,reason end
    local after=SourceRandom.snapshot(nextRng)
    return {version=1,runSeed=map.runSeed,mapSeed=map.mapSeed,mapSignature=map.sourceSignature,
        nodeId=nodeId,beforeRng=copy(map.mapRng),afterRng=copy(after),effect=effect},after
end

function M.prepareEmeraldBoost(map,nodeId)
    if not emeraldNode(map,nodeId) then return nil,nil,'invalid_emerald_map_owner' end
    local ok,available=pcall(M.available,map)
    if ok then
        for _,node in ipairs(available)do if node.id==nodeId then return prepareEmerald(map,nodeId) end end
    end
    return nil,nil,'emerald_node_unavailable'
end

function M.commitEmeraldBoost(map,nodeId,boost)
    local expected,nextRng,reason=prepareEmerald(map,nodeId)
    if not expected then return false,reason end
    local node=emeraldNode(map,nodeId)
    if map.currentNodeId~=nodeId or map.floor~=node.floor or not array(map.path,17)
        or map.path[#map.path]~=nodeId then return false,'emerald_node_not_chosen' end
    if not equal(boost,expected) then return false,'emerald_boost_owner_mismatch' end
    map.emeraldBoost,map.mapRng=copy(expected),copy(nextRng)
    return true
end

function M.snapshot(map) return copy(map) end

function M.view(map)
    local view, visited, available = copy(map), {}, {}
    for _, nodeId in ipairs(map.path) do visited[nodeId] = true end
    for _, node in ipairs(M.available(map)) do available[node.id] = true end
    for _, node in ipairs(view.nodes) do
        node.visited, node.available = visited[node.id] == true, available[node.id] == true
    end
    view.complete = map.floor == (map.terminalFloor or 17)
    return view
end

-- The expected graph is bounded and acyclic, so malformed cyclic input also terminates.
equal = function(actual, expected)
    if type(actual) ~= type(expected) then return false end
    if type(expected) ~= "table" then return actual == expected end
    if getmetatable(actual)~=nil then return false end
    for key, value in pairs(expected) do if not equal(actual[key], value) then return false end end
    for key in pairs(actual) do if expected[key] == nil then return false end end
    return true
end

-- Strict same-run restoration: regenerate the source graph, then replay legal choices.
-- Returns an independent state or nil/reason; never mutates the supplied snapshot/data.
function M.restore(data, snapshot, trustedContext)
    if type(snapshot) ~= "table" or getmetatable(snapshot)~=nil or (snapshot.version ~= 3 and snapshot.version ~= 4)
        or type(snapshot.runSeed)~='string' or not array(snapshot.path, 17) then
        return nil, "invalid_snapshot"
    end
    local ok, map = pcall(M.generate, data, snapshot.runSeed, snapshot.version==4 and snapshot.act or 1,trustedContext)
    if not ok then return nil, "invalid_configuration" end
    if snapshot.sourceSignature ~= map.sourceSignature then return nil, "configuration_mismatch" end
    for _, nodeId in ipairs(snapshot.path) do
        local boost
        if map.emeraldSelection and nodeId==map.emeraldSelection.nodeId then
            boost=M.prepareEmeraldBoost(map,nodeId)
            if not boost then return nil,'invalid_emerald_path' end
        end
        if type(nodeId) ~= "string" or not M.choose(map, nodeId) then return nil, "invalid_path" end
        if boost and not M.commitEmeraldBoost(map,nodeId,boost) then return nil,'invalid_emerald_path' end
    end
    if not equal(snapshot, map) then return nil, "invalid_snapshot" end
    return map
end

return M
