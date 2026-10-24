-- Production A0 Act1 topology, promoted from the independently verified candidate.
-- Independently written from pinned source behavior; provenance and exclusions:
-- docs/reviews/TASK-12.4-map-rng-topology-candidate.md.
local Random = require('abyss_sts_random')
local T = {}

function T.seedForActOne(seed, ...)
    assert(select('#', ...) == 0, 'Unsupported extra arguments')
    Random.fromSeed(seed) -- Reuse strict canonical signed64 validation, no draw.
    if seed == '9223372036854775807' then return '-9223372036854775808' end
    local negative = seed:sub(1, 1) == '-'
    local digits = negative and seed:sub(2) or seed
    local result, carry = {}, 1
    for i = #digits, 1, -1 do
        local value = tonumber(digits:sub(i, i)) + (negative and -carry or carry)
        if value < 0 then value, carry = 9, 1
        elseif value > 9 then value, carry = 0, 1
        else carry = 0 end
        result[i] = tostring(value)
    end
    local value = table.concat(result)
    if not negative and carry == 1 then value = '1' .. value end
    value = value:gsub('^0+', '')
    if value == '' then return '0' end
    return negative and '-' .. value or value
end

local function extremeParent(parents, maximum)
    local result = parents[1]
    for i = 2, #parents do
        if (maximum and parents[i].x > result.x) or (not maximum and parents[i].x < result.x) then
            result = parents[i]
        end
    end
    return result
end

-- Kept public in this isolated candidate for independent ancestry vectors.
function T.commonAncestor(first, second, depth)
    assert(first ~= second and first.y == second.y, 'Expected different nodes in the same row')
    local left, right
    -- The pinned game mirror and independent oracle both use x < other.y.
    -- Changing this to the apparently intended x < other.x changes behavior.
    if first.x < second.y then left, right = first, second else left, right = second, first end
    for _ = first.y, math.max(0, first.y - depth), -1 do
        if #left.parents == 0 or #right.parents == 0 then return nil end
        left, right = extremeParent(left.parents, true), extremeParent(right.parents, false)
        if left == right then return left end
    end
    return nil
end

local function addEdge(node, x, y)
    for _, edge in ipairs(node.edges) do if edge.dst_x == x and edge.dst_y == y then return end end
    node.edges[#node.edges + 1] = { src_x = node.x, src_y = node.y, dst_x = x, dst_y = y }
    table.sort(node.edges, function(a, b) return a.dst_x < b.dst_x or (a.dst_x == b.dst_x and a.dst_y < b.dst_y) end)
end

-- Explicit draw-injection seam for source-boundary vectors. No room assignment.
-- The normal entry below fixes dimensions to 15 rows, 7 columns and 6 paths.
function T.generateDungeon(height, width, density, draw)
    assert(type(height) == 'number' and height % 1 == 0 and height >= 2 and height <= 15)
    assert(type(width) == 'number' and width % 1 == 0 and width >= 2 and width <= 7)
    assert(type(density) == 'number' and density % 1 == 0 and density >= 1 and density <= 6)
    assert(type(draw) == 'function', 'Expected closed-integer draw function')
    local function random(minimum, maximum)
        local value = draw(minimum, maximum)
        assert(type(value) == 'number' and value % 1 == 0 and value >= minimum and value <= maximum, 'Draw outside closed range')
        return value
    end
    local grid = {}
    for y = 0, height - 1 do
        grid[y + 1] = {}
        for x = 0, width - 1 do grid[y + 1][x + 1] = { x = x, y = y, edges = {}, parents = {} } end
    end
    local function node(x, y) return grid[y + 1][x + 1] end
    local function path(x, y)
        local current = node(x, y)
        if y + 1 >= height then
            -- Source terminal drawing anchor, not an extra generated map row.
            addEdge(current, 3, y + 2)
            return
        end
        local minimum, maximum = -1, 1
        if x == 0 then minimum = 0 elseif x == width - 1 then maximum = 0 end
        local nextX, nextY = x + random(minimum, maximum), y + 1
        local target = node(nextX, nextY)
        -- Iterate the original candidate's parent list even when retry changes
        -- target. Source addParent intentionally retains duplicate references.
        local parents = target.parents
        for _, parent in ipairs(parents) do
            if parent ~= current then
                local ancestor = T.commonAncestor(parent, current, 5)
                if ancestor and nextY - ancestor.y < 3 then
                    if target.x > x then
                        nextX = x + random(-1, 0)
                        if nextX < 0 then nextX = x end
                    elseif target.x == x then
                        nextX = x + random(-1, 1)
                        if nextX > width - 1 then nextX = x - 1 elseif nextX < 0 then nextX = x + 1 end
                    else
                        nextX = x + random(0, 1)
                        if nextX > width - 1 then nextX = x end
                    end
                    target = node(nextX, nextY)
                end
            end
        end
        if x > 0 then
            local edges = node(x - 1, y).edges
            if #edges > 0 then nextX = math.max(nextX, edges[#edges].dst_x) end
        end
        if x < width - 1 then
            local edges = node(x + 1, y).edges
            if #edges > 0 then nextX = math.min(nextX, edges[1].dst_x) end
        end
        target = node(nextX, nextY)
        addEdge(current, nextX, nextY)
        target.parents[#target.parents + 1] = current
        path(nextX, nextY)
    end
    local firstStart
    for i = 1, density do
        local start = random(0, width - 1)
        if i == 1 then firstStart = start end
        while i == 2 and start == firstStart do start = random(0, width - 1) end
        path(start, 0)
    end
    -- Only the first row is filtered. Parent lists are not rewritten after
    -- removing an edge, matching the fixed source's later assignment inputs.
    local seen = {}
    for _, current in ipairs(grid[1]) do
        local retained = {}
        for _, edge in ipairs(current.edges) do
            local key = edge.dst_x .. ',' .. edge.dst_y
            if not seen[key] then retained[#retained + 1] = edge end
            seen[key] = true
        end
        current.edges = retained
    end
    local nodes, edges = {}, {}
    for _, row in ipairs(grid) do
        for _, current in ipairs(row) do
            if #current.edges > 0 then
                nodes[#nodes + 1] = { x = current.x, y = current.y }
                for _, edge in ipairs(current.edges) do
                    if edge.dst_y < height then edges[#edges + 1] = edge end
                end
            end
        end
    end
    return { height = height, width = width, pathDensity = density, grid = grid, nodes = nodes, edges = edges }
end

function T.generate(runSeed, ...)
    assert(select('#', ...) == 0, 'Unsupported extra arguments')
    local mapSeed = T.seedForActOne(runSeed)
    local rng = Random.fromSeed(mapSeed)
    local result = T.generateDungeon(15, 7, 6, function(minimum, maximum)
        -- MapGenerator.randRange uses random(max-min)+min, not the float API.
        return minimum + Random.randomInt(rng, maximum - minimum)
    end)
    result.runSeed, result.mapSeed, result.randomState = runSeed, mapSeed, Random.snapshot(rng)
    return result
end

return T
