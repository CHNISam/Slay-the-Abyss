package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C = require('abyss_combat')
local data = require('abyss_data')
local s = C.new(data, {seed=42, enemies={'guardian'}, deck={'strike','strike','strike'}})
local g = s.enemies[1]
-- Real card actions only. Three Strikes deal 18 before Charge Up;
-- next turn three Strikes deal 9 through its 9 Block, leaving shift budget 3.
for _,id in ipairs({'guardian_1','guardian_2'}) do
 assert(C.intent(s,1).id == id)
 while #s.hand > 0 do assert(C.play(s,s.hand[1].uid,1)) end
 assert(C.endTurn(s))
end
assert(g.statuses.mode_shift==3)
assert(C.intent(s,1).id=='guardian_4')
assert(C.endTurn(s)) -- Vent Steam, no damage dealt this player turn
assert(s.player.statuses.vulnerable==2)
assert(s.player.statuses.weak==2)
assert(C.play(s,s.hand[1].uid,1)) -- actual weakened Strike crosses Mode Shift
assert(C.intent(s,1).id=='guardian_5')
assert(C.endTurn(s)) -- Close Up, duration 2 -> 1 after round
assert(s.player.statuses.vulnerable==1)
assert(C.intent(s,1).id=='guardian_6')
local before=s.player.hp
assert(C.endTurn(s)) -- Roll Attack must see Vulnerable 1 until round end
local actual=before-s.player.hp
print('Guardian Vent -> Strike shift -> Close Up -> Roll: expected HP loss 13; actual '..actual)
assert(actual==13,'shared Vulnerable end-round regression: expected floor(9 * 1.5)=13, got '..actual)
