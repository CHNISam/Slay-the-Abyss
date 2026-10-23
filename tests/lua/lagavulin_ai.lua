package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local data = require("abyss_data")
local count = 0
local function equal(a, b, name) assert(a == b, (name or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function test(name, fn) fn(); count = count + 1; print("ok " .. count .. " - " .. name) end
local function battle(deck) return Combat.new(data, {enemies={"lagavulin"}, deck=deck or {"defend"}, seed=42}) end
local function intent(s) return Combat.intent(s, 1).kind end

test("A0 Lagavulin starts asleep with 8 Block and 110 HP", function()
 local s=battle(); equal(s.enemies[1].hp,110); equal(s.enemies[1].block,8); equal(intent(s),"sleep")
 local view=Combat.intent(s,1); view.kind="attack"; equal(intent(s),"sleep")
end)
test("three sleeping turns grant setup; natural wake attacks on turn four", function()
 local s=battle(); local e=s.enemies[1]
 for turn=1,3 do
  equal(s.turn,turn); equal(intent(s),"sleep"); assert(Combat.endTurn(s)); equal(s.player.hp,80)
  equal(e.block,turn<3 and 8 or 0)
 end
 equal(intent(s),"attack"); assert(Combat.endTurn(s)); equal(s.player.hp,62)
 assert(Combat.endTurn(s)); equal(s.player.hp,44); equal(intent(s),"debuff")
 assert(Combat.endTurn(s)); equal(s.player.hp,44)
 equal(s.player.statuses.dexterity,-1); equal(s.player.statuses.strength,-1)
 equal(intent(s),"attack"); assert(Combat.endTurn(s)); equal(s.player.hp,26)
 equal(e.block,0,"sleep Block never returns")
end)
test("exactly blocked damage and zero damage do not wake", function()
 local s=battle(); local e=s.enemies[1]
 equal(Combat.damage(s,s.player,e,8),0); equal(e.block,0); equal(intent(s),"sleep")
 equal(Combat.damage(s,s.player,e,0),0); equal(intent(s),"sleep")
 assert(Combat.endTurn(s)); equal(e.block,8); equal(intent(s),"sleep")
end)
test("HP damage immediately changes queued intent and skips exactly one action", function()
 local s=battle(); local e=s.enemies[1]
 equal(Combat.damage(s,s.player,e,9),1); equal(intent(s),"stunned")
 Combat.damage(s,s.player,e,1); equal(intent(s),"stunned")
 assert(Combat.endTurn(s)); equal(s.player.hp,80); equal(e.block,0); equal(intent(s),"attack")
 assert(Combat.endTurn(s)); equal(s.player.hp,62)
end)
test("wake on the third setup turn still skips that action", function()
 local s=battle(); assert(Combat.endTurn(s)); assert(Combat.endTurn(s))
 Combat.damage(s,s.player,s.enemies[1],9,true); equal(intent(s),"stunned")
 assert(Combat.endTurn(s)); equal(s.player.hp,80); equal(intent(s),"attack")
end)
test("poison HP loss bypasses sleeping Block and stuns that enemy turn", function()
 local s=battle(); local e=s.enemies[1]; Combat.addStatus(e,"poison",2)
 assert(Combat.endTurn(s)); equal(e.hp,108); equal(s.player.hp,80)
 equal(intent(s),"attack"); equal(e.block,0)
 assert(Combat.endTurn(s)); equal(s.player.hp,62)
end)
test("lethal hit never schedules a living enemy intent", function()
 local s=battle({"bludgeon"}); local e=s.enemies[1]
 Combat.damage(s,s.player,e,118,true); equal(e.hp,0); equal(Combat.intent(s,1),nil)
 assert(Combat.endTurn(s)); equal(s.phase,"victory"); equal(s.player.hp,80)
end)
test("separate enemies and battles own independent sleep counters", function()
 local s=Combat.new(data,{enemies={"lagavulin","lagavulin"},seed=42}); local other=battle()
 Combat.damage(s,s.player,s.enemies[1],9); assert(Combat.endTurn(s))
 equal(Combat.intent(s,1).kind,"attack"); equal(Combat.intent(s,2).kind,"sleep")
 equal(intent(other),"sleep"); equal(other.enemies[1].block,8)
end)
test("failed card resolution restores the sleeping AI and Block", function()
 local s=battle({"strike"}); local e=s.enemies[1]; local card=s.catalog.cards.strike
 card.effects={{op="damage",value=9},{op="gainStatus",status="strength",value=2147483647}}
 s.player.statuses.strength=1 -- overflow after an otherwise legal damage operation
 local ok=pcall(Combat.play,s,s.hand[1].uid,1); equal(ok,false)
 equal(e.hp,110); equal(e.block,8); equal(intent(s),"sleep"); equal(s.energy,3); equal(#s.hand,1)
end)
print("lagavulin AI: " .. count .. " groups passed")
