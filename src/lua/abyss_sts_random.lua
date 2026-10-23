-- Promoted TASK-16.1 source-interpretation subset for independent event streams.
-- STS mirror 319009d5df0a82d9fb0f23cc22322286c6a87ec0, random/Random.java.
-- Explicit ABI and exclusions: docs/reviews/TASK-16.1-random-wrapper-candidate.md.
local P = require('abyss_randomxs128')
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

local MAX_FLOAT = (2.0-2.0^-23)*2.0^127
-- Round one finite binary64 intermediate to binary32, nearest/even. Operands
-- are binary32; their products have <=48 significant bits. Addition of two
-- binary32 operands is also safe to round via binary64. Preserve signed zero
-- and the 2^-149 subnormal grid; do not depend on 64-bit integers or pack().
local function float32(value)
    if value==0 then return value/1.0 end
    local sign=value<0 and -1.0 or 1.0
    local absolute=value*sign
    local significand,unit
    if absolute<2.0^-126 then
        significand=absolute*2.0^149;unit=2.0^-149
    else
        local scaled,power=absolute,1.0
        while scaled>=2.0 do scaled=scaled/2.0;power=power*2.0 end
        while scaled<1.0 do scaled=scaled*2.0;power=power/2.0 end
        significand=scaled*8388608.0;unit=power/8388608.0
    end
    local rounded=floor(significand)
    local remainder=significand-rounded
    if remainder>0.5 or (remainder==0.5 and rounded%2~=0) then rounded=rounded+1 end
    local result=rounded*unit
    if result>MAX_FLOAT then return sign*math.huge end
    return sign*result
end
local function finiteFloat(value)
    return type(value)=='number' and value==value and value>=-MAX_FLOAT and value<=MAX_FLOAT
        and float32(value)==value
end
R.float32 = float32
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
-- EventRoom reconstructs selection from seed + room counter. Selection draws do
-- not advance the persistent room stream (Random(seed,counter) uses random(999)).
function R.atCounter(seed, counter)
    assert(int32(counter) and counter>=0 and counter<=100000, 'Invalid replay counter')
    local s=R.fromSeed(seed)
    for _=1,counter do R.randomInt(s,999) end
    return s
end
function R.randomLongHex(s)
    validate(s); advance(s)
    return P.next64Hex(s.primitive)
end
-- java.util.Random's 48-bit LCG and Collections.shuffle. Three 16-bit limbs
-- avoid binary64 precision loss and Fengari signed32 intermediate overflow.
function R.shuffle(s, list)
    local h=R.randomLongHex(s)
    local limbs={tonumber(h:sub(13,16),16),tonumber(h:sub(9,12),16),tonumber(h:sub(5,8),16)}
    local multiplier={58989,57068,5} -- 0x0005deece66d
    local function xor16(a,b)
        local n,p=0,1
        for _=1,16 do if a%2~=b%2 then n=n+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end
        return n
    end
    for i=1,3 do limbs[i]=xor16(limbs[i],multiplier[i]) end
    local function bits31()
        local nextLimbs,carry={},11.0
        for i=1,3 do
            local value=carry
            for j=1,i do value=value+(limbs[j]/1.0)*multiplier[i-j+1] end
            nextLimbs[i]=value%65536;carry=math.floor(value/65536)
        end
        limbs=nextLimbs
        return math.floor((limbs[3]*4294967296.0+limbs[2]*65536.0+limbs[1])/131072.0)
    end
    local function index(bound)
        assert(bound>=1 and bound<=65536, 'Unsupported shuffle size')
        local power=bound
        while power>1 and power%2==0 do power=power/2 end
        if power==1 then return math.floor(bound/1.0*bits31()/2147483648.0) end
        while true do
            local bits=bits31();local value=bits%bound
            if bits-value+(bound-1)<2147483648.0 then return value end
        end
    end
    for i=#list,2,-1 do local j=index(i)+1;list[i],list[j]=list[j],list[i] end
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
function R.randomFloatRange(s,range,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s)
    assert(finiteFloat(range), 'Unsupported range: require exact finite binary32')
    advance(s)
    return float32(P.nextFloat(s.primitive)*range)
end
function R.randomFloatBetween(s,minimum,maximum,...)
    assert(select('#',...)==0, 'Unsupported extra arguments')
    validate(s)
    assert(finiteFloat(minimum) and finiteFloat(maximum), 'Unsupported endpoints: require exact finite binary32')
    local span=float32(maximum/1.0-minimum)
    assert(span~=math.huge and span~=-math.huge, 'Unsupported overflowing binary32 span')
    advance(s)
    local scaled=float32(P.nextFloat(s.primitive)*span)
    return float32(minimum/1.0+scaled)
end
return R
