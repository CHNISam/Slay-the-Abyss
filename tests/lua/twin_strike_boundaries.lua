package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, data = require("abyss_combat"), require("abyss_data")
local passed, failed = 0, 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function test(name, fn)
    local ok, reason = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(reason)))
end
-- Independent fixed expectations: Twin Strike queues two separate attacks,
-- each 5 (7 upgraded), with normal per-hit modifiers and retaliation.
-- Fixtures isolate the card, not natural acquisition or platform execution.
local cases = {
    {name="positive Strength applies to each hit", strength=3, hits={{8,0},{8,0}}, upgradedHits={{10,0},{10,0}}},
    {name="negative Strength applies to each hit", strength=-3, hits={{2,0},{2,0}}, upgradedHits={{4,0},{4,0}}},
    {name="Weak floors each hit rather than the combined total", weak=1, hits={{3,0},{3,0}}, upgradedHits={{5,0},{5,0}}},
    {name="Strength Weak and Vulnerable compose before each floor", strength=2, weak=1, vulnerable=1, hits={{7,0},{7,0}}, upgradedHits={{10,0},{10,0}}},
    {name="enemy block is consumed across separate hits", enemyBlock=6, hits={{0,5},{4,1}}, upgradedHits={{1,6},{7,0}}},
    {name="Thorns consumes player block before the next hit", thorns=3, playerBlock=4, playerHpAfter=78, hits={{5,0},{5,0}}, upgradedHits={{7,0},{7,0}}, thornsHits=2},
    {name="lethal first retaliation prevents second attack", thorns=3, playerHp=3, playerHpAfter=0, phase="defeat", hits={{5,0}}, upgradedHits={{7,0}}, thornsHits=1},
    {name="lethal first attack does not retarget the next enemy", enemyHp=1, secondEnemy=true, hits={{1,0}}, upgradedHits={{1,0}}},
}
for _, upgraded in ipairs({false, true}) do
    for _, case in ipairs(cases) do
        test((upgraded and "upgraded: " or "base: ") .. case.name, function()
            local enemies = case.secondEnemy and {"jaw_worm", "jaw_worm"} or {"jaw_worm"}
            local s = Combat.new(data, {seed=42, deck={{cardId="twin_strike",upgraded=upgraded}}, enemies=enemies})
            local card, enemy = s.hand[1], s.enemies[1]
            s.player.hp, s.player.block = case.playerHp or 80, case.playerBlock or 0
            enemy.hp, enemy.maxHp, enemy.block = case.enemyHp or 100, 100, case.enemyBlock or 0
            for _, name in ipairs({"strength", "weak"}) do
                if case[name] then Combat.addStatus(s.player, name, case[name]) end
            end
            if case.vulnerable then Combat.addStatus(enemy, "vulnerable", case.vulnerable) end
            if case.thorns then Combat.addStatus(enemy, "thorns", case.thorns) end
            local otherHp = s.enemies[2] and s.enemies[2].hp
            local first, hp = #s.events + 1, enemy.hp
            assert(Combat.play(s, card.uid, 1))
            local expected, hit, thornCount, lost = upgraded and case.upgradedHits or case.hits, 0, 0, 0
            for i=first,#s.events do
                local event = s.events[i]
                if event.kind == "damage" then
                    hit = hit + 1
                    assert(expected[hit], "unexpected extra attack")
                    equal(event.detail.target, enemy.id, "attack target")
                    equal(event.detail.amount, expected[hit][1], "hit HP loss")
                    equal(event.detail.blocked, expected[hit][2], "hit absorbed")
                    lost = lost + expected[hit][1]
                elseif event.kind == "status_damage" and event.detail.status == "thorns" then
                    thornCount = thornCount + 1
                    equal(hit, thornCount, "retaliation occurs between hits")
                end
            end
            equal(hit, #expected, "attack count")
            equal(thornCount, case.thornsHits or 0, "retaliation count")
            equal(enemy.hp, hp-lost, "enemy HP")
            equal(s.player.hp, case.playerHpAfter or 80, "player HP")
            equal(s.player.block, 0, "remaining player block")
            if otherHp then equal(s.enemies[2].hp, otherHp, "unselected enemy HP") end
            equal(s.phase, case.phase or "player", "phase")
            equal(s.energy, 2, "cost")
            equal(#s.hand, 0); equal(#s.discard,s.player.hp>0 and 1 or 0); equal(#s.exhaust, 0)
            if s.player.hp>0 then equal(s.discard[1].uid,card.uid,'discarded original instance')
            else equal(s.cardInUse,card,'death interrupts use-card disposal') end
        end)
    end
end
print("LUA_TWIN_STRIKE_BOUNDARIES " .. passed .. " passed; " .. failed .. " failed")
assert(failed == 0, "Twin Strike boundary failures: " .. failed)
