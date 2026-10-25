local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Run=H.Run
for _,spec in ipairs({{'heart_of_iron','metallicize','6'}, {'essence_of_steel','plated_armor','4'}, {'cultist_potion','ritual','1'}}) do
 local host,ui,panel=H.setup({'defend'},{'cultist'})
 assert(Run.obtainPotion(host.run,spec[1]));ui:render()
 local face=panel:GetChild('potion1'):GetChild('normal'):GetChild('label').text
 assert(face:find(spec[3],1,true),face)
 assert(Run.usePotion(host.run,1));ui:showStatus(0)
 local found=false
 for i=1,12 do
  local row=panel:GetChild('statusInfo'):GetChild('text'..i)
  if row and row.text:find('回合结束',1,true) and row.text:find(spec[3],1,true) then found=true end
 end
 assert(found,spec[1]..' must show actual owner-end amount')
end
print('LUA_POTION_SUSTAINED_UI_PASS 3')
