-- A released card press must never become delayed help or eat the first target tap.
-- Exercise real Run/Combat/controller callbacks with the generated UI test fixture.
local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(why)))
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function setup(deck)
    local h,u,p,event,tap,drain,deckToggle = H.setup(deck or {'bash','strike','defend'}, {'cultist'})
    local s, slot = h.run.combat
    for i,c in ipairs(s.hand) do if c.cardId == 'bash' then slot = i; break end end
    local name = 'card' .. assert(slot)
    local hit = p:GetChild(name):GetChild('hit')
    return h,u,p,event,tap,s,name,hit,deckToggle
end
local function hidden(p) assert(not p:GetChild('statusInfo').visible, 'released/cancelled card opened help') end
local function keyword(p)
    local info = p:GetChild('statusInfo')
    assert(info.visible and info:GetChild('title').text:find('关键词',1,true), 'live card hold/hover lost help')
    assert(info:GetChild('name1').text:find('易伤',1,true))
end

-- Missing matching-release cancellation must fail these cases on the old head.
test('50ms tap remains selected without delayed help or suppressed next click', function()
    local h,u,p,event,tap,s,name = setup()
    local before = H.F.Combat.copy(s)
    event(name,'down',17); h:update(0.05); event(name,'up',17); event(name,'click',17)
    assert(u.selected ~= nil); h:update(0.31); hidden(p)
    assert(not u.suppressClick and same(s,before), 'short tap mutated rules or suppressed input')
end)
test('first enemy tap after released Bash applies exactly once', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:update(0.05); event(name,'up',17); event(name,'click',17); h:update(0.31)
    tap('enemy1',18)
    assert(s.enemies[1].hp == 44 and s.energy == 1 and #s.hand == 2, 'first target tap was swallowed')
    event('enemy1','click',18); event(name,'click',17)
    assert(s.enemies[1].hp == 44 and s.energy == 1 and #s.hand == 2, 'duplicate click replayed a card')
end)
for _, target in ipairs({'card','dragLayer'}) do
    test('stationary EndDrag on ' .. target .. ' cancels its pending help', function()
        local h,u,p,event,tap,s,name = setup()
        local before = H.F.Combat.copy(s)
        event(name,'down',17); h:update(0.05)
        local box = p:GetChild(name)
        event(target == 'card' and name or 'dragLayer','endDrag',17,box.x,box.y)
        event(name,'click',17); h:update(0.4); hidden(p)
        assert(u.selected == nil and same(s,before))
    end)
end
for _, kind in ipairs({'no_coordinates','unplayable','no_touch_id'}) do
    test('short tap cancels help in ' .. kind .. ' C-mode', function()
        local h,u,p,event,tap,s,name,hit = setup()
        if kind == 'unplayable' then s.energy=0; u:render() end
        if kind == 'no_coordinates' then
            hit.listeners.down({touchId=17}); h:update(0.05)
            hit.listeners.up({touchId=17}); hit.click({touchId=17})
        else
            local touch = 17
            if kind == 'no_touch_id' then touch=nil end
            event(name,'down',touch); h:update(0.05); event(name,'up',touch); event(name,'click',touch)
        end
        h:update(0.4); hidden(p)
        assert(s.energy == (kind == 'unplayable' and 0 or 3) and #s.hand == 3)
    end)
end
test('a genuine 350ms hold still opens help and releases without playing', function()
    local h,u,p,event,tap,s,name = setup()
    local before = H.F.Combat.copy(s)
    event(name,'down',17); h:update(0.34); hidden(p); h:update(0.02); keyword(p)
    event(name,'up',17); event(name,'click',17); h:update(0.4)
    assert(same(s,before) and u.selected == nil)
end)
for _, kind in ipairs({'no_coordinates','unplayable'}) do
    test('genuine hold still opens help in ' .. kind .. ' C-mode', function()
        local h,u,p,event,tap,s,name,hit = setup()
        if kind == 'unplayable' then s.energy=0; u:render() end
        local before = H.F.Combat.copy(s)
        if kind == 'no_coordinates' then hit.listeners.down({touchId=17}) else event(name,'down',17) end
        h:update(0.36); keyword(p)
        hit.listeners.up({touchId=17}); hit.click({touchId=17})
        assert(same(s,before) and u.selected == nil)
    end)
end
test('keyword hover is still read-only and closes on exit', function()
    local h,u,p,event,tap,s,name = setup()
    local before = H.F.Combat.copy(s)
    event(name,'enter',17); h:update(0.34); hidden(p); h:update(0.02); keyword(p)
    assert(not p:GetChild('statusInfo'):GetChild('hit').visible)
    event(name,'exit',17); hidden(p); assert(same(s,before))
end)
test('foreign Up and EndDrag do not cancel the live card hold', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:update(0.05)
    event(name,'up',18); event(name,'endDrag',18); event(name,'click',18)
    h:update(0.31); keyword(p)
    assert(s.energy == 3 and #s.hand == 3 and s.enemies[1].hp == 52)
end)
test('same touch on another card cannot cancel the held source', function()
    local h,u,p,event,tap,s,name = setup()
    local other = name == 'card1' and 'card2' or 'card1'
    event(name,'down',17); h:update(0.05); event(other,'up',17); event(other,'endDrag',17)
    h:update(0.31); keyword(p)
end)
test('coordinate-free old card release preserves newer keyword-card help', function()
    local h,u,p,event,tap,s,name,hit = setup({'bash','bash'})
    local other = p:GetChild(name == 'card1' and 'card2' or 'card1'):GetChild('hit')
    hit.listeners.down({touchId=17}); h:update(0.05)
    other.listeners.down({touchId=18}); hit.listeners.up({touchId=17}); hit.listeners.endDrag({touchId=17})
    h:update(0.36); keyword(p)
end)
test('old card release cannot cancel a newer hover tooltip', function()
    local h,u,p,event,tap,s,name,hit = setup({'bash','bash'})
    local other = name == 'card1' and 'card2' or 'card1'
    hit.listeners.down({touchId=17}); h:update(0.05); event(other,'enter',18)
    hit.listeners.up({touchId=17}); h:update(0.36); keyword(p)
    event(other,'exit',18); hidden(p)
end)
test('resize cancels held help even without release callbacks', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:update(0.05); h:resize(1600,900); h:update(0.4); hidden(p)
    assert(s.energy == 3 and #s.hand == 3)
end)
test('stale old touch after resize cannot cancel a new hold on the same slot', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:resize(1600,900); event(name,'down',18)
    event(name,'up',17); event(name,'endDrag',17); h:update(0.36); keyword(p)
end)
test('same-slot card UID replacement invalidates held help without a render', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:update(0.05)
    local slot = tonumber(name:match('%d+')); local other = slot == 1 and 2 or 1
    s.hand[slot],s.hand[other] = s.hand[other],s.hand[slot]
    h:update(0.4); hidden(p)
end)
test('deck interruption cancels help and old release but a new tap still works', function()
    local h,u,p,event,tap,s,name,hit,deckToggle = setup()
    event(name,'down',17); h:update(0.05); deckToggle()
    event(name,'up',17); event(name,'click',17); h:update(0.4); hidden(p)
    assert(u.selected == nil); tap(name,18); assert(u.selected ~= nil)
end)
test('exit cancellation blocks old help and allows a fresh Bash target tap', function()
    local h,u,p,event,tap,s,name = setup()
    local before = H.F.Combat.copy(s)
    event(name,'down',17); h:update(0.05); assert(h:openExit()); h:update(1); assert(h:closeExit())
    event(name,'up',17); event(name,'click',17); h:update(0.4); hidden(p)
    assert(u.selected == nil and same(s,before))
    tap(name,18); tap('enemy1',19); assert(s.enemies[1].hp == 44 and s.energy == 1 and #s.hand == 2)
end)
for _, boundary in ipairs({'turn','combat','run'}) do
    test(boundary .. ' identity change cancels pending card help', function()
        local h,u,p,event,tap,s,name = setup()
        event(name,'down',17); h:update(0.05)
        if boundary == 'turn' then s.turn = s.turn + 1
        elseif boundary == 'combat' then h.run.combat = H.F.Combat.copy(s)
        else h.run = H.F.Combat.copy(h.run); u.run = h.run end
        h:refresh(); h:update(0.4); hidden(p)
        event(name,'up',17); event(name,'click',17); assert(u.selected == nil)
    end)
end
test('movement cancels pending help and keeps drag targeting functional', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:update(0.05); event(name,'drag',17,300,64); h:update(0.4); hidden(p)
    event('dragLayer','up',17,300,64)
    assert(s.enemies[1].hp == 44 and s.energy == 1 and #s.hand == 2)
end)
test('release immediately before the deadline cannot fire before a delayed Click', function()
    local h,u,p,event,tap,s,name = setup()
    event(name,'down',17); h:update(0.349); event(name,'up',17)
    h:update(1); hidden(p); event(name,'click',17); assert(u.selected)
    tap('enemy1',18)
    assert(s.enemies[1].hp == 44 and s.energy == 1 and #s.hand == 2)
end)
for _, value in ipairs({0/0, math.huge, -math.huge}) do
    test('nonfinite coordinates retain cancellable C-mode: ' .. tostring(value), function()
        local h,u,p,event,tap,s,name,hit = setup()
        local point = {touchId=17, GetUIPos=function() return value,value end}
        hit.listeners.down(point); h:update(0.05); hit.listeners.up(point)
        h:update(0.4); hidden(p); hit.click(point); assert(u.selected)
        tap('enemy1',18)
        assert(s.enemies[1].hp == 44 and s.energy == 1 and #s.hand == 2)
    end)
end
for _, boundary in ipairs({'battle_phase','run_phase'}) do
    test(boundary .. ' invalidates held help without a render', function()
        local h,u,p,event,tap,s,name = setup()
        event(name,'down',17); h:update(0.05)
        if boundary == 'battle_phase' then s.phase='enemy' else h.run.phase='map' end
        u:update(0.4); hidden(p)
    end)
end
test('old coordinate-free release preserves newer hover on the same control', function()
    local h,u,p,event,tap,s,name,hit = setup()
    local before = H.F.Combat.copy(s)
    hit.listeners.down({touchId=17}); h:update(0.05); event(name,'enter',18)
    hit.listeners.up({touchId=17}); hit.listeners.endDrag({touchId=17})
    h:update(0.36); keyword(p); event(name,'exit',18); hidden(p)
    assert(same(s,before))
end)
print('LUA_CARD_HELP_RELEASE ' .. passed .. ' passed; ' .. failed .. ' failed')
assert(failed == 0, 'card-help ownership regressions failed')
