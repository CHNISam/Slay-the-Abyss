-- TASK-16.1 source-interpretation subset. Never production RNG or game-save format.
-- STS mirror 319009d5df0a82d9fb0f23cc22322286c6a87ec0, random/Random.java.
-- Explicit ABI and exclusions: docs/reviews/TASK-16.1-random-wrapper-candidate.md.
local P = dofile('tools/candidates/libgdx_randomxs128.lua')
local R = {}
local floor = math.floor
local MIN, MAX = -2147483648.0, 2147483647.0
local function exact(t, keys)
    assert(type(t)=='table' and getmetatable(t)==nil, 'Expected plain table')
    for k in pairs(t) do assert(keys[k], 'Unexpected field') end
end
local function int32(n)
    return type(n)=='number' and n>=MIN and n<=MAX and n==floor(n)
end
local function validate(s)
    exact(s,{primitive=true,counter=true})
    assert(int32(s.counter), 'Invalid signed32 counter')
    P.snapshot(s.primitive) -- Validate nested state before increment or draw.
end
local function advance(s)
    if s.counter==MAX then s.counter=MIN else s.counter=s.counter+1 end
end
local function probability(p)
    if type(p)~='number' or not (p>=0 and p<=1) then return false end
    if p==0 then return true end
    if p<2.0^-126 then
        local units=p*2.0^149
        return units==floor(units)
    end
    local normalized=p
    while normalized<1 do normalized=normalized*2 end
    local significand=normalized*8388608.0
    return significand==floor(significand)
end
function R.fromSeed(seed,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    return {primitive=P.fromSeed(seed),counter=0}
end
function R.snapshot(s)
    validate(s)
    return {words=P.snapshot(s.primitive),counter=s.counter}
end
function R.restore(snap)
    exact(snap,{words=true,counter=true})
    assert(int32(snap.counter), 'Invalid signed32 counter')
    return {primitive=P.restore(snap.words),counter=snap.counter}
end
function R.cloneState(s)
    return R.restore(R.snapshot(s))
end
function R.randomInt(s,maximum,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s)
    assert(int32(maximum) and maximum<MAX, 'Unsupported integer ABI or overflowing bound')
    advance(s)
    return P.nextInt(s.primitive,maximum+1)
end
function R.randomIntBetween(s,minimum,maximum,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s)
    assert(int32(minimum) and int32(maximum), 'Unsupported integer ABI')
    -- Force binary64 arithmetic, avoiding Fengari signed32 intermediate overflow.
    local span=maximum/1.0-minimum
    assert(span>=MIN and span<MAX, 'Unsupported overflowing signed32 span')
    advance(s)
    return minimum/1.0+P.nextInt(s.primitive,span+1)
end
function R.randomBoolean(s,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s);advance(s)
    local raw=P.next64Hex(s.primitive)
    return tonumber(raw:sub(16,16),16)%2==1
end
function R.randomBooleanChance(s,chance,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s)
    assert(probability(chance), 'Unsupported probability: require exact binary32 in [0,1]')
    advance(s)
    return P.nextFloat(s.primitive)<chance
end
function R.randomFloat(s,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s);advance(s)
    return P.nextFloat(s.primitive)
end
return R
