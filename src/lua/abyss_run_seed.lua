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
local function increment(seed)
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
function M.increment(seed) return increment(M.normalize(seed)) end
function M.add(seed, amount)
    assert(type(amount)=='number' and amount%1==0 and amount>=0 and amount<=1200,'invalid seed offset')
    seed=M.normalize(seed)
    for _=1,amount do seed=increment(seed) end
    return seed
end
-- Java long addition, including signed64 wrap, without a binary64 conversion.
function M.forFloor(seed,floor)
    assert(type(floor)=='number' and floor%1==0 and floor>=0 and floor<=55,'invalid room floor')
    return M.add(seed,floor)
end
return M
