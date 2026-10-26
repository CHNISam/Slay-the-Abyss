package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Orbs,Actions=require('abyss_combat'),require('abyss_actor'),require('abyss_orbs'),require('abyss_card_actions')
local D=require('abyss_warrior_strength_cards').withCards(require('abyss_character_profiles').prepare(require('abyss_data'),'watcher'))
for _,advanced in ipairs({false,true})do
 local s=C.new(D,{deck={'combust','burn'},enemies={'cultist'},seed=42,orbSlots=1,enableStances=true,cardRandomSeed='42'})
 s.experimentalMechanics=advanced
 for _,c in ipairs(s.hand)do if c.cardId=='combust'then assert(C.play(s,c.uid));break end end
 s.player.stance='Calm';A.applyPower(s,s.player,'like_water',5,s.player);A.applyPower(s,s.player,'metallicize',3,s.player);A.applyPower(s,s.player,'plated_armor',4,s.player)
 Orbs.channel(s,'frost',C);local start=#s.events;local hp=s.player.hp
 local dazed=Actions.fresh(C,s,'dazed');Actions.toHand(s,dazed)
 assert(C.endTurn(s));assert(s.player.hp==hp-1)
 local blocks,orb,burn,loss,exhaust={},nil,nil,nil,nil
 for i=start+1,#s.events do local e=s.events[i]
  if e.kind=='block'and e.detail.target=='player'then blocks[#blocks+1]=e.detail.amount end
  if e.kind=='orb_effect'and e.detail.orb=='frost'then orb=i end
  if e.kind=='damage'and e.detail.target=='player'and e.detail.blocked==2 then burn=i end
  if e.kind=='hp_loss'and e.detail.target=='player'then loss=i end
  if e.kind=='exhaust'and e.detail.uid==dazed.uid then exhaust=i end
 end
 assert(#blocks==4,'pre-card acquisition mismatch '..tostring(advanced)..': '..table.concat(blocks,','))
 for i,n in ipairs({5,3,4,2})do assert(blocks[i]==n)end
 assert(orb and burn and loss and exhaust and orb<burn and burn<loss and loss<exhaust,'pre-card/orb/Burn/ordinary/Ethereal order')
 print('PASS source block acquisition -> Frost -> Burn -> Combust -> Ethereal '..tostring(advanced))
end
print('OWNER_END_PRE_CARDS_PASS')
