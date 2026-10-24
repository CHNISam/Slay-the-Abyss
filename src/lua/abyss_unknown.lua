-- Basic StS1 unknown-room probability reducer, in integer percent units.
-- The caller owns entry transactions and eventRng. No RNG is consumed here.
-- Shop exclusions and special relics require separately verified adapters.
local M = {}
local keys = { 'monster', 'shop', 'treasure' }

local function integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

local function validBase(base)
    if type(base) ~= 'table' then return false end
    for _, key in ipairs(keys) do if not integer(base[key], 1, 100) then return false end end
    for key in pairs(base) do
        if key ~= 'monster' and key ~= 'shop' and key ~= 'treasure' then return false end
    end
    return true
end

local function validState(state, base)
    if type(state) ~= 'table' or state.version ~= 1 or not validBase(base) then return false end
    for _, key in ipairs(keys) do
        -- Keep addition within actual Lua/Fengari integer bounds, before mutation.
        if not integer(state[key], base[key], 2147483547) or state[key] % base[key] ~= 0 then return false end
    end
    for key in pairs(state) do
        if key ~= 'version' and key ~= 'monster' and key ~= 'shop' and key ~= 'treasure' then return false end
    end
    return true
end

function M.new(base)
    assert(validBase(base), 'invalid unknown-room base percentages')
    return { version = 1, monster = base.monster, shop = base.shop, treasure = base.treasure }
end

function M.snapshot(state)
    return { version = state.version, monster = state.monster, shop = state.shop, treasure = state.treasure }
end

function M.restore(snapshot, base)
    if not validState(snapshot, base) then return nil, 'invalid_unknown_snapshot' end
    return M.snapshot(snapshot)
end

function M.advance(state, roll, base)
    assert(validState(state, base), 'invalid unknown-room probability state')
    assert(type(roll) == 'number' and roll == roll and roll >= 0 and roll < 1, 'roll must be in [0,1)')
    local selected, cumulative = 'event', 0.0
    -- Accumulate integer percentages before dividing; .10+.03 floating drift
    -- must not move the supplied equality-boundary contract.
    for _, key in ipairs(keys) do
        cumulative = cumulative + state[key]
        if roll < cumulative / 100 then selected = key; break end
    end
    for _, key in ipairs(keys) do
        state[key] = selected == key and base[key] or state[key] + base[key]
    end
    return selected
end

-- Source-backed PC adapter. Keep the v1 ideal-percent audit API above intact;
-- real entry uses binary32 accumulation and the mirror's actual 100-slot fills.
local F = require('abyss_sts_random').float32
local pcBase = {monster=F(.1), shop=F(.03), treasure=F(.02)}
function M.newPc()
    return {version=2,monster=pcBase.monster,shop=pcBase.shop,treasure=pcBase.treasure,tinyChestCount=0}
end
function M.snapshotPc(s)
    local copy={}
    for k,v in pairs(s) do
        if type(v)=='table' then local p={};for a,b in pairs(v) do p[a]=b end;copy[k]=p else copy[k]=v end
    end
    return copy
end
local function validPc(s)
    if type(s)~='table' or s.version~=2 or not integer(s.tinyChestCount,0,3) then return false end
    for _,k in ipairs(keys) do
        if type(s[k])~='number' or not (s[k]>=pcBase[k] and s[k]<=10000) or F(s[k])~=s[k] then return false end
    end
    for k in pairs(s) do
        if k~='version' and k~='monster' and k~='shop' and k~='treasure' and k~='tinyChestCount' and k~='previous' then return false end
    end
    if s.previous then
        if type(s.previous)~='table' then return false end
        for _,k in ipairs(keys) do if type(s.previous[k])~='number' or not (s.previous[k]>=pcBase[k] and s.previous[k]<=10000) then return false end end
    end
    return true
end
function M.restorePc(s)
    if not validPc(s) then return nil,'invalid_unknown_snapshot' end
    return M.snapshotPc(s)
end
function M.advancePc(s,roll,options)
    assert(validPc(s),'invalid unknown-room PC state')
    assert(type(roll)=='number' and roll>=0 and roll<1,'roll must be in [0,1)')
    options=options or {}
    local bucket=math.floor(F(roll*100.0));local selected,fill='event',0
    -- Arrays.fill's min(99, start) is intentional: at overflow later kinds can
    -- overwrite bucket 99, including a zero-size shop. Documented mirror quirk.
    for _,key in ipairs(keys) do
        local size=key=='shop' and options.previousRoom=='shop' and 0 or math.floor(F(s[key]*100.0))
        if bucket>=math.min(99,fill) and bucket<math.min(100,fill+size) then selected=key end
        fill=fill+size
    end
    s.previous={monster=s.monster,shop=s.shop,treasure=s.treasure}
    if options.tinyChest then
        s.tinyChestCount=(s.tinyChestCount+1)%4
        if s.tinyChestCount==0 then selected='treasure' end
    end
    local rolled=selected
    if selected=='monster' and options.juzu then selected='event' end
    for _,key in ipairs(keys) do
        local hit=(key=='monster' and rolled=='monster') or (key~='monster' and selected==key)
        s[key]=hit and pcBase[key] or F(s[key]+pcBase[key])
    end
    return selected
end
return M
