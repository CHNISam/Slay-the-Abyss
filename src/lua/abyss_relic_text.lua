-- Shared read-only relic detail text for live UI and out-of-run inspection.
local number=require('abyss_numbers').integer
local triggers={combat_start='战斗开始时，',combat_end='战斗结束时，'}
local function find(entries,id)
    for _,entry in ipairs(entries or {})do if entry.id==id then return entry end end
end
local M={}
function M.describe(data,id)
        if id=='membership_card' then return '所有商店商品半价。' end
        if id=='courier' then return '商店商品八折，购买后补货。' end
        if id=='smiling_mask' then return '商店删牌服务固定为50金币。' end
        local definition = find(data.relics.relics, id)
        if not definition then return "" end
        if definition.description then return definition.description end
        local parts
        local function describeRelicEffects()
            parts = {}
            for _, effect in ipairs(definition.effects or {}) do
                local value = number(effect.value)
                if effect.op == "heal" then parts[#parts + 1] = "回复 " .. value .. " 点生命"
                elseif effect.op == "block" then parts[#parts + 1] = "获得 " .. value .. " 点格挡"
                elseif effect.op == "draw" then parts[#parts + 1] = "抽 " .. value .. " 张牌"
                elseif effect.op == "energy" then parts[#parts + 1] = "获得 " .. value .. " 点能量"
                elseif effect.op == "gainStatus" then
                    local status = find(data.statuses.statuses, effect.status)
                    parts[#parts + 1] = "获得 " .. value .. " 层" .. (status and status.name or effect.status)
                end
            end
        end
        describeRelicEffects()
        if #parts == 0 then return "" end
        return (triggers[definition.trigger] or "") .. table.concat(parts, "，") .. "。"
end
return M
