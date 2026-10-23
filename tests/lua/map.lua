local loaded, Map = pcall(require, "abyss_map")
assert(loaded, "TASK-12 map module is not implemented")
local Random = require("abyss_random")
local data = require("abyss_data")
local count = 0
local function test(name, run)
    run(); count = count + 1; print("ok map " .. count .. " - " .. name)
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function assertSame(a, b, message) assert(equal(a, b), message or "different snapshots") end
local function byId(map)
    local result = {}; for _, node in ipairs(map.nodes) do assert(not result[node.id]); result[node.id] = node end
    return result
end

test("numeric RNG has a known sequence and invalid requests are atomic", function()
    local r = Random.new(42)
    assert(Random.next(r, 10) == 10 and r.seed == 22539)
    assertSame(Random.new(-1), Random.new(65535))
    for _, bad in ipairs({false, "42", 0.5, math.huge, 0/0}) do
        assert(not pcall(Random.new, bad), "invalid seed accepted")
    end
    for _, bad in ipairs({0, -1, 1.5, "3", false, math.huge}) do
        local before = copy(r); assert(not pcall(Random.next, r, bad)); assertSame(r, before)
    end
    local a, b = Random.new(65535), Random.new(65535)
    for _ = 1, 1000 do assert(Random.next(a, 97) == Random.next(b, 97)) end
end)

test("multiple seeds produce reachable generated rows and separate Boss rooms", function()
    for _, seed in ipairs({0, 1, 42, 313, 65535, -17}) do
        local map = Map.generate(data, seed)
        assert(map.floor == 0 and map.currentNodeId == nil and #map.path == 0)
        assert(#map.nodes == 47)
        local index, floors, types = byId(map), {}, {}
        local reachable = {}; for _, node in ipairs(Map.available(map)) do reachable[node.id] = true end
        for _, node in ipairs(map.nodes) do
            assert(reachable[node.id], "unreachable node " .. node.id)
            floors[node.floor] = (floors[node.floor] or 0) + 1; types[node.type] = true
            if node.floor == 15 then assert(node.type == "camp") end
            if node.floor == 17 then
                assert(node.type == "treasure" and node.roomKind == "boss_treasure" and node.lane == 2 and #node.nextIds == 0)
            elseif node.floor == 16 then
                assert(node.type == "boss" and node.lane == 2 and #node.nextIds == 1)
            else
                assert(node.type ~= "boss" and #node.nextIds >= (node.floor == 15 and 1 or 2))
            end
            local seen = {}
            for _, id in ipairs(node.nextIds) do
                local nextNode = assert(index[id], "dangling edge")
                assert(not seen[id] and nextNode.floor == node.floor + 1, "duplicate or cross-floor edge")
                seen[id], reachable[id] = true, true
            end
        end
        for floor = 1, 17 do assert(floors[floor] == (floor > 15 and 1 or 3)) end
    end
end)

test("combat encounter selection respects identity, tier and floor", function()
    local encounters = {}; for _, e in ipairs(data.enemies.encounters) do encounters[e.id] = e end
    for _, seed in ipairs({1, 42, 65535}) do
        for _, node in ipairs(Map.generate(data, seed).nodes) do
            local tier = ({combat="normal", elite="elite", boss="boss"})[node.type]
            if tier then
                local encounter = assert(encounters[node.encounterId])
                assert(encounter.tier == tier and encounter.minFloor <= node.floor and encounter.maxFloor >= node.floor)
            else assert(node.encounterId == nil) end
        end
    end
end)

test("generation is deterministic and does not depend on input ordering or aliases", function()
    local original, input = Map.generate(data, 42), copy(data)
    local reversed = {}; for i = #input.enemies.encounters, 1, -1 do reversed[#reversed+1] = input.enemies.encounters[i] end
    input.enemies.encounters = reversed
    assertSame(original, Map.generate(input, 42))
    input.rules.map.floors = 999; input.enemies.encounters[1].id = "changed"
    assertSame(original, Map.generate(data, 42))
    assert(not equal(original, Map.generate(data, 313)), "different seeds must vary the map")
end)

test("navigation follows legal branches through camp, Boss and Boss treasure", function()
    for _, choice in ipairs({1, 2, 3}) do
        local map, visited = Map.generate(data, 42), {}
        for floor = 1, 17 do
            local available = Map.available(map)
            local node = available[math.min(choice, #available)]
            assert(Map.choose(map, node.id)); assert(map.floor == floor and map.currentNodeId == node.id)
            assert(#map.path == floor and map.path[floor] == node.id); visited[node.type] = true
        end
        assert(#Map.available(map) == 0)
        for _, kind in ipairs({"combat", "camp", "treasure", "boss"}) do assert(visited[kind]) end
        local before = Map.snapshot(map)
        local ok, reason = Map.choose(map, map.currentNodeId)
        assert(ok == false and reason == "map_complete"); assertSame(map, before)
    end
end)

test("unknown, skipped, repeated, backward and disconnected choices are atomic", function()
    local map = Map.generate(data, 42)
    local function reject(id)
        local before = Map.snapshot(map)
        local ok, reason = Map.choose(map, id)
        assert(ok == false and type(reason) == "string"); assertSame(map, before)
    end
    reject(nil); reject(false); reject({}); reject("missing"); reject(map.nodes[7].id)
    local start = Map.available(map)[1]; assert(Map.choose(map, start.id)); reject(start.id)
    local available = Map.available(map); local allowed = {}; for _, node in ipairs(available) do allowed[node.id] = true end
    for _, node in ipairs(map.nodes) do if node.floor == 2 and not allowed[node.id] then reject(node.id) end end
    assert(Map.choose(map, available[1].id)); reject(start.id)
end)

test("view and available return copies with correct visited and legal flags", function()
    local map = Map.generate(data, 42)
    local initial = Map.snapshot(map); local available = Map.available(map)
    available[1].nextIds[1] = "tamper"; assertSame(map, initial)
    assert(Map.choose(map, map.nodes[1].id))
    local allowed = {}; for _, node in ipairs(Map.available(map)) do allowed[node.id] = true end
    local view = Map.view(map)
    for _, node in ipairs(view.nodes) do
        assert(node.visited == (node.id == map.currentNodeId))
        assert(node.available == (allowed[node.id] == true))
    end
    local before = Map.snapshot(map); view.path[1] = "tamper"; view.nodes[1].type = "tamper"
    assertSame(map, before)
end)

test("snapshots restore legal progress as independent same-run state", function()
    local map = Map.generate(data, 313)
    for _ = 1, 7 do assert(Map.choose(map, Map.available(map)[1].id)) end
    local snap = Map.snapshot(map)
    local restored = assert(Map.restore(data, snap))
    assertSame(map, restored)
    restored.nodes[1].nextIds[1] = "tamper"; restored.path[1] = "tamper"
    assertSame(map, snap)
    snap.nodes[1].type = "tamper"; assert(map.nodes[1].type == "combat")
    assert(Map.restore(data, Map.snapshot(Map.generate(data, 0))))
end)

test("malformed graphs, progress, references and configuration drift cannot restore", function()
    local valid = Map.generate(data, 42)
    local changes = {
        function(s) s.version = 999 end,
        function(s) s.seed = math.huge end,
        function(s) s.randomSeed = s.randomSeed + 1 end,
        function(s) s.nodes[1].nextIds[1] = s.nodes[10].id end,
        function(s) s.nodes[1].encounterId = "missing" end,
        function(s) s.nodes[43].floor = 14 end,
        function(s) s.nodes[43].type = "combat" end,
        function(s) s.nodes[1].type = "boss" end,
        function(s) s.nodes[2] = s.nodes[1] end,
        function(s) s.path = {s.nodes[4].id}; s.floor = 1; s.currentNodeId = s.nodes[4].id end,
        function(s) s.path = {[2]=s.nodes[1].id} end,
        function(s) s.floor = 7 end,
        function(s) s.unexpected = true end,
        function(s) s.nodes[1].nextIds[1] = s end,
    }
    for _, change in ipairs(changes) do
        local bad = copy(valid); change(bad)
        local ok, result, reason = pcall(Map.restore, data, bad)
        assert(ok and result == nil and type(reason) == "string", "malformed snapshot was not safely rejected")
    end
    assert(Map.restore(data, false) == nil)
    local changed = copy(data); changed.enemies.encounters[1].maxFloor = 12
    assert(Map.restore(changed, valid) == nil, "changed encounter configuration accepted")
    changed = copy(data); changed.rules.map.restFloor = 13
    assert(Map.restore(changed, valid) == nil, "changed map configuration accepted")
end)

test("invalid map inputs fail instead of dropping required types or encounters", function()
    local missingElite = copy(data)
    local encounters = {}; for _, e in ipairs(missingElite.enemies.encounters) do if e.tier ~= "elite" then encounters[#encounters+1] = e end end
    missingElite.enemies.encounters = encounters
    assert(pcall(Map.generate, missingElite, 1), "optional elite floor must not force an elite")
    local missingType = copy(data); table.remove(missingType.rules.map.nodeTypes)
    assert(not pcall(Map.generate, missingType, 1))
    local duplicate = copy(data); duplicate.enemies.encounters[2].id = duplicate.enemies.encounters[1].id
    assert(not pcall(Map.generate, duplicate, 1))
    assert(not pcall(Map.generate, data, 1.5))
end)

print("LUA_MAP_PASS " .. count)
