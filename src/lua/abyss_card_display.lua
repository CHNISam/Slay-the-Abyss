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
-- Encodes only the numeric dynamic variable, never the surrounding sentence.
-- Native colour parsing verified by the independent 1849 probe (see evidence).
function M.format(template, definition, preview, palette)
    local values = M.values(definition, preview)
    return (template:gsub('{effects%.(%d+)%.value}', function(rawIndex)
        local index = tonumber(rawIndex) + 1
        local token, entry = values[index], preview[index]
        if token and token.direction ~= 'same' then
            local colour = assert(palette[token.colourKey])
            local hex = string.format('#%02X%02X%02X', colour.r, colour.g, colour.b)
            return '<color=' .. hex .. '>' .. token.text .. '</color>'
        end
        if entry then
            assert(entry.low == entry.high, 'card damage display must be exact')
            return integer(entry.low)
        end
        return integer(definition.effects[index].value)
    end))
end
return M
