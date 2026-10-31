local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Run=H.Run
for _,spec in ipairs({{'heart_of_iron','metallicize','6'}, {'essence_of_steel','plated_armor','4'}, {'cultist_potion','ritual','1'}}) do
 local host,ui,panel,event=H.setup({'defend'},{'cultist'})
 assert(Run.obtainPotion(host.run,spec[1]));ui:render()
 local label=panel:GetChild('potion1'):GetChild('normal'):GetChild('label')
 assert(label.visible and utf8.len(label.text)==1)
 local face=require('abyss_battle_potion_view').potionText(Run.potionView(host.run)[1],host.run.combat)
 -- Preserve compact-copy generation and the real visible potion effect.
 assert(face:find(spec[3],1,true),face)
 assert(panel:GetChild('potion1').visible)
 event('potion1','down',3);host:update(.4);event('potion1','up',3);event('potion1','click',3)
 local info=panel:GetChild('statusInfo');local effect=info:GetChild('text1')
 assert(info.visible and effect.visible and effect.text:find(spec[3],1,true))
 info:GetChild('hit').click();assert(not info.visible)
 assert(Run.usePotion(host.run,1));ui:showStatus(0)
 local found=false
 for i=1,12 do
  local row=panel:GetChild('statusInfo'):GetChild('text'..i)
  if row and row.text:find('回合结束',1,true) and row.text:find(spec[3],1,true) then found=true end
 end
 assert(found,spec[1]..' must show actual owner-end amount')
end
print('LUA_POTION_SUSTAINED_UI_PASS 3')
