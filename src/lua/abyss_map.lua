-- Same-run map navigation only; no platform storage, UI or combat dependencies.
local Rooms = require("abyss_map_rooms")
local Seed = require("abyss_run_seed")
local Acts = require('abyss_acts')
local M = {}
local kinds = { "combat", "elite", "camp", "shop", "event", "treasure", "boss" }
-- Topology and room kinds only. Actual encounters belong to the Run queue and
-- are selected after a legal room entry succeeds; rendering/restoring draws none.

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

function M.generate(data, seed, act)
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
local function equal(actual, expected)
    if type(actual) ~= type(expected) then return false end
    if type(expected) ~= "table" then return actual == expected end
    if getmetatable(actual)~=nil then return false end
    for key, value in pairs(expected) do if not equal(actual[key], value) then return false end end
    for key in pairs(actual) do if expected[key] == nil then return false end end
    return true
end

-- Strict same-run restoration: regenerate the source graph, then replay legal choices.
-- Returns an independent state or nil/reason; never mutates the supplied snapshot/data.
function M.restore(data, snapshot)
    if type(snapshot) ~= "table" or getmetatable(snapshot)~=nil or (snapshot.version ~= 3 and snapshot.version ~= 4)
        or type(snapshot.runSeed)~='string' or not array(snapshot.path, 17) then
        return nil, "invalid_snapshot"
    end
    local ok, map = pcall(M.generate, data, snapshot.runSeed, snapshot.version==4 and snapshot.act or 1)
    if not ok then return nil, "invalid_configuration" end
    if snapshot.sourceSignature ~= map.sourceSignature then return nil, "configuration_mismatch" end
    for _, nodeId in ipairs(snapshot.path) do
        if type(nodeId) ~= "string" or not M.choose(map, nodeId) then return nil, "invalid_path" end
    end
    if not equal(snapshot, map) then return nil, "invalid_snapshot" end
    return map
end

return M
