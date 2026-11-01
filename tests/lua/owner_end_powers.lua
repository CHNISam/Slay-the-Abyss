package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Actions=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions')
local D=require('abyss_watcher_final_cards').withCards(require('abyss_silent_final_cards').withCardDefinitions(require('abyss_warrior_strength_cards').withCards(require('abyss_data'))))
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(advanced,deck)
 local s=C.new(D,{deck=deck or {},enemies={'cultist'},seed=42,enableStances=true,orbSlots=0,cardRandomSeed='42'})
 s.experimentalMechanics=advanced;return s
end
for _,advanced in ipairs({false,true})do for _,first in ipairs({'loss','wraith'})do
 local s=fresh(advanced);s.player.hp=20
 local function loss()A.addTemporaryStrength(s.player,5,s)end
 local function wraith()A.applyPower(s,s.player,'wraith_form',-1,s.player)end
 if first=='loss'then loss();wraith()else wraith();loss()end
 A.applyPower(s,s.player,'ritual',3,s.player);A.applyNoDraw(s,s.player)
 C.applyEffects(s,{{op='gainExhaustPower',status='dark_embrace',value=1}},s.player)
 A.applyPower(s,s.player,'regen',3,s.player);A.applyPower(s,s.player,'artifact',1,s.player)
 require('abyss_warrior_status_cards').applyPower(s,'fire_breathing',6)
 local dazed=Actions.fresh(C,s,'dazed');Actions.toHand(s,dazed);local drawnBurn=Actions.fresh(C,s,'burn');s.draw[#s.draw+1]=drawnBurn
 local start=#s.events;assert(C.endTurn(s))
 eq(s.player.statuses.strength,first=='loss'and 8 or 3);eq(s.player.statuses.dexterity or 0,first=='loss'and -1 or 0)
 eq(s.player.statuses.artifact,0);eq(s.player.temporaryStrength,0);eq(s.player.hp,23);eq(s.player.statuses.regen,2);eq(s.player.noDraw,false)
 local clear,exhaust,draw,enemy
 for i=start+1,#s.events do local e=s.events[i]
  if e.kind=='no_draw_removed'then clear=i elseif e.kind=='exhaust'and e.detail.uid==dazed.uid then exhaust=i
  elseif e.kind=='damage'and e.detail.target==s.enemies[1].id and not draw then
   draw=i;local found=false;for _,c in ipairs(e.frame.hand)do if c.uid==drawnBurn.uid then found=true end end;assert(found)
  elseif e.kind=='enemy_turn'then enemy=i end
 end
 assert(clear and exhaust and draw and enemy and clear<exhaust and exhaust<draw and draw<enemy,'NoDraw -> Ethereal -> DarkEmbrace draw -> discard/enemy')
 print('PASS acquisition '..first..' consumes Artifact at correct owner-end action, RegenTOP and NoDraw/exhaust draw '..tostring(advanced))
end end
for _,advanced in ipairs({false,true})do for _,first in ipairs({'the_bomb','omega'})do
 local s=fresh(advanced,{'the_bomb','omega'});s.energy=5
 for _,id in ipairs({first,first=='the_bomb'and 'omega'or 'the_bomb'})do
  for _,card in ipairs(s.hand)do if card.cardId==id then assert(C.play(s,card.uid));break end end
 end
 local bomb=assert(s.colorlessBombs[1]);bomb.turns=1;s.player.statuses[bomb.id]=1;s.enemies[1].hp=1
 local original=C.retaliate;local calls=0
 C.retaliate=function(state,source,target,n)eq(source,nil);calls=calls+1;return original(state,source,target,n)end
 local ok,why=pcall(C.endTurn,s);C.retaliate=original;assert(ok,why)
 eq(C.outcome(s),'victory');eq(calls,1);eq(bomb.turns,first=='the_bomb'and 0 or 1)
 print('PASS real '..first..' acquisition wins before later non-DAMAGE Bomb reduction; both source owners remain null '..tostring(advanced))
end end
print('OWNER_END_POWERS_PASS 8 real component/Power interleavings; controlled boundary values, not natural acquisition')
