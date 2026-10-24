-- Local transaction/input regressions, not original-game RNG or platform certification.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Nodes, Run, Map, C = require('abyss_nodes'), require('abyss_run'), require('abyss_map'), require('abyss_combat')
local UI, Layout, Presentation = require('abyss_node_ui'), require('abyss_ui_layout'), require('abyss_presentation')
local data = require('abyss_data')
local cursor = {CursorEnter='enter', CursorExit='exit', CursorDown='down', CursorUp='up', CursorEndDrag='endDrag'}
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
end
local function same(a, b)
    assert(type(a) == type(b), 'state type changed')
    if type(a) ~= 'table' then assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, 'state key missing') end
end
local function rejected(run, map, command, reason)
    local before = C.copy({run=run, map=map})
    local ok, why = command()
    assert(ok == false, 'stale or unavailable purchase must be rejected')
    if reason then assert(why == reason, tostring(why) .. ' ~= ' .. reason) end
    same({run=run, map=map}, before) -- includes every RNG stream, shelf, deck and next UID
end
local function enterShop(run, map)
    -- Navigation-only prefix: explicit supported relic/funding, real stock and RNG.
    local Routes=dofile('tests/lua/support/map_routes.lua')
    local path=Routes.to(map,function(node)return node.type=='shop'end)
    for i=1,#path-1 do
        if not run.nodeFlow then assert(Map.choose(map,path[i])) -- navigation-only initial prefix
        else
            local node=Routes.at(map,path[i]);assert(Nodes.enter(run,map,node.id))
            if run.phase=='combat'then
                for _=1,300 do
                    if run.phase~='combat'then break end
                    local target;for j,e in ipairs(run.combat.enemies)do if e.hp>0 then target=j;break end end
                    local selected;for _,card in ipairs(run.combat.hand)do if C.canPlay(run.combat,card.uid,target)then selected=card;if C.cardDefinition(run.combat,card).type=='attack'then break end end end
                    if selected then assert(Run.play(run,selected.uid,target))else assert(Run.endTurn(run))end
                end
                assert(run.phase=='reward');assert(Run.claimCardReward(run,0));dofile('tests/lua/support/finish_combat_rewards.lua')(run);assert(Nodes.completeCombat(run,map))
            elseif node.type=='event'then assert(Nodes.chooseEvent(run,'leave'))
            elseif node.type=='camp'then assert(Nodes.rest(run))
            elseif node.type=='treasure'then assert(Nodes.claimTreasure(run))
            else error('unexpected intermediate room '..node.type)end
        end
    end
    assert(Nodes.enter(run,map,path[#path]))
end
local function shop(courier)
    local run, map = Run.new(data, 42), Map.generate(data, 42)
    run.gold = 10000
    if courier then run.relics[#run.relics + 1] = 'courier' end
    enterShop(run, map)
    return run, map
end
local function duplicate()
    local run, map = shop(true)
    for _ = 1, 6 do assert(Nodes.buyCard(run, run.nodeFlow.cards[1].id)) end
    assert(run.nodeFlow.cards[1].id == 'anger' and run.nodeFlow.cards[1].price == 37)
    assert(run.nodeFlow.cards[2].id == 'anger' and run.nodeFlow.cards[2].price == 42)
    return run, map
end
local function findSpec(list, name)
    for _, spec in ipairs(list) do
        if spec.name == name then return spec end
        local found = spec.children and findSpec(spec.children, name)
        if found then return found end
    end
end
local function control(spec, parent)
    local box = {children={}, parent=parent, visible=spec.visible ~= false,
        text=spec.text and spec.text.content or '', listeners={}}
    function box:GetChild(name) return self.children[name] end
    function box:SetVisible(value) self.visible = value end
    function box:SetImage(source, id) self.imageId = id end
    function box:SetLocalScale(...) end
    function box:SetAnchoredPosition(x, y) self.position = {x, y} end
    function box:AddCursorEventListener(event, handler)
        assert(not self.listeners[event], 'duplicate native event listener')
        self.listeners[event] = handler
    end
    for _, child in ipairs(spec.children or {}) do box.children[child.name] = control(child, box) end
    return box
end
local function uiFor(run, map)
    local root = control(findSpec(Layout, 'nodePanel'))
    local ui = UI.new(root, run, map, Presentation, 'click', nil, {imageSource='static', cursorEvents=cursor})
    ui:setVisible(true)
    return ui, root
end
local function emit(root, slot, event, touch)
    local hit = root:GetChild('shopView'):GetChild('card' .. slot):GetChild('hit')
    return assert(hit.listeners[event])({touchId=touch, GetUIPos=function() return 100, 100 end})
end
local function bought(run, before, slot, price)
    assert(before.gold - run.gold == price, 'clicked slot must charge its own quote')
    assert(#run.deck == #before.deck + 1 and run.nextDeckUid == before.nextDeckUid + 1, 'exactly one permanent card UID')
    same(run.deck[#run.deck], {uid=before.nextDeckUid, cardId='anger', upgraded=false})
    for i, card in ipairs(before.deck) do same(run.deck[i], card) end
    for i, offer in ipairs(before.nodeFlow.cards) do
        if i ~= slot then same(run.nodeFlow.cards[i], offer) end
    end
    same(run.nodeFlow.relics, before.nodeFlow.relics); same(run.nodeFlow.potions, before.nodeFlow.potions)
    assert(run.shopRng.merchant.counter > before.shopRng.merchant.counter, 'selected slot must restock')
    local fresh = run.nodeFlow.cards[slot]
    assert(fresh.slot == slot and not fresh.sold)
    assert(fresh.id ~= before.nodeFlow.cards[slot].id or fresh.price ~= price, 'fixture must visibly replace selected slot')
end

for _, slot in ipairs({2, 1}) do
    test('real Courier duplicate UI buys only slot ' .. slot, function()
        local run, map = duplicate(); local ui = uiFor(run, map); local before = C.copy(run)
        assert(ui:press('shopView/card' .. slot))
        bought(run, before, slot, slot == 2 and 42 or 37)
    end)
end
test('legacy ID rejects ambiguous duplicate stock atomically', function()
    local run, map = duplicate()
    rejected(run, map, function() return Nodes.buyCard(run, 'anger') end, 'item_unavailable')
end)
test('slot API selects the expensive duplicate instead of first matching ID', function()
    local run, map = duplicate(); local before = C.copy(run)
    assert(type(Nodes.buyCardSlot) == 'function', 'explicit card-slot API is required')
    assert(Nodes.buyCardSlot(run, 2)); bought(run, before, 2, 42)
end)
test('expensive slot rejects funds sufficient only for cheaper duplicate', function()
    local run, map = duplicate(); local ui = uiFor(run, map)
    run.gold = 37 -- stale enabled UI must still revalidate the selected 42-gold quote
    rejected(run, map, function() return ui:press('shopView/card2') end, 'insufficient_gold')
    ui:render()
    rejected(run, map, function() return ui:press('shopView/card2') end, 'unavailable_action')
    assert(ui:press('shopView/card1')); assert(run.gold == 0)
end)
test('selected second-slot restock failure rolls back every resource and RNG', function()
    local run, map = duplicate(); local ui = uiFor(run, map)
    run.cardRng = {} -- same invalid authoritative-stream fault as the existing shop suite
    rejected(run, map, function() return ui:press('shopView/card2') end, 'shop_content_unavailable')
    assert(type(Nodes.buyCardSlot) == 'function', 'explicit card-slot API is required')
    rejected(run, map, function() return Nodes.buyCardSlot(run, 2) end, 'shop_content_unavailable')
end)
test('slot API rejects malformed, missing, unavailable, sold and completed offers', function()
    assert(type(Nodes.buyCardSlot) == 'function', 'explicit card-slot API is required')
    local run, map = shop()
    rejected(run, map, function() return Nodes.buyCardSlot(run) end, 'item_unavailable')
    for _, slot in ipairs({false, true, {}, '2', '', 0, -1, 1.5, 8, math.huge, -math.huge, 0/0}) do
        rejected(run, map, function() return Nodes.buyCardSlot(run, slot) end, 'item_unavailable')
    end
    rejected(run, map, function() return Nodes.buyCardSlot(run, 6) end, 'item_unavailable')
    local missing = C.copy(run); missing.nodeFlow.cards[2] = nil
    rejected(missing, map, function() return Nodes.buyCardSlot(missing, 2) end, 'item_unavailable')
    assert(Nodes.buyCardSlot(run, 1)); assert(run.nodeFlow.cards[1].sold)
    rejected(run, map, function() return Nodes.buyCardSlot(run, 1) end, 'item_unavailable')
    assert(Nodes.leaveShop(run))
    rejected(run, map, function() return Nodes.buyCardSlot(run, 2) end, 'no_pending_node')
    local fresh = Run.new(data, 42)
    rejected(fresh, map, function() return Nodes.buyCardSlot(fresh, 1) end, 'no_pending_node')
end)
test('unique legacy ID remains compatible with slot purchase', function()
    local run, map = shop(); local other = C.copy(run)
    assert(Nodes.buyCard(run, run.nodeFlow.cards[2].id))
    assert(type(Nodes.buyCardSlot) == 'function', 'explicit card-slot API is required')
    assert(Nodes.buyCardSlot(other, 2)); same(run, other)
end)
for _, boundary in ipairs({'purchase', 'external_purchase', 'render', 'overlay', 'leave', 'new_shop', 'restart'}) do
    test('old duplicate card callback and Down are rejected after ' .. boundary, function()
        local run, map = duplicate(); local ui, root = uiFor(run, map)
        local old = ui.actions['shopView/card2'].handler
        emit(root, 2, 'down', 11)
        if boundary == 'purchase' then assert(ui:press('shopView/card2'))
        elseif boundary == 'external_purchase' then assert(Nodes.buyCard(run, run.nodeFlow.cards[3].id))
        elseif boundary == 'render' then ui:render()
        elseif boundary == 'overlay' then ui:setVisible(false); ui:setVisible(true); ui:render()
        elseif boundary == 'leave' then assert(Nodes.leaveShop(run))
        elseif boundary == 'new_shop' then assert(Nodes.leaveShop(run)); enterShop(run, map)
        elseif boundary == 'restart' then run, map = duplicate(); ui.run, ui.map = run, map end
        rejected(run, map, old)
        emit(root, 2, 'up', 11)
        rejected(run, map, function() return emit(root, 2, 'click', 11) end)
        if boundary ~= 'leave' then
            ui:render()
            local price, size, gold = run.nodeFlow.cards[2].price, #run.deck, run.gold
            emit(root, 2, 'down', 12); emit(root, 2, 'up', 12)
            assert(emit(root, 2, 'click', 12), 'fresh gesture must buy current selected offer')
            assert(#run.deck == size + 1 and gold - run.gold == price)
        end
    end)
end
print('LUA_SHOP_CARD_IDENTITY ' .. passed .. ' passed; ' .. failed .. ' failed')
assert(failed == 0)
