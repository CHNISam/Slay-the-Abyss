local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
local C,A,H,Q=F.C,F.A,F.hooks,F.Q
for _,shared in ipairs({false,true})do for _,reserve in ipairs({'fairy','tail','bloom'})do
 local s=C.new(F.D,{seed=42,deck={},enemies={'cultist'},enableStances=shared})
 local owned={'centennial_puzzle','runic_cube','self_forming_clay','red_skull','lizard_tail'}
 if reserve=='bloom'then owned[#owned+1]='mark_of_bloom'end
 H.bindBattle(s,owned,{lizard_tail=-1});A.applyPower(s,s.player,'rupture',2,s.player)
 local card=Q.fresh(C,s,'bloodletting');s.hand={card};s.draw={};s.discard={}
 for _=1,8 do s.draw[#s.draw+1]=Q.fresh(C,s,'defend')end
 s.player.hp=3;s.enemies[1].hp=200;s.enemies[1].maxHp=200
 s.potionInventory=reserve=='tail'and {}or {[1]='fairy_in_a_bottle',[3]='dexterity'};s.potionCapacity=3
 local root=F.root(s);root.playing=card
 local called,accepted=F.call(root,'real fatal payment '..tostring(shared)..' '..reserve,C.play,s,card.uid,1)
 F.eq(called,true,'real play returns');F.eq(accepted,true,'real card accepted')
 F.eq(s.relicCombat.centennialUsed,true,'Puzzle actual loss consumed')
 F.eq(s.player.hp,reserve=='bloom'and 0 or reserve=='tail'and 40 or 24,'reserve health')
 if reserve=='bloom'then F.eq(#s.hand,0,'terminal draws suppressed');F.eq(s.relicCounters.lizard_tail,-1,'Bloom keeps Tail')
 else
  F.eq(#s.hand,4,'Puzzle and Cube both draw');F.eq(s.player.statuses.next_turn_block,3,'Clay actual loss')
  F.eq(s.player.statuses.strength,2,'Rupture resolves after reverse TOP draws')
  F.eq(s.relicCounters.lizard_tail,reserve=='tail'and -2 or -1,'Fairy before Tail')
 end
 F.eq(s.cardActions,nil,'native owner released');F.eq(s.actionQueue,nil,'shared owner released')
end end
do
 local s=C.new(F.D,{seed=42,deck={'defend'},enemies={'cultist'}});H.bindBattle(s,{'red_skull','centennial_puzzle'})
 s.player.hp=40;H.battleStart(s,'red_skull');F.eq(s.player.statuses.strength,3)
 local root=F.root(s);F.call(root,'heal boundary removes Red Skull',C.applyEffects,s,{{op='heal',value=10}},s.player)
 F.eq(s.player.statuses.strength,0);F.eq(s.relicCombat.centennialUsed,nil,'healing is not HP loss')
end
F.finish('hp')
