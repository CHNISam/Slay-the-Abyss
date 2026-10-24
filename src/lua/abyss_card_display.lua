-- Read-only presentation of values already calculated by Combat.cardPreview.
local integer = require('abyss_numbers').integer
local M = {}
local eligible = {damage=true, damageAll=true, block=true}
function M.values(definition, preview)
    local result = {}
    for index, effect in ipairs(definition.effects) do
        local entry = preview[index]
        if eligible[effect.op] and entry and entry.op == effect.op
            and type(effect.value) == 'number' and type(entry.low) == 'number' and entry.low == entry.high then
            local direction = entry.low > effect.value and 'up' or entry.low < effect.value and 'down' or 'same'
            result[index] = {effectIndex=index, op=effect.op, base=effect.value, current=entry.low,
                direction=direction, text=integer(entry.low) .. (direction=='up' and '↑' or direction=='down' and '↓' or ''),
                colourKey=direction=='up' and 'cardValueIncrease' or direction=='down' and 'cardValueDecrease' or 'text'}
        end
    end
    return result
end
return M
