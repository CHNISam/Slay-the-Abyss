local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
local r=F.R.new(F.D,42)
F.case('opening :: actual turn-start random upgrade',function()
 assert(F.R.obtainRelic(r,'warped_tongs'));assert(F.R.startCombat(r,'cultist_solo'))
 local root=F.root(r);F.call(root,'actual turn-start random upgrade',F.R.endTurn,r)
end)
F.case('opening :: actual final enemy triggers victory hooks',function()
 local s=r.combat;local root=F.root(r);s.enemies[1].hp=1;local strike
 for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,card in ipairs(pile)do if card.cardId=='strike'then strike=card end end end
 s.hand={strike};s.energy=9
 F.call(root,'actual final enemy triggers victory hooks',F.R.play,r,strike.uid,1)
 F.eq(s.phase,'victory','victory completed')
end)
F.finish('hooks_opening')
