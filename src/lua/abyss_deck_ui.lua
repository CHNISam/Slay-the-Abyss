-- Read-only permanent-deck snapshot. No Run commands, combat piles or RNG.
local Combat = require("abyss_combat")
local Theme = require("abyss_theme")
local M = {}
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }

function M.new(root, presentation, clickEvent, platform, onClose)
    local self = { root = root, visible = false, generation = 0 }
    local grid = assert(root:GetChild("grid"), "missing deck grid")
    local function colour(value) return platform.color(value.r, value.g, value.b, value.a) end
    local function tint(control, value) control.imageColor = colour(value) end
    local function fill(control, instance, catalog)
        local definition = Combat.cardDefinition({catalog=catalog}, instance)
        local display = assert(presentation[instance.cardId], "missing deck presentation " .. instance.cardId)
        local face = control:GetChild("face")
        face:GetChild("name").text = display.name .. (instance.upgraded and "＋" or "")
        face:GetChild("name").fontColor = colour(instance.upgraded and Theme.color.positive or Theme.color.text)
        -- Permanent cards carry no combat modifiers: fill live tokens with their own values.
        local text = instance.upgraded and display.upgradeText or display.text
        local live = instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
        if live then
            text = live:gsub("{effects%.(%d+)%.value}", function(index)
                return string.format("%.0f", definition.effects[tonumber(index) + 1].value)
            end)
        end
        face:GetChild("label").text = text
        face:GetChild("type").text = typeNames[definition.type] or definition.type
        face:GetChild("cost").text = definition.cost == -2 and "" or definition.costMode == "all_energy" and "X" or tostring(definition.cost)
        tint(face:GetChild("border"), Theme.color.rarity[definition.rarity] or Theme.color.line)
        tint(face:GetChild("artPlate"), Theme.color.cardType[definition.type] or Theme.color.panelRaised)
        face:GetChild("art"):SetImage(platform.imageSource, Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
        control:GetChild("uid").text = "UID " .. instance.uid
        control:SetVisible(true)
    end
    function self:open(run)
        if self.visible then return false end
        self.generation = self.generation + 1
        local generation = self.generation
        -- A copied permanent instance never acquires temporary hand cost/growth/status.
        local cards, catalog = Combat.copy(run.deck), {cards={}}
        for _, card in ipairs(run.data.cards.cards) do catalog.cards[card.id] = card end
        self.visible, self.run, self.cards, self.catalog = true, run, cards, catalog
        self.indexBase, self.pending, self.calibrating = nil, false, true
        root:SetVisible(true)
        root:SetAsLastSibling()
        root:GetChild("title").text = "卡组 · " .. #cards .. " 张"
        grid.scrollProgress = 0
        -- Official API leaves index origin unspecified. A single-item callback
        -- reveals it without assuming a Lua (1) or native (0) convention. Fill
        -- the full list on the next update, outside the possibly deferred callback.
        grid:RefreshItems(#cards > 0 and 1 or 0, function(control, index)
            if not self.visible or self.generation ~= generation or not self.calibrating then return end
            self.indexBase, self.pending = index, true
            fill(control, cards[1], catalog)
        end)
        return true
    end
    function self:update()
        if not self.visible or not self.pending then return end
        self.pending, self.calibrating = false, false
        local generation, cards, catalog, base = self.generation, self.cards, self.catalog, self.indexBase
        grid:RefreshItems(#cards, function(control, index)
            if not self.visible or self.generation ~= generation then return end
            local instance = cards[index - base + 1]
            if instance then fill(control, instance, catalog) else control:SetVisible(false) end
        end)
    end
    function self:close()
        if not self.visible then return false end
        self.generation = self.generation + 1
        self.visible, self.pending, self.calibrating, self.run, self.cards, self.catalog = false, false, false, nil, nil, nil
        root:SetVisible(false)
        grid:RefreshItems(0, function() end)
        return true
    end
    root.disableCursorEventPassthrough = true
    root:GetChild("blocker"):AddCursorEventListener(clickEvent, function() return true end)
    root:GetChild("close"):GetChild("hit"):AddCursorEventListener(clickEvent, onClose)
    root:SetVisible(false)
    return self
end
return M
