-- Stable post-shuffle placement only. The host owns shuffle and Draw actions.
local M={}
local MAX=2147483647
local bottleFields={"inBottleFlame","inBottleLightning","inBottleTornado","bottled"}
local function integer(n,lo)
    return type(n)=="number" and n==n and n%1==0 and n>=lo and n<=MAX
end
local function plain(t) return type(t)=="table" and getmetatable(t)==nil end
local function dense(t)
    assert(plain(t),"opening draw must be a plain array")
    local n=0
    for k in next,t do assert(integer(k,1),"invalid opening draw index");n=n+1 end
    for i=1,n do assert(rawget(t,i)~=nil,"sparse opening draw") end
    return n
end
local function flags(t)
    assert(plain(t),"invalid opening card metadata")
    if t.innate~=nil then assert(type(t.innate)=="boolean","invalid innate flag") end
    -- The current combat ABI represents source isInnate as `innate` only.
    assert(t.isInnate==nil,"use canonical innate field")
    for _,field in ipairs(bottleFields) do
        local value=rawget(t,field)
        assert(value==nil or type(value)=="boolean","invalid bottled flag")
        assert(value~=true,"bottled opening placement unsupported")
    end
end

-- Inputs must be the COMPLETE already-shuffled combat draw pile, never the
-- unshuffled permanent deck or a pile from which opening cards were drawn.
-- Returns a new array holding the original instances, an uncapped queued draw
-- amount, and data-only counts. No RNG dependency, callbacks or state mutation.
function M.stage(shuffledDraw,catalogCards,masterHandSize)
    dense(shuffledDraw)
    assert(plain(catalogCards),"missing opening card catalog")
    assert(integer(masterHandSize,0),"invalid opening master hand size")
    local ordinary,innate,seen={},{},{}
    for _,instance in ipairs(shuffledDraw) do
        assert(plain(instance) and integer(instance.uid,1) and not seen[instance.uid],"invalid opening card UID")
        seen[instance.uid]=true
        assert(type(instance.cardId)=="string" and instance.cardId~="","invalid opening card ID")
        assert(instance.upgraded==nil or type(instance.upgraded)=="boolean","invalid opening upgrade flag")
        flags(instance)
        local definition=rawget(catalogCards,instance.cardId)
        assert(plain(definition) and definition.id==instance.cardId,"unknown opening card")
        flags(definition)
        if definition.upgrade~=nil then flags(definition.upgrade) end
        local value=definition.innate or false
        if instance.upgraded and definition.upgrade and definition.upgrade.innate~=nil then
            value=definition.upgrade.innate
        end
        if instance.innate~=nil then value=instance.innate end
        local target=value and innate or ordinary
        target[#target+1]=instance
    end
    local result={}
    for _,instance in ipairs(ordinary) do result[#result+1]=instance end
    for _,instance in ipairs(innate) do result[#result+1]=instance end
    local extra=math.max(0,#innate-masterHandSize)
    return result,extra,{innateCount=#innate,ordinaryCount=#ordinary}
end
return M
