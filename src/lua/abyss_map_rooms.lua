-- Production A0 Act1 room assignment, promoted from the verified candidate.
-- Independently authored from the behavior ledger, not upstream implementation.
-- Scope and source limits: docs/reviews/TASK-12.4-map-room-candidate.md.
local Topology = require('abyss_map_topology')
local Random = require('abyss_sts_random')
local Primitive = require('abyss_randomxs128')
local C = {}

-- Positive binary64 -> binary32 nearest/even, limited to the small finite
-- products used by room quotas. Binary32 operands multiply exactly in binary64.
local function roundedProduct(count, chance)
    local value = count * chance
    if value == 0 then return 0 end
    local scaled, unit = value, 1.0
    while scaled >= 2 do scaled, unit = scaled / 2, unit * 2 end
    while scaled < 1 do scaled, unit = scaled * 2, unit / 2 end
    local significand = scaled * 8388608.0
    local base = math.floor(significand)
    local remainder = significand - base
    if remainder > 0.5 or (remainder == 0.5 and base % 2 == 1) then base = base + 1 end
    return math.floor(base * (unit / 8388608.0) + 0.5)
end

function C.quotas(count)
    assert(type(count) == 'number' and count >= 0 and count <= 105 and count % 1 == 0, 'Expected grid room count')
    -- Exact binary32 representations of Exordium's A0 literals.
    return {
        shop = roundedProduct(count, 0.05000000074505806),
        camp = roundedProduct(count, 0.11999999731779099),
        elite = roundedProduct(count, 0.07999999821186066),
        event = roundedProduct(count, 0.2199999988079071),
    }
end

-- nextInt receives an exclusive bound, bypassing the STS wrapper counter.
function C.shuffle(list, nextInt)
    for length = #list, 2, -1 do
        local index = nextInt(length)
        assert(type(index) == 'number' and index % 1 == 0 and index >= 0 and index < length, 'Invalid raw shuffle draw')
        list[length], list[index + 1] = list[index + 1], list[length]
    end
end

local parentRestricted = { camp = true, treasure = true, shop = true, elite = true }
local siblingRestricted = { camp = true, combat = true, event = true, elite = true, shop = true }

-- Returns the first legal pool index, leaving the pool untouched. Kept public
-- only for independent rule vectors; input is the topology candidate's grid ABI.
function C.selectRoom(grid, node, pool)
    for index, kind in ipairs(pool) do
        local rowAllowed = not ((node.y <= 4 and (kind == 'camp' or kind == 'elite'))
            or (node.y >= 13 and kind == 'camp'))
        if rowAllowed then
            local matches = false
            for _, parent in ipairs(node.parents) do
                if parentRestricted[kind] and parent.type == kind then matches = true end
                if siblingRestricted[kind] then
                    for _, edge in ipairs(parent.edges) do
                        local sibling = grid[edge.dst_y + 1][edge.dst_x + 1]
                        if sibling ~= node and sibling.type == kind then matches = true end
                    end
                end
            end
            if not matches or node.y == 0 then return index end
        end
    end
    return nil
end

function C.assign(grid, pool)
    for _, row in ipairs(grid) do
        for _, node in ipairs(row) do
            if #node.edges > 0 and node.type == nil then
                local index = C.selectRoom(grid, node, pool)
                if index then node.type = table.remove(pool, index) end
            end
        end
    end
    -- The fallback deliberately does not consume a rejected room or revisit a
    -- previously assigned sibling. It happens only after the whole first pass.
    local fallback = 0
    for _, row in ipairs(grid) do
        for _, node in ipairs(row) do
            if #node.edges > 0 and node.type == nil then node.type = 'combat'; fallback = fallback + 1 end
        end
    end
    return fallback
end

function C.generate(runSeed, ...)
    assert(select('#', ...) == 0, 'Unsupported extra arguments')
    local map = Topology.generate(runSeed)
    local quotaCount = 0
    for _, node in ipairs(map.nodes) do if node.y ~= 13 then quotaCount = quotaCount + 1 end end
    local quotas, pool = C.quotas(quotaCount), {}
    for _, kind in ipairs({'shop', 'camp', 'elite', 'event'}) do
        for _ = 1, quotas[kind] do pool[#pool + 1] = kind end
    end
    -- Assign every cell in the fixed rows, including disconnected cells whose
    -- retained parent references may still affect later source rule checks.
    for row, kind in pairs({ [1] = 'combat', [9] = 'treasure', [15] = 'camp' }) do
        for _, node in ipairs(map.grid[row]) do node.type = kind end
    end
    local unassignedCount = 0
    for _, row in ipairs(map.grid) do
        for _, node in ipairs(row) do
            if #node.edges > 0 and node.type == nil then unassignedCount = unassignedCount + 1 end
        end
    end
    while #pool < unassignedCount do pool[#pool + 1] = 'combat' end
    -- Resume the exact path-ending state, never seed another generator.
    local rng = Random.restore(map.randomState)
    map.topologyState = Random.snapshot(rng)
    map.poolBeforeShuffle = {}
    for i, kind in ipairs(pool) do map.poolBeforeShuffle[i] = kind end
    C.shuffle(pool, function(bound) return Primitive.nextInt(rng.primitive, bound) end)
    map.poolAfterShuffle = {}
    for i, kind in ipairs(pool) do map.poolAfterShuffle[i] = kind end
    map.fallbackCount = C.assign(map.grid, pool)
    for _, node in ipairs(map.nodes) do node.type = map.grid[node.y + 1][node.x + 1].type end
    map.quotaCount, map.quotas, map.unassignedCount, map.remainingRooms = quotaCount, quotas, unassignedCount, pool
    map.randomState = Random.snapshot(rng)
    return map
end

return C
