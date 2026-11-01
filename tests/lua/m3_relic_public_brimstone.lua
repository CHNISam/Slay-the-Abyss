-- Source Brimstone.atTurnStart: player+2 and every enemy+1, including turn1.
-- Actual combat start/endTurn drain production queues, no direct relic hook.
local Run=require('abyss_run');local D=require('abyss_data')
local r=Run.new(D,42);assert(Run.obtainRelic(r,'Brimstone'))
assert(Run.startCombat(r,'louse_pair'))
for turn=1,3 do
 assert(r.combat.turn==turn)
 assert(r.combat.player.statuses.strength==turn*2,'Brimstone player strength2/4/6')
 for _,e in ipairs(r.combat.enemies)do assert(e.statuses.strength==turn,'Brimstone enemy strength1/2/3')end
 if turn<3 then assert(Run.endTurn(r))end
end
local control=Run.new(D,42);assert(Run.startCombat(control,'louse_pair'));assert(not control.combat.player.statuses.strength)
for _,e in ipairs(control.combat.enemies)do assert(not e.statuses.strength)end
print('M3_RELIC_PUBLIC_BRIMSTONE_PASS opening-and-two-turns')
