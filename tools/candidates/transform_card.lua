-- TASK-13.1.2.2: supplied-pool transform selection, not a production event.
-- Fixed mirror fc379c875c11e008e9c10548ac8e394c301c532f:
-- AbstractDungeon.transformCard/returnTrulyRandom*FromAvailable and
-- CardLibrary.getCurse(AbstractCard, Random). See accompanying source note.
local Random = require('abyss_sts_random')
local M = {}
local groups = {
    colored = {'common', 'srcUncommon', 'srcRare'},
    colorless = {'srcColorless'},
    curse = {'curses'},
}
local excludedCurses = {Necronomicurse=true, AscendersBane=true, CurseOfTheBell=true, Pride=true}

local function validId(id) return type(id)=='string' and id~='' end

-- Reject sparse/metadata-bearing arrays and metatables before traversing by
-- position. Duplicate IDs remain distinct slots; pool order is caller-owned.
local function validPool(pool)
    if type(pool)~='table' or getmetatable(pool)~=nil then return false end
    local count, highest = 0, 0
    for key,id in pairs(pool) do
        if type(key)~='number' or key%1~=0 or key<1 or key>2147483647 or not validId(id) then return false end
        count=count+1
        if key>highest then highest=key end
    end
    return count==highest
end

-- category is colored/colorless/curse, not an inferred card type or rarity.
-- Returns a fresh unupgraded card descriptor and advanced cloned RNG. Caller
-- must commit that RNG together with acquisition/event state; this is NOT a
-- permanent-deck transaction. A refusal returns nil/reason, mutating nothing.
function M.select(category, prohibitedId, pools, rng)
    if type(category)~='string' or not groups[category] then return nil,'invalid_category' end
    if not validId(prohibitedId) then return nil,'invalid_card_id' end
    if type(pools)~='table' or getmetatable(pools)~=nil then return nil,'invalid_pools' end
    local candidates = {}
    for _,name in ipairs(groups[category]) do
        local pool=pools[name]
        if not validPool(pool) then return nil,'invalid_pools' end
        for _,id in ipairs(pool) do
            if id~=prohibitedId and not (category=='curse' and excludedCurses[id]) then
                candidates[#candidates+1]=id
            end
        end
    end
    if #candidates==0 then return nil,'empty_transform_pool' end
    local ok,nextRng=pcall(Random.cloneState,rng)
    if not ok then return nil,'invalid_rng' end
    local index
    if category=='curse' then index=Random.randomIntBetween(nextRng,0,#candidates-1)
    else index=Random.randomInt(nextRng,#candidates-1) end
    return {cardId=candidates[index+1],upgraded=false},nextRng
end

return M
