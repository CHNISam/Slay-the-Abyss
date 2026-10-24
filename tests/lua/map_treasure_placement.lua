local Map = require("abyss_map")
local data = require("abyss_data")

-- Independent source contract: generateRoomTypes queues Shop/Rest/Elite/Event;
-- generateMap assigns TreasureRoom only to row index 8. Boss treasure is separate.
-- This does not assert room quotas, original topology or original seeded RNG.
for seed = 0, 127 do
    local map = Map.generate(data, seed)
    local ordinaryChests, bossChests = 0, 0
    for _, node in ipairs(map.nodes) do
        if node.type == "treasure" then
            assert(node.floor == 9 or node.floor == 17,
                "extra random treasure: seed=" .. seed .. " node=" .. node.id)
            if node.floor == 9 then
                assert(node.roomKind == nil)
                ordinaryChests = ordinaryChests + 1
            else
                assert(node.roomKind == "boss_treasure")
                bossChests = bossChests + 1
            end
        end
    end
    assert(ordinaryChests >= 1 and ordinaryChests <= 6 and bossChests == 1, "fixed treasure boundaries changed")
    for floor = 1, 17 do
        assert(Map.choose(map, Map.available(map)[1].id))
    end
    local restored, reason = Map.restore(data, Map.snapshot(map))
    assert(restored, reason)
    assert(restored.floor == 17)
end
local old = Map.snapshot(Map.generate(data, 0))
old.sourceSignature = 'map-v2:'..old.sourceSignature
local restored, reason = Map.restore(data, old)
assert(restored == nil and reason == "configuration_mismatch", "old room distributions must not restore silently")
print("LUA_MAP_TREASURE_PLACEMENT_PASS 128")
