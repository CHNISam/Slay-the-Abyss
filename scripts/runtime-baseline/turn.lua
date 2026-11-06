-- A timing phase must prove its representative action happened, not merely
-- that the Host is still idle in the same route after a possibly rejected click.
return function(host,battle,previousTurn)
 assert(type(previousTurn)=='number' and previousTurn>=1 and previousTurn%1==0,'invalid initial combat turn')
 assert(host.run.phase=='combat' and host.run.combat==battle,'combat owner changed during baseline turn')
 assert(battle.turn==previousTurn+1 and battle.phase=='player','baseline end-turn did not complete exactly one turn')
 assert(not host.battleUI.busy,'baseline turn feedback is unfinished')
end
