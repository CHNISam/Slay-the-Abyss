-- Pure Power definition, amount and stacking rules. Actor owns all commits,
-- acquisition order, application callbacks and presentation events.
local M = {}
local stacks = { intensity = true, duration = true, none = true }
local decays = { none = true, turn_end_minus_1 = true, round_end_minus_1 = true,
    turn_start_trigger_then_minus_1 = true, turn_end_trigger_then_minus_1 = true }
local signed = { strength = true, dexterity = true, focus = true }
-- Only source-verified ApplyPower categories; raw status mutation stays separate.
local debuffs = { draw_reduction=true, corpse_explosion=true,wraith_form=true,no_block=true, bias=true, weak=true, vulnerable=true, frail=true, poison=true, entangled=true,
    shackled=true,choked=true,block_return=true,mark=true,energy_down=true,hex=true,confusion=true,constricted=true,slow=true }

local function integer(amount)
    return type(amount) == "number" and amount == amount and amount % 1 == 0
        and amount >= -2147483647 and amount <= 2147483647
end
M.integer=integer

function M.validateAmount(id,amount)
    assert(integer(amount) and (signed[id] or id=='wraith_form' or (id=='unawakened'or id=='regrow'or id=='painful_stabs') and amount==-1 or amount >= 0), "invalid status amount")
end

function M.validateDefinitions(definitions)
    assert(type(definitions) == "table", "missing status definitions")
    for id, definition in pairs(definitions) do
        assert(definition.id == id and stacks[definition.stack] and decays[definition.decay], "invalid status definition")
        if definition.decay:find("trigger", 1, true) then
            assert(id == "poison" or id == "regen", "unknown status trigger")
        end
    end
end

function M.artifactEligible(id,amount)
    return debuffs[id] == true or (signed[id] == true and amount <= 0)
end

local function clampStatusStack(id,before,amount,value)
    -- Strength/Dexterity clamp after stacking, for either actor and either sign.
    if signed[id] then value = math.max(-999, math.min(999, value)) end
    if id == 'plated_armor' and before > 0 then value = math.min(999, value) end
    if id=='painful_stabs' and (before==-1 or amount==-1)then value=-1 end
    return value
end

local function normalizeStatusStack(id,definition,value)
    if definition.stack == "none" and id~="unawakened" and id~="regrow" and id~='painful_stabs' then value = value > 0 and 1 or 0 end
    if id=='painful_stabs' and value>0 then value=1 end
    return value
end

local function retainsNegativeStatus(id)
    return signed[id] or id=='wraith_form' or id=='unawakened'or id=='regrow'or id=='painful_stabs'
end

function M.stackValue(id,definition,before,amount)
    local value = before + 0.0 + amount
    assert(integer(value), "status stack overflow") -- reject before Actor commits
    value=clampStatusStack(id,before,amount,value)
    value=normalizeStatusStack(id,definition,value)
    return retainsNegativeStatus(id) and value or math.max(0, value)
end

return M
