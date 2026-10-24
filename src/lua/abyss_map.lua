-- Same-run map navigation only; no platform storage, UI or combat dependencies.
local Random = require("abyss_random")
local M = {}
local kinds = { "combat", "elite", "camp", "shop", "event", "treasure", "boss" }
local tierFor = { combat = "normal", elite = "elite", boss = "boss" }
-- Verified floor boundaries only. Three-lane topology and uniform random draws
-- remain a local candidate, not the original game's generator or random stream.
local forced = { [1] = "combat", [9] = "treasure", [15] = "camp", [16] = "boss", [17] = "treasure" }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
end

local function integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
end

local function array(value, limit)
    if type(value) ~= "table" then return false end
    local length, count = #value, 0
    if length > limit then return false end
    for key in pairs(value) do
        if not integer(key) or key < 1 or key > length then return false end
        count = count + 1
    end
    return count == length
end

local function id(floor, lane) return "f" .. floor .. "_l" .. lane end

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
    local signature = { "map-v2:17:rows15:boss16:rest15:treasure9:bossTreasure17:encounterStream:fixedTreasureOnly" }
    for _, entry in ipairs(encounters) do
        signature[#signature + 1] = entry.id .. ":" .. entry.tier .. ":" .. entry.minFloor .. ":" .. entry.maxFloor
    end
    return encounters, table.concat(signature, "|")
end

local function pool(encounters, kind, floor)
    local result = {}
    for _, encounter in ipairs(encounters) do
        if encounter.tier == tierFor[kind] and encounter.minFloor <= floor and encounter.maxFloor >= floor then
            result[#result + 1] = encounter.id
        end
    end
    return result
end

function M.generate(data, seed)
    local encounters, signature = configuration(data)
    local random = Random.new(seed)
    -- Same initial seed, independent state. Sharing the room-type stream makes
    -- even-sized encounter pools unreachable through low-bit LCG correlation.
    -- This remains the local candidate RNG, not original PC random parity.
    local encounterRandom = Random.new(seed)
    local map = { version = 2, seed = random.seed, randomSeed = random.seed,
        encounterRandomSeed = encounterRandom.seed, sourceSignature = signature,
        floor = 0, path = {}, nodes = {} }
    for floor = 1, data.rules.map.floors do
        local allowed = {}
        for _, kind in ipairs(kinds) do
            -- Ordinary map treasure is the fixed ninth row, never a random room.
            -- Unknown-room treasure is resolved on entry by Nodes, preserving ?.
            if kind ~= "boss" and kind ~= "treasure" and (kind ~= "elite" or floor >= 6)
                and (kind ~= "camp" or (floor >= 6 and floor ~= 14))
                and (not tierFor[kind] or #pool(encounters, kind, floor) > 0) then
                allowed[#allowed + 1] = kind
            end
        end
        for lane = 1, (floor > data.rules.map.generatedRows and 1 or 3) do
            local actualLane = floor > data.rules.map.generatedRows and 2 or lane
            local kind = forced[floor] or allowed[Random.next(random, #allowed)]
            local node = { id = id(floor, actualLane), floor = floor, lane = actualLane, type = kind, nextIds = {} }
            if floor == data.rules.map.bossTreasureFloor then node.roomKind = "boss_treasure" end
            if tierFor[kind] then
                local candidates = pool(encounters, kind, floor)
                assert(#candidates > 0, "no eligible " .. kind .. " encounter on floor " .. floor)
                node.encounterId = candidates[Random.next(encounterRandom, #candidates)]
            end
            map.nodes[#map.nodes + 1] = node
        end
    end
    for _, node in ipairs(map.nodes) do
        if node.floor >= data.rules.map.generatedRows and node.floor < data.rules.map.floors then
            node.nextIds = { id(node.floor + 1, 2) }
        elseif node.floor < data.rules.map.generatedRows then
            local neighbors = node.lane == 2 and {1, 3} or {2}
            node.nextIds = { id(node.floor + 1, node.lane), id(node.floor + 1, neighbors[Random.next(random, #neighbors)]) }
        end
    end
    map.randomSeed = random.seed
    map.encounterRandomSeed = encounterRandom.seed
    return map
end

local function index(map)
    local result = {}; for _, node in ipairs(map.nodes) do result[node.id] = node end; return result
end

function M.available(map)
    if map.floor == 17 then return {} end
    local nodes, result = index(map), {}
    if map.floor == 0 then
        for _, node in ipairs(map.nodes) do if node.floor == 1 then result[#result + 1] = copy(node) end end
    else
        for _, nextId in ipairs(nodes[map.currentNodeId].nextIds) do result[#result + 1] = copy(nodes[nextId]) end
    end
    return result
end

function M.choose(map, nodeId)
    if map.floor == 17 then return false, "map_complete" end
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
    view.complete = map.floor == 17
    return view
end

-- The expected graph is bounded and acyclic, so malformed cyclic input also terminates.
local function equal(actual, expected)
    if type(actual) ~= type(expected) then return false end
    if type(expected) ~= "table" then return actual == expected end
    for key, value in pairs(expected) do if not equal(actual[key], value) then return false end end
    for key in pairs(actual) do if expected[key] == nil then return false end end
    return true
end

-- Strict same-run restoration: regenerate the source graph, then replay legal choices.
-- Returns an independent state or nil/reason; never mutates the supplied snapshot/data.
function M.restore(data, snapshot)
    if type(snapshot) ~= "table" or snapshot.version ~= 2 or not integer(snapshot.seed)
        or snapshot.seed < 0 or snapshot.seed >= 65536 or not array(snapshot.path, 17) then
        return nil, "invalid_snapshot"
    end
    local ok, map = pcall(M.generate, data, snapshot.seed)
    if not ok then return nil, "invalid_configuration" end
    if snapshot.sourceSignature ~= map.sourceSignature then return nil, "configuration_mismatch" end
    for _, nodeId in ipairs(snapshot.path) do
        if type(nodeId) ~= "string" or not M.choose(map, nodeId) then return nil, "invalid_path" end
    end
    if not equal(snapshot, map) then return nil, "invalid_snapshot" end
    return map
end

return M
