local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Run=H.Run
local specs={{'attack_potion','攻击','0'},{'skill_potion','技能','0'},{'power_potion','能力','0'},
 {'colorless_potion','无色','0'},{'entropic_brew','槽','果汁'},{'fairy_in_a_bottle','致命','30'}}
for _,spec in ipairs(specs)do
 local host,ui,panel=H.setup({'defend'},{'cultist'})
 assert(Run.obtainPotion(host.run,spec[1]));ui:render()
 local face=panel:GetChild('potion1'):GetChild('normal'):GetChild('label').text
 assert(face:find(spec[2],1,true),spec[1]..' compact: '..face)
 ui:openHelp(ui:potionHelpSpec(1),nil,false)
 local info=panel:GetChild('statusInfo');local text=info:GetChild('text1').text
 assert(text:find(spec[2],1,true)and text:find(spec[3],1,true),spec[1]..' expanded: '..text)
 if spec[1]=='fairy_in_a_bottle'then assert(info:GetChild('note1').text:find('无法主动',1,true))end
end
print('LUA_POTION_REMAINING_UI_PASS 6')
