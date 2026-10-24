local Map = require("abyss_map")
local data = require("abyss_data")
local function indexed(map)
    local nodes = {}; for _, node in ipairs(map.nodes) do nodes[node.id] = node end; return nodes
end
local function has(node, target)
    for _, id in ipairs(node.nextIds) do if id == target then return true end end
    return false
end

-- Independent clamp example: the left source already reaches lane 2. A lane-2
-- proposal to lane 1 must become lane 2 and deduplicate its existing straight edge.
local sample = Map.generate(data, 0)
local nodes = indexed(sample)
assert(has(nodes.f1_l1, "f2_l2"))
assert(not has(nodes.f1_l2, "f2_l1"), "seed0 crossing: f1_l1->f2_l2 / f1_l2->f2_l1")
assert(#nodes.f1_l2.nextIds == 1 and nodes.f1_l2.nextIds[1] == "f2_l2", "clamp must deduplicate the straight edge")

for seed = 0, 127 do
    local map = Map.generate(data, seed)
    local index = indexed(map)
    for _, left in ipairs(map.nodes) do
        for _, right in ipairs(map.nodes) do
            if left.floor == right.floor and left.lane < right.lane then
                for _, leftId in ipairs(left.nextIds) do
                    for _, rightId in ipairs(right.nextIds) do
                        assert(index[leftId].lane <= index[rightId].lane,
                            "crossing: seed=" .. seed .. " " .. left.id .. " / " .. right.id)
                    end
                end
            end
        end
    end
    local old = Map.snapshot(map)
    old.sourceSignature = old.sourceSignature:gsub(":adjacentEdgeClamp", "")
    local restored, reason = Map.restore(data, old)
    assert(not restored and reason == "configuration_mismatch", "old crossing graphs must not restore silently")
end
print("LUA_MAP_NO_CROSSINGS_PASS 128")
