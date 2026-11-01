package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Actions=require('abyss_combat'),require('abyss_card_actions')
local D=require('abyss_silent_final_cards').withCardDefinitions(require('abyss_warrior_strength_cards').withCards(require('abyss_character_profiles').prepare(require('abyss_data'),'watcher')))
for _,advanced in ipairs({false,true})do
 local s=C.new(D,{deck={'well_laid_plans'},enemies={'cultist'},seed=42,enableStances=true,orbSlots=0,cardRandomSeed='42'});s.experimentalMechanics=advanced
 for _,c in ipairs(s.hand)do if c.cardId=='well_laid_plans'then assert(C.play(s,c.uid));break end end
 C.applyEffects(s,{{op='gainExhaustPower',status='dark_embrace',value=2}},s.player)
 for i=1,9 do Actions.toHand(s,Actions.fresh(C,s,'protect'))end;Actions.toHand(s,Actions.fresh(C,s,'dazed'))
 for i=1,2 do s.draw[#s.draw+1]=Actions.fresh(C,s,'defend_purple')end
 assert(C.endTurn(s));assert(s.pendingChoice and s.pendingChoice.kind=='retain');assert(C.chooseCard(s,s.pendingChoice.token,0))
 local frame;for _,e in ipairs(s.events)do if e.kind=='enemy_turn'then frame=e.frame;break end end
 local drawn=0;for _,c in ipairs(frame.hand)do if c.cardId=='defend_purple'then drawn=drawn+1 end end
 assert(#frame.hand==10 and drawn==1,'Ethereal Dark Embrace BOTTOM draw must survive discard/restore: '..#frame.hand..'/'..drawn)
 print('PASS retained nine Protect restored before DE draw; full hand sends second draw to discard '..tostring(advanced))
end
print('OWNER_END_NATIVE_CLEANUP_PASS')
