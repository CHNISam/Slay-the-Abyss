-- Explicit battle fixture, real production UI listeners -> public Run.play.
return function(f)
 local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
 local R=require('abyss_sts_random')
 local h,u,_,e,tap,drain=H.setup({'sword_boomerang','defend'},{'cultist','cultist','cultist'})
 local s=h.run.combat;local sword,defend
 for _,c in ipairs(s.hand)do if c.cardId=='sword_boomerang'then sword=c else defend=c end end
 assert(sword and defend);s.hand={sword,defend};s.draw={};s.discard={};s.energy=3
 s.cardRandomRng=R.restore(f.initial)
 for _,enemy in ipairs(s.enemies)do enemy.hp=30;enemy.maxHp=30;enemy.block=0;enemy.statuses={}end
 h:refresh()
 -- A no-target random attack commits on the play area; no selected enemy input.
 e('card1','down',7);e('card1','drag',7,0,0);e('dragLayer','up',7,0,0)
 assert(s.energy==2 and #s.discard==1 and s.discard[1].uid==sword.uid,'real UI commits exactly one Sword')
 drain()
 local snap=R.snapshot(s.cardRandomRng)
 assert(snap.counter==f.after.counter and snap.words[1]==f.after.words[1] and snap.words[2]==f.after.words[2])
 for i,enemy in ipairs(s.enemies)do assert(enemy.hp==f.finalHp[i],'UI target vector')end
 for _,kind in ipairs({'up','endDrag','click','click'})do e('card1',kind,7)end
 assert(s.energy==2 and #s.hand==1 and s.hand[1].uid==defend.uid and not u.selected,'release leftovers cannot play next card')
 local after=R.snapshot(s.cardRandomRng);assert(after.counter==snap.counter and after.words[1]==snap.words[1] and after.words[2]==snap.words[2])
 tap('card1',8);tap('playArea',8);assert(s.energy==1 and s.player.block==5,'next independent action remains usable')
 print('SWORD_RANDOM_UI_PASS')
end
