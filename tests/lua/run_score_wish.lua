-- Full-source preserved Wish owner adapter; does not open the Watcher roster.
local C,P,D,R=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_sts_random')
for _,up in ipairs({false,true})do for _,blocked in ipairs({false,true})do
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',miscRng=R.fromSeed('7'),enableStances=true,
  deck={{uid=90,cardId='wish',upgraded=up}},enemies={'cultist'}})
 s.energy=20;if blocked then s.relics={'ectoplasm'}end
 local gold=s.player.gold;assert(C.play(s,s.hand[1].uid,1));local choice=assert(s.pendingChoice)
 assert(C.chooseCard(s,choice.token,2));local gained=blocked and 0 or up and 30 or 25
 assert(s.player.gold==gold+gained);assert(s.scoreStats.goldGained==gained,'Wish must record accepted gold')
end end
print('PASS score preserved Wish basic/upgraded/Ectoplasm choice')
