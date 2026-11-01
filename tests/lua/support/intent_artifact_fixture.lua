local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local H = dofile("tests/lua/support/battle_action_fixture.lua")
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local Combat = H.F.Combat
local IntentView=require("abyss_battle_intent_view")
local passed, failed = 0, 0
local originalPrint, counters = print, {recoveries=0}
print = function(...)
    local message = tostring(select(1, ...))
    if message:find("ABYSS_FEEDBACK recovered", 1, true) then counters.recoveries = counters.recoveries + 1 end
    originalPrint(...)
end
local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end
-- Compare every field on every call. Successful recursion creates no diagnostic
-- strings; only a real mismatch builds its path while unwinding.
local function difference(actual, expected)
    if type(actual) ~= type(expected) then
        return ": expected type " .. type(expected) .. ", got " .. type(actual)
    end
    if type(actual) ~= "table" then
        if actual ~= expected then return ": expected " .. tostring(expected) .. ", got " .. tostring(actual) end
        return nil
    end
    for key, value in pairs(actual) do
        local wanted = expected[key]
        -- Still visit every field on every frame. Equal scalar leaves need no
        -- recursive Lua call; tables always recurse, including shared aliases.
        if type(value) == "table" or value ~= wanted then
            local mismatch = difference(value, wanted)
            if mismatch then return "." .. tostring(key) .. mismatch end
        end
    end
    for key in pairs(expected) do
        if actual[key] == nil then return "." .. tostring(key) .. ": missing value" end
    end
end
local function same(actual, expected, path)
    local mismatch = difference(actual, expected)
    assert(not mismatch, mismatch and (path or "combat") .. mismatch)
end
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(why)))
end
-- Keep every rule/status and all actual deck/constructor dependencies. Copying
-- the full unrelated source catalog in each frame does not strengthen these cases.
-- Keep all rules/statuses and enter the real Combat.new, host and feedback path.
local playbackData = {rules=H.F.Data.rules, statuses=H.F.Data.statuses,
    cards={cards={}}, enemies={enemies={}}}
for _, card in ipairs(H.F.Data.cards.cards) do
    if card.id == "defend" or card.id == "strike" then playbackData.cards.cards[#playbackData.cards.cards+1] = card end
end
for _, enemy in ipairs(H.F.Data.enemies.enemies) do
    if enemy.id == "fat_gremlin" or enemy.id == "jaw_worm" or enemy.id == "green_louse" then
        playbackData.enemies.enemies[#playbackData.enemies.enemies+1] = enemy
    end
end
assert(#playbackData.cards.cards == 2 and #playbackData.enemies.enemies == 3, "playback dependencies missing")
local function setup(effects, kind)
    -- Synthetic effect sequences keep legal source constructor/setMove metadata.
    -- Their ordered tooltip forecast is distinct from the source displayed face.
    local source=kind=="debuff" and {"green_louse","green_louse_2"}
        or kind=="defend" and {"jaw_worm","jaw_worm_3"}
        or {"fat_gremlin","fat_gremlin_1"}
    local h, u, p, emit, tap, drain = H.setup({"strike", "defend"}, {source[1]})
    h.run.combat=Combat.new(playbackData,{deck={"strike","defend"},enemies={source[1]}})
    if effects then
        -- Synthetic supported sequences isolate ordering, not new stock enemy moves.
        -- First native render follows synthetic setup; later refreshes retain
        -- the source selected/displayed distinction.
        local enemy = h.run.combat.enemies[1]
        enemy.ai, enemy.intentIndex = nil, 1
        enemy.intents = {{id=source[2], kind=kind or "attack", effects=effects}}
    end
    return h, u, p, tap, drain
end
local function playbackSetup(deck, enemies)
    local h, u, p, emit, tap, drain, deckToggle, root = H.setup(deck, enemies)
    h.run.combat = Combat.new(playbackData, {deck=deck, enemies=enemies})
    -- Caller finishes synthetic selected-move setup before first native render.
    return h, u, p, emit, tap, drain, deckToggle, root
end
local function refresh(h, p, tap)
    local before = Combat.copy(h.run.combat)
    h:refresh(); h:refresh(); tap("enemy1", 11)
    local detail = inspectDetails(h.battleUI, p)
    same(h.run.combat, before)
    local box,_,entry=monsterControl(p,"enemy1")
    eq(entry.actor,h.run.combat.enemies[1],"native actor identity")
    assert(box.alive~=false,"native intent control must remain live")
    -- Preserve the original ordered-effect preview contract; the world face is
    -- createIntent/applyPowers state, covered separately by playback assertions.
    local forecast=IntentView.intentView(h.run.combat,1).value
    same(h.run.combat,before)
    return forecast, detail
end
local function rejects(h, reason)
    local before = Combat.copy(h.run.combat)
    local ok, why = pcall(function()
        h:refresh()
        -- Source world intent is cached between source refresh events. The
        -- read-only details still must expose an invalid ordered projection.
        assert(h.battleUI:showStatus(1),"intent details did not open")
    end)
    eq(ok, false, "read-only intent details must reject")
    assert(tostring(why):find(reason, 1, true), tostring(why))
    same(h.run.combat, before)
end
local function resolve(s)
    local copy = Combat.copy(s)
    copy.events = {}
    Combat.applyEffects(copy, Combat.intent(copy, 1).effects, copy.enemies[1], copy.player)
    return copy
end
local function drainChecked(h, u, observe)
    local s, events = h.run.combat, h.run.combat.events
    local player, enemy, committed = s.player, s.enemies[1], Combat.copy(s)
    local recoveries = counters.recoveries
    for _ = 1, 400 do
        if not u.busy then break end
        if observe then observe(u.feedback.current, u.displayBattle) end
        h:update(0.05)
        eq(h.run.combat, s); eq(s.player, player); eq(s.enemies[1], enemy); eq(s.events, events)
        if u.busy then same(s, committed) end
    end
    assert(not u.busy, "feedback remained stuck")
    eq(counters.recoveries, recoveries, "playback must not need recovery")
    committed.events = {}
    same(s, committed)
end

local function finish(label)
    print(label .. " " .. passed .. " passed; " .. failed .. " failed")
    print = originalPrint
    assert(failed == 0, "Intent Artifact failures: " .. failed)
end
return {H=H, Combat=Combat, counters=counters, eq=eq, same=same, test=test, setup=setup,
    refresh=refresh, rejects=rejects, resolve=resolve, drainChecked=drainChecked, finish=finish,
    playbackSetup=playbackSetup, playbackData=playbackData,
    forecast=function(battle,index)return IntentView.intentView(battle,index or 1).value end}
