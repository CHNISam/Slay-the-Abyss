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
print("LUA_FEEDBACK_EVENTS_PASS 1")
