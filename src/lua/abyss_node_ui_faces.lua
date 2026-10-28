local CardSkin=require('abyss_card_skin')
local Theme = require("abyss_theme")
local CardDisplay = require('abyss_card_display')
local Combat = require('abyss_combat')
local number = require("abyss_numbers").integer
local C = Theme.color
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }
local triggers = { combat_start = "战斗开始时，", combat_end = "战斗结束时，" }
local function find(entries, id, key)
    for _, item in ipairs(entries or {}) do if item[key or "id"] == id then return item end end
end
local M = {}

-- Installs the faces responsibility on one node UI instance.
function M.install(ctx)
    function ctx.card(id) return find(ctx.self.run.data.cards.cards, id) end

    function ctx.cardName(id, upgraded, upgrades)
        local display, definition = ctx.self.presentation[id], ctx.card(id)
        return (display and display.name or (definition and definition.name) or id)
        .. (upgraded and ('+'..(definition and definition.repeatable and number(upgrades or 1) or '')) or '')
    end

    function ctx.relicName(id)
        local definition = find(ctx.self.run.data.relics.relics, id)
        return definition and definition.name or id
    end

    function ctx.potionText(id) return require('abyss_potion_text').describe(ctx.self.run,id) end

    function ctx.eventOptionText(option)
        if option.rewardCard then
            local definition=assert(ctx.card(option.cardId),'missing reward definition')
            local display=assert(ctx.self.presentation[option.cardId],'missing reward display')
            local cost=display.cost
            if option.upgraded and definition.upgrade and definition.upgrade.cost~=nil then cost=number(definition.upgrade.cost)end
            return '费用 '..cost..' · '..typeNames[definition.type]..' · '
            ..({rare='稀有',uncommon='罕见'})[definition.rarity]..'｜'
            ..CardDisplay.permanentText(display,definition,option)
        end
        return option.description..(option.potionId and '\n'..ctx.potionText(option.potionId)or'')
        ..(option.cardId and '\n「'..ctx.cardName(option.cardId,option.upgraded,option.upgrades)..'」'or'')
        ..(not option.enabled and '（当前条件不足）'or'')
    end

    function ctx.relicText(id)
        if id=='membership_card' then return '所有商店商品半价。' end
        if id=='courier' then return '商店商品八折，购买后补货。' end
        if id=='smiling_mask' then return '商店删牌服务固定为50金币。' end
        local definition = find(ctx.self.run.data.relics.relics, id)
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
                    local status = find(ctx.self.run.data.statuses.statuses, effect.status)
                    parts[#parts + 1] = "获得 " .. value .. " 层" .. (status and status.name or effect.status)
                end
            end
        end
        describeRelicEffects()
        if #parts == 0 then return "" end
        return (triggers[definition.trigger] or "") .. table.concat(parts, "，") .. "。"
    end

    ctx.skinFaces={}

    ctx.artFaces={}

    function ctx.fillCard(box, id, upgraded, look)
        look = look or {}
        local definition, display = ctx.card(id) or {}, ctx.self.presentation[id] or {}
        local printedCost=definition.cost
        ctx.skinFaces[box]=true
        local instance=look.instance or {cardId=id,upgraded=upgraded==true}
        definition=Combat.cardDefinition({catalog={cards={[id]=definition}}},instance)
        ctx.inspectCards[box]=definition.originalV4 and {definition=definition,upgraded=instance.upgraded} or nil
        if look.inspectOnly then box:GetChild('hit'):SetVisible(definition.originalV4~=nil) end
        local kind = Theme.icon.cardArt[definition.type] and definition.type or "status"
        local function writeCardCopy()
            CardDisplay.writeTitle(box:GetChild("name"),ctx.cardName(id,false),instance.upgraded,
            definition.repeatable and (instance.upgrades or 1) or nil,box:GetChild("type"),
            typeNames[definition.type] or "")
            ctx.ink(box:GetChild("name"), Theme.cardSkin.text.title)
            local text=CardDisplay.permanentText(display,definition,instance)
            CardDisplay.writeBody(box:GetChild("description"),type(text)=='string' and text or '')
            ctx.ink(box:GetChild("description"), C.text)
        end
        writeCardCopy()
        -- Presentation costs can be strings; format the numeric rule value.
        local cost
        local function writeCardCost()
            cost = definition.cost
            if upgraded and definition.upgrade and definition.upgrade.cost ~= nil then cost = definition.upgrade.cost end
            box:GetChild("cost").text = definition.cost == -2 and "" or definition.costMode == "all_energy" and "X" or cost ~= nil and number(cost) or ""
            ctx.tint(box:GetChild("costDisc"), look.dim and C.energyEmpty or look.changed and C.positive or C.energy)
        end
        writeCardCost()
        local function writeCardArt()
            for art in pairs(Theme.icon.cardArt) do box:GetChild("art_" .. art):SetVisible(art == kind) end
            CardDisplay.writeArt(box:GetChild("art_" .. kind), definition, ctx.picture);if CardDisplay.writeNativeArt(box,definition,display.nativeArt,ctx.options,box:GetChild('art_'..kind))then ctx.artFaces[box]=true end
            ctx.tint(box:GetChild("artPlate"), look.dim and C.panelSunken or C.cardType[kind] or C.panelRaised)
        end
        writeCardArt()
        local covered=look.veil or look.stamp~=nil
        local reason=look.reason or look.stamp or '当前不可选择'
        local function writeCardFrame()
            ctx.tint(box:GetChild("border"), look.selected and C.goldBright or look.dim and C.line or C.rarity[definition.rarity] or C.line)
            ctx.tint(box:GetChild("nameBand"), C.rarityBand[definition.rarity] or C.rarityBand.basic)
            ctx.tint(box:GetChild("nameRule"), C.rarity[definition.rarity] or C.line)
            ctx.ink(box:GetChild("cost"), look.dim and C.textMuted or look.changed and C.positive or C.energy)
            CardSkin.apply(box,definition,ctx.options,{dim=look.dim,selected=look.selected,cost=cost,baseCost=look.changed and printedCost or definition.cost,
                reason=reason,overlayCovered=covered})
        end
        writeCardFrame()
        ctx.show(box:GetChild("glow"), look.selected)
        ctx.show(box:GetChild("veil"), look.veil)
        ctx.show(box:GetChild("stampPlate"), look.stamp ~= nil)
        ctx.show(box:GetChild("stamp"), look.stamp ~= nil)
        box:GetChild("stamp").text = look.stamp or ""
    end
end
return M
