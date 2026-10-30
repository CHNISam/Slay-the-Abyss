package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local H = dofile("tests/lua/support/battle_action_fixture.lua")
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local Combat = H.F.Combat
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
local function setup(effects, kind)
    local enemyId,moveId='fat_gremlin','fat_gremlin_1'
    if effects then
        enemyId,moveId='jaw_worm','jaw_worm_1'
        if kind=='debuff' then enemyId,moveId='green_louse','green_louse_2'
        elseif kind=='defend' then enemyId,moveId='jaw_worm','jaw_worm_3'
        else for _,effect in ipairs(effects)do if effect.op=='damage' and (effect.times or 1)>1 then enemyId,moveId='book_of_stabbing','multi_stab' end end end
    end
    local h, u, p, emit, tap, drain = H.setup({"strike", "defend"}, {enemyId})
    if effects then
        -- Explicit effect-arithmetic fixture: retain a real source move identity.
        -- A fresh battle owner creates the source intent after controlled setup.
        local battle=Combat.copy(h.run.combat)
        local enemy=battle.enemies[1]
        enemy.ai,enemy.intentIndex=nil,1
        enemy.intents={{id=moveId,kind=kind or 'attack',effects=effects}}
        h.run.combat=battle
    end
    return h, u, p, tap, drain
end
-- Playback compares every committed field on every 0.05s frame. These two
-- multi-enemy cases need only these stock definitions, not the whole catalog.
-- Keep all rules/statuses and enter the real Combat.new, host and feedback path.
local playbackData = {rules=H.F.Data.rules, statuses=H.F.Data.statuses,
    cards={cards={}}, enemies={enemies={}}}
for _, card in ipairs(H.F.Data.cards.cards) do
    if card.id == "defend" then playbackData.cards.cards[#playbackData.cards.cards+1] = card end
end
for _, enemy in ipairs(H.F.Data.enemies.enemies) do
    if enemy.id == "fat_gremlin" or enemy.id == "jaw_worm" or enemy.id == "green_louse" then
        playbackData.enemies.enemies[#playbackData.enemies.enemies+1] = enemy
    end
end
assert(#playbackData.cards.cards == 1 and #playbackData.enemies.enemies == 3, "playback dependencies missing")
local function playbackSetup(deck, enemies)
    local h, u, p, emit, tap, drain, deckToggle, root = H.setup(deck, enemies)
    h.run.combat = Combat.new(playbackData, {deck=deck, enemies=enemies})
    h:refresh()
    return h, u, p, emit, tap, drain, deckToggle, root
end
local function refresh(h, p, tap)
    local before = Combat.copy(h.run.combat)
    h:refresh(); h:refresh(); tap("enemy1", 11)
    local detail = inspectDetails(h.battleUI, p)
    same(h.run.combat, before)
    -- Ordered preview arithmetic belongs to the complete detail projection;
    -- source world damage deliberately does not pre-execute self buffs.
    local face=require('abyss_battle_intent_view').intentView(h.run.combat,1)
    for _,row in ipairs(face.rows or {})do
        assert(detail:find(row.text,1,true),'actual tooltip lost ordered preview row: '..row.text)
    end
    return face.value, detail
end
local function rejects(h, reason)
    local before = Combat.copy(h.run.combat)
    local ok, why = pcall(function()
        h:refresh()
        -- Overflow belongs to ordered tooltip projection, not source world
        -- damage which must never pre-apply the future status effect.
        h.battleUI:showStatus(1)
    end)
    eq(ok, false, "refresh must reject")
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
    playbackSetup=playbackSetup, playbackData=playbackData}
