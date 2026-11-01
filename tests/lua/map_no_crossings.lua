local Map = require("abyss_map")
local data = require("abyss_data")
local function indexed(map)
    local nodes = {}; for _, node in ipairs(map.nodes) do nodes[node.id] = node end; return nodes
end
local function has(node, target)
    for _, id in ipairs(node.nextIds) do if id == target then return true end end
    return false
end

-- Source golden seed0 starts at connected lanes2/3/5/6/7; no phantom lane1.
local sample = Map.generate(data, 0)
local nodes = indexed(sample)
assert(nodes.f1_l1==nil and has(nodes.f1_l2,'f2_l1'))
assert(#nodes.f1_l3.nextIds==1 and has(nodes.f1_l3,'f2_l3'))

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
    old.sourceSignature = 'map-v2:'..old.sourceSignature
    local restored, reason = Map.restore(data, old)
    assert(not restored and reason == "configuration_mismatch", "old crossing graphs must not restore silently")
end
print("LUA_MAP_NO_CROSSINGS_PASS 128")
