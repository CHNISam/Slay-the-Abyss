package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Data = require("abyss_data")
local s = Combat.new(Data, {deck={"strike"}, enemies={"jaw_worm", "jaw_worm"}})
local hp = s.enemies[1].hp
assert(Combat.play(s, s.hand[1].uid, 1))
local hit = s.events[#s.events]
assert(hit.kind == "damage" and hit.frame, "damage needs a detached presentation frame")
assert(hit.frame.enemies[1].hp == hp - 6)
s.enemies[1].hp = 1
assert(hit.frame.enemies[1].hp == hp - 6, "later rules must not mutate earlier frames")
local capped = Combat.new(Data,{deck={"defend"}})
capped.player.block = 998
assert(Combat.play(capped,capped.hand[1].uid,1))
local shield = capped.events[#capped.events]
assert(shield.kind == "block" and shield.detail.amount == 1 and shield.frame.player.block == 999,
    "feedback must show the actual capped block gain, not the requested amount")
local thorn = Combat.new(Data,{deck={"strike"}})
thorn.player.block = 5
Combat.addStatus(thorn.enemies[1],"thorns",3)
local hp = thorn.player.hp
assert(Combat.play(thorn,thorn.hand[1].uid,1))
local retaliation = thorn.events[#thorn.events]
assert(retaliation.kind == "status_damage" and retaliation.detail.status == "thorns")
assert(retaliation.detail.amount == 0 and retaliation.detail.blocked == 3)
assert(retaliation.frame.player.hp == hp and retaliation.frame.player.block == 2)
print("LUA_FEEDBACK_EVENTS_PASS 3")
