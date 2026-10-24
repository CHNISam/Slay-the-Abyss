package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local H = dofile("tests/lua/support/battle_action_fixture.lua")
local Combat = H.F.Combat
local passed, failed = 0, 0
local originalPrint, recoveryCount = print, 0
print = function(...)
    local message = tostring(select(1, ...))
    if message:find("ABYSS_FEEDBACK recovered", 1, true) then recoveryCount = recoveryCount + 1 end
    originalPrint(...)
end
local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function same(actual, expected, path)
    path = path or "combat"
    eq(type(actual), type(expected), path)
    if type(actual) ~= "table" then eq(actual, expected, path); return end
    for key, value in pairs(actual) do same(value, expected[key], path .. "." .. tostring(key)) end
    for key in pairs(expected) do assert(actual[key] ~= nil, path .. "." .. tostring(key)) end
end
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(why)))
end
local function setup(effects, kind)
    local h, u, p, emit, tap, drain = H.setup({"strike", "defend"}, {"fat_gremlin"})
    if effects then
        -- Synthetic supported sequences isolate ordering, not new stock enemy moves.
        local enemy = h.run.combat.enemies[1]
        enemy.ai, enemy.intentIndex = nil, 1
        enemy.intents = {{id="preview_order", kind=kind or "attack", effects=effects}}
    end
    return h, u, p, tap, drain
end
local function refresh(h, p, tap)
    local before = Combat.copy(h.run.combat)
    h:refresh(); h:refresh(); tap("enemy1", 11)
    same(h.run.combat, before)
    return p:GetChild("enemy1"):GetChild("intent").text, p:GetChild("notice").text
end
local function rejects(h, reason)
    local before = Combat.copy(h.run.combat)
    local ok, why = pcall(function() h:refresh() end)
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
    local recoveries = recoveryCount
    for _ = 1, 400 do
        if not u.busy then break end
        if observe then observe(u.feedback.current, u.displayBattle) end
        h:update(0.05)
        eq(h.run.combat, s); eq(s.player, player); eq(s.enemies[1], enemy); eq(s.events, events)
        if u.busy then same(s, committed) end
    end
    assert(not u.busy, "feedback remained stuck")
    eq(recoveryCount, recoveries, "playback must not need recovery")
    committed.events = {}
    same(s, committed)
end

test("stock Fat Gremlin refresh and real end-turn agree at Weak upper bound with Artifact", function()
    local h, u, p, tap, drain = setup()
    local s = h.run.combat
    Combat.addStatus(s.player, "weak", 2147483647)
    Combat.addStatus(s.player, "artifact", 1)
    local copy = Combat.copy(s)
    assert(Combat.endTurn(copy))
    eq(copy.player.statuses.weak, 2147483646); eq(copy.player.statuses.artifact, 0)
    local compact, detail = refresh(h, p, tap)
    eq(compact, "4"); assert(detail:find("虚弱 1", 1, true))
    assert(u:showStatus(0))
    eq(p:GetChild("statusInfo"):GetChild("name2").text, "虚弱 2147483647 · 减益")
    local recoveries = recoveryCount
    tap("hero", 12); tap("endTurn", 13); drain()
    eq(recoveryCount, recoveries, "the complete boundary playback must not need recovery")
    eq(s.player.statuses.weak, 2147483646); eq(s.player.statuses.artifact, 0)
    eq(p:GetChild("hero"):GetChild("statusRow"):GetChild("count1").text, "2147483646")
end)

test("ordinary stock values retain status details, card preview and command behavior", function()
    local h, u, p, tap, drain = setup()
    local s = h.run.combat
    Combat.addStatus(s.player, "weak", 2); Combat.addStatus(s.player, "artifact", 1)
    local before = Combat.copy(s)
    eq(refresh(h, p, tap), "4")
    for _, card in ipairs(s.hand) do
        local preview = Combat.cardPreview(s, card)
        eq(preview[1].low, card.cardId == "strike" and 4 or 5)
    end
    assert(u:showStatus(0))
    local info = p:GetChild("statusInfo")
    eq(info:GetChild("name1").text, "人工制品 1 · 增益")
    eq(info:GetChild("name2").text, "虚弱 2 · 减益")
    same(s, before)
    tap("hero", 21); tap("endTurn", 22); drain()
    eq(s.player.statuses.weak, 1); eq(s.player.statuses.artifact, 0)
    eq(p:GetChild("hero"):GetChild("statusRow"):GetChild("count1").text, "1")
end)

test("neighboring boundary and stock non-applying intent remain valid", function()
    local h, _, p, tap = setup()
    Combat.addStatus(h.run.combat.player, "weak", 2147483646)
    Combat.addStatus(h.run.combat.player, "artifact", 1)
    eq(refresh(h, p, tap), "4")
    local jaw, _, panel, _, jawTap = H.setup({"defend"}, {"jaw_worm"})
    Combat.addStatus(jaw.run.combat.player, "weak", 2147483647)
    Combat.addStatus(jaw.run.combat.player, "artifact", 1)
    eq(refresh(jaw, panel, jawTap), "11")
end)

test("Artifact gates each supported ordinary debuff before either recipient's stack arithmetic", function()
    for _, status in ipairs({"weak", "vulnerable", "frail", "poison", "entangled"}) do
        for _, op in ipairs({"applyStatus", "gainStatus"}) do
            local h, _, p, tap = setup({{op=op, status=status, value=1}}, "debuff")
            local s = h.run.combat
            local actor = op == "gainStatus" and s.enemies[1] or s.player
            Combat.addStatus(actor, status, 2147483647); Combat.addStatus(actor, "artifact", 1)
            refresh(h, p, tap)
            local copy = resolve(s)
            local after = op == "gainStatus" and copy.enemies[1] or copy.player
            eq(after.statuses[status], 2147483647); eq(after.statuses.artifact, 0)
        end
    end
end)

test("unblocked true overflow remains visible and leaves the live state untouched", function()
    local h = setup()
    Combat.addStatus(h.run.combat.player, "weak", 2147483647)
    rejects(h, "status stack overflow")
    local ok, why = pcall(Combat.endTurn, Combat.copy(h.run.combat))
    eq(ok, false); assert(tostring(why):find("status stack overflow", 1, true))
end)

test("repeated applications spend separate Artifact charges and expose overflow when exhausted", function()
    for _, charges in ipairs({1, 2}) do
        local h, _, p, tap = setup({{op="applyStatus", status="weak", value=1},
            {op="applyStatus", status="weak", value=1}}, "debuff")
        Combat.addStatus(h.run.combat.player, "weak", 2147483647)
        Combat.addStatus(h.run.combat.player, "artifact", charges)
        if charges == 1 then rejects(h, "status stack overflow")
        else refresh(h, p, tap); eq(resolve(h.run.combat).player.statuses.artifact, 0) end
    end
end)

test("damage between repeated Vulnerable applications observes the consumed copied charge", function()
    local h, _, p, tap = setup({{op="applyStatus", status="vulnerable", value=1},
        {op="damage", value=10}, {op="applyStatus", status="vulnerable", value=1}, {op="damage", value=10}})
    Combat.addStatus(h.run.combat.player, "artifact", 1)
    local compact, detail = refresh(h, p, tap)
    eq(compact, "10")
    assert(detail:find("10 点伤害", 1, true)); assert(detail:find("15 点伤害", 1, true))
    local copy, hits = resolve(h.run.combat), {}
    for _, event in ipairs(copy.events) do if event.kind == "damage" then hits[#hits+1] = event.detail.amount end end
    eq(hits[1], 10); eq(hits[2], 15); eq(copy.player.statuses.vulnerable, 1)
end)

test("self buffs and target debuffs consume only their own actor's Artifact", function()
    local h, _, p, tap = setup({{op="gainStatus", status="weak", value=1},
        {op="applyStatus", status="vulnerable", value=1}, {op="damage", value=10, times=2}})
    local s = h.run.combat
    Combat.addStatus(s.player, "artifact", 1); Combat.addStatus(s.enemies[1], "artifact", 1)
    eq(refresh(h, p, tap), "10×2")
    local copy = resolve(s)
    eq(copy.player.statuses.artifact, 0); eq(copy.enemies[1].statuses.artifact, 0)
    eq(copy.player.hp, s.player.hp - 20)
end)

test("signed power type depends on incoming amount including zero, not current total", function()
    for _, row in ipairs({
        {status="strength", amount=-2, want="15", tail={op="damage", value=10}},
        {status="dexterity", amount=-2, want="15", tail={op="block", value=10}},
        {status="strength", amount=0, second=-2, want="13", tail={op="damage", value=10}},
        {status="dexterity", amount=0, second=-2, want="13", tail={op="block", value=10}},
    }) do
        local effects = {{op="gainStatus", status=row.status, value=row.amount}}
        if row.second then effects[#effects+1] = {op="gainStatus", status=row.status, value=row.second} end
        effects[#effects+1] = row.tail
        local h, _, p, tap = setup(effects, row.tail.op == "block" and "defend" or "attack")
        Combat.addStatus(h.run.combat.enemies[1], row.status, 5)
        Combat.addStatus(h.run.combat.enemies[1], "artifact", 1)
        eq(refresh(h, p, tap), row.want)
    end
end)

test("positive self buff preserves Artifact for the later debuff", function()
    local h, _, p, tap = setup({{op="gainStatus", status="strength", value=2},
        {op="gainStatus", status="weak", value=1}, {op="damage", value=10}})
    Combat.addStatus(h.run.combat.enemies[1], "strength", -4)
    Combat.addStatus(h.run.combat.enemies[1], "artifact", 1)
    eq(refresh(h, p, tap), "8")
    local copy = resolve(h.run.combat)
    eq(copy.enemies[1].statuses.strength, -2); eq(copy.enemies[1].statuses.artifact, 0)
end)

test("without Artifact ordered status modifiers still reach later damage and block", function()
    local h, _, p, tap = setup({{op="gainStatus", status="strength", value=-2},
        {op="gainStatus", status="weak", value=1}, {op="damage", value=10},
        {op="gainStatus", status="dexterity", value=3}, {op="gainStatus", status="frail", value=1},
        {op="block", value=10}})
    local compact, detail = refresh(h, p, tap)
    eq(compact, "6"); assert(detail:find("格挡 9", 1, true))
    eq(resolve(h.run.combat).enemies[1].block, 9)
end)

test("Artifact does not suppress invalid power amounts before core validation", function()
    for _, value in ipairs({-1, 0.5, math.huge}) do
        local h = setup({{op="applyStatus", status="weak", value=value}}, "debuff")
        Combat.addStatus(h.run.combat.player, "artifact", 1)
        rejects(h, "invalid status amount")
    end
end)

test("each enemy keeps its executed face while later enemies still see new statuses", function()
    local h, u, p, _, tap = H.setup({"defend"}, {"fat_gremlin", "jaw_worm"})
    local s = h.run.combat
    for _, enemy in ipairs(s.enemies) do enemy.ai, enemy.intentIndex = nil, 1 end
    s.enemies[1].intents = {{id="expose", kind="debuff", effects={{op="applyStatus", status="vulnerable", value=1}}}}
    s.enemies[2].intents = {{id="strike", kind="attack", effects={{op="gainStatus", status="strength", value=2}, {op="damage", value=10}}}}
    h:refresh(); eq(p:GetChild("enemy2"):GetChild("intent").text, "12")
    tap("endTurn", 31)
    local sawExposed, sawStrength, sawSecondIntent = false, false, false
    drainChecked(h, u, function(entry, frame)
        if entry.kind == "status" and entry.detail.status == "vulnerable" then
            sawExposed = true
            eq(p:GetChild("enemy2"):GetChild("intent").text, "18", "unacted enemy must see Vulnerable")
        elseif entry.kind == "intent" and entry.detail.enemy == s.enemies[2].id then
            sawSecondIntent = true; eq(p:GetChild("enemy2"):GetChild("intent").text, "18")
        elseif entry.kind == "status" and entry.detail.status == "strength" then
            sawStrength = true; eq(frame.enemies[2].statuses.strength, 2)
            eq(p:GetChild("enemy2"):GetChild("intent").text, "18", "completed self buff must not be forecast twice")
        end
    end)
    assert(sawExposed and sawSecondIntent and sawStrength)
    eq(s.player.hp, s.player.maxHp - 18)
    eq(p:GetChild("enemy2"):GetChild("intent").text, "21", "new player phase must preview the next action")
    tap("endTurn", 32)
    local sawNextAction = false
    drainChecked(h, u, function(entry)
        if entry.kind == "status" and entry.detail.status == "strength" then
            sawNextAction = true; eq(p:GetChild("enemy2"):GetChild("intent").text, "21")
        end
    end)
    assert(sawNextAction)
    eq(s.player.hp, s.player.maxHp - 39)
    eq(p:GetChild("enemy2"):GetChild("intent").text, "24")
end)

test("two stock applying enemies exhaust exactly two charges without historical-frame recovery", function()
    local h, u, p, _, tap = H.setup({"defend"}, {"fat_gremlin", "fat_gremlin"})
    local s = h.run.combat
    Combat.addStatus(s.player, "weak", 2147483647); Combat.addStatus(s.player, "artifact", 2)
    h:refresh(); tap("endTurn", 41)
    local blocks = {}
    drainChecked(h, u, function(entry, frame)
        if entry.kind == "status" and entry.detail.status == "artifact" then
            blocks[frame.player.statuses.artifact] = true
            eq(p:GetChild("enemy1"):GetChild("intent").text, "4")
            eq(p:GetChild("enemy2"):GetChild("intent").text, "4")
        end
    end)
    assert(blocks[1] and blocks[0])
    eq(s.player.statuses.artifact, 0); eq(s.player.statuses.weak, 2147483646)
end)

test("cancelled playback and replacement battle cannot retain an old actor's intent", function()
    local h, u, p, tap = setup({{op="gainStatus", status="strength", value=2}, {op="damage", value=10}})
    h:refresh(); tap("endTurn", 51)
    for _ = 1, 100 do
        if u.feedback.current.kind == "intent" then break end
        h:update(0.05)
    end
    eq(u.feedback.current.kind, "intent")
    eq(p:GetChild("enemy1"):GetChild("intent").text, "12")
    u.feedback:cancel()
    assert(not u.busy)
    eq(p:GetChild("enemy1"):GetChild("intent").text, "14")
    h.run.combat = Combat.new(H.F.Data, {deck={"defend"}, enemies={"fat_gremlin"}})
    Combat.addStatus(h.run.combat.enemies[1], "strength", 3)
    h:refresh(); eq(p:GetChild("enemy1"):GetChild("intent").text, "7")
    Combat.addStatus(h.run.combat.player, "weak", 2147483647)
    rejects(h, "status stack overflow")
end)

print("LUA_INTENT_ARTIFACT_PREVIEW " .. passed .. " passed; " .. failed .. " failed")
print = originalPrint
assert(failed == 0, "Intent Artifact preview failures: " .. failed)
