local Map = require("abyss_map")
local data = require("abyss_data")
assert(data.rules.map.generatedRows == 15)
assert(data.rules.map.floors == 17 and data.rules.map.bossFloor == 16)
assert(data.rules.map.bossTreasureFloor == 17 and data.rules.map.restFloor == 15)
for seed = 0, 127 do
    local map = Map.generate(data, seed)
    local forced = { [1] = "combat", [9] = "treasure", [15] = "camp", [16] = "boss" }
    local rows = {}
    for _, node in ipairs(map.nodes) do
        assert(node.floor <= 17)
        if node.floor == 17 then assert(node.roomKind == "boss_treasure" and node.type == "treasure") end
        rows[node.floor] = true
        if forced[node.floor] then assert(node.type == forced[node.floor], "wrong forced row") end
        if node.floor <= 5 then assert(node.type ~= "camp" and node.type ~= "elite") end
        if node.floor == 14 then assert(node.type ~= "camp") end
    end
    for floor = 1, 17 do
        assert(rows[floor])
        assert(Map.choose(map, Map.available(map)[1].id))
        if floor == 15 then
            local choices = Map.available(map)
            assert(#choices == 1 and choices[1].floor == 16 and choices[1].type == "boss")
            assert(not Map.view(map).complete, "camp arrival is not Boss arrival")
        end
    end
    assert(Map.view(map).complete and #map.path == 17)
    assert(Map.restore(data, Map.snapshot(map)), "completed Boss route must restore")
end
local old = Map.snapshot(Map.generate(data, 42)); old.version = 1
assert(Map.restore(data, old) == nil, "old 15-floor snapshots cannot silently use new rules")
print("LUA_MAP_FLOOR_BOUNDARIES_PASS 1")
