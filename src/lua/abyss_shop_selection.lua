-- Presentation state from ShopScreen's hover and touchscreen-confirm paths.
-- Offers remain owned by the current run; this module never changes inventory.
local Theme = require('abyss_theme')
local L = Theme.layout.nativeNode.shop
local M = {}
local integer=require('abyss_numbers').integer

function M.new(owner, root, options)
    local state = { entries = {}, scales = {} }
    local function mobile() return options.touchScreen and options.touchScreen() == true end
    local function current(q)
        if not q or not owner.visible or owner.run ~= q.run or owner.map ~= q.map
            or owner.mode ~= 'main' or owner.run.phase ~= 'node' or owner.run.nodeFlow ~= q.flow
            or q.flow.complete then return false end
        local offer = q.flow[q.category] and q.flow[q.category][q.slot]
        return offer == q.offer and not offer.sold and not offer.unavailable
            and offer.id == q.id and offer.price == q.price and offer.upgraded == q.upgraded
    end
    local function observe(q)
        if not q or q.retired then return false end
        if not current(q) then q.retired=true;return false end
        return true
    end
    function state:clear()
        self.selected, self.focus = nil, nil
        self:paint(1)
    end
    function state:begin()
        self.entries = {}
        self.focus = nil
        if self.selected and (not observe(self.selected) or owner.run.gold < self.selected.price) then self.selected = nil end
    end
    function state:bind(key, category, slot, handler, name, description)
        local flow = owner.run.nodeFlow
        local offer = flow[category][slot]
        local q = {key=key,category=category,slot=slot,offer=offer,id=offer.id,price=offer.price,
            upgraded=offer.upgraded,run=owner.run,map=owner.map,flow=flow,
            handler=handler,name=name,description=description}
        self.entries[key] = q
        return function()
            if not observe(q) then return false, 'stale_action' end
            if not mobile() then return handler() end
            if self.selected and self.selected.key == key then self.selected = nil else self.selected = q end
            owner:render()
            return true
        end, function() return observe(q) end
    end
    function state:footer()
        local selected = self.selected
        if not selected or not observe(selected) then self.selected = nil; return end
        local q = self.entries[selected.key]
        if not q or q.offer ~= selected.offer or q.price ~= selected.price then self.selected = nil; return end
        local function buy()
            if self.selected ~= selected or not observe(selected) then return false,'stale_action' end
            self.selected = nil
            return q.handler()
        end
        return '取消选择', '购买 · ' .. integer(selected.price), true, buy, nil,
            function() return self.selected == selected and observe(selected) end
    end
    function state:cancel()
        if not self.selected then return false end
        self:clear(); owner:render(); return true
    end
    function state:enter(key)
        if mobile() or not owner.visible or owner.mode ~= 'main' then return end
        local q = self.entries[key]
        -- Insufficient funds must not prevent reading a card or item.
        if q and not q.offer.sold and not q.offer.unavailable then self.focus = key end
    end
    function state:exit(key) if self.focus == key then self.focus = nil end end
    function state:isSelected(key) return self.selected and self.selected.key == key end
    function state:paint(dt)
        local focused = self.selected and self.selected.key or self.focus
        local cardFocus = focused and focused:match('card%d+$') ~= nil
        local amount = math.min(1, math.max(0, dt) / L.hoverDuration)
        for i, x in ipairs(L.columns) do
            local key = 'shopView/card' .. i
            local target = focused == key and L.hoverScale or 1
            local scale = (self.scales[i] or 1) + (target - (self.scales[i] or 1)) * amount
            self.scales[i] = scale
            local shift = i > 5 and cardFocus and L.focusRowShift or 0
            local box = root:GetChild('card' .. i)
            box:SetLocalScale(scale, scale, 1)
            box:SetAnchoredPosition(x, L.cardRows[i] - shift)
            box:GetChild('glow'):SetVisible(focused == key)
            root:GetChild('price' .. i):SetAnchoredPosition(x,
                L.priceRows[i] - shift - (scale - 1) * Theme.layout.card.size[2] / 2)
        end
        local q = focused and self.entries[focused]
        local detail = root:GetChild('detail')
        local show = q ~= nil and q.category ~= 'cards'
        detail:SetVisible(show)
        if show then
            detail:GetChild('name').text = q.name
            detail:GetChild('description').text = q.description
        end
    end
    function state:update(dt)
        if self.selected and (not observe(self.selected) or owner.run.gold < self.selected.price) then
            self:clear(); owner:render(); return
        end
        if not owner.visible or owner.mode ~= 'main' or not owner.run.nodeFlow
            or owner.run.nodeFlow.type ~= 'shop' then self.focus = nil end
        if self.focus and not current(self.entries[self.focus]) then self.focus = nil end
        self:paint(dt)
    end
    return state
end
return M
