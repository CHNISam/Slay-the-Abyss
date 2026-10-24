-- Immutable signed64 run identity; legacy combat/encounter state stays separate.
local Random = require('abyss_sts_random')
local M = {}
function M.normalize(seed)
    if seed==nil then seed=1 end
    if type(seed)=='number' then
        assert(seed==seed and math.abs(seed)<=9007199254740991 and seed%1==0,'seed must be a finite safe integer or signed64 string')
        seed=seed==0 and '0' or string.format('%.0f',seed)
    end
    Random.fromSeed(seed) -- Existing canonical signed64 validator, no RNG draws.
    return seed
end
function M.legacy(seed)
    seed=M.normalize(seed)
    local negative=seed:sub(1,1)=='-'
    local value=0
    for i=negative and 2 or 1,#seed do value=(value*10+tonumber(seed:sub(i,i)))%65536 end
    return negative and (65536-value)%65536 or value
end
function M.increment(seed)return require('abyss_map_topology').seedForActOne(M.normalize(seed))end
-- Java long addition, including signed64 wrap, without a binary64 conversion.
function M.forFloor(seed,floor)
    assert(type(floor)=='number' and floor%1==0 and floor>=0 and floor<=17,'invalid room floor')
    seed=M.normalize(seed)
    for _=1,floor do seed=M.increment(seed) end
    return seed
end
return M
