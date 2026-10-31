local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Run=H.Run
for _,spec in ipairs({{'flex_potion','力量'},{'speed_potion','敏捷'}}) do
 local host,ui,panel,event=H.setup({'defend'},{'cultist'})
 assert(Run.obtainPotion(host.run,spec[1]));ui:render()
 local label=panel:GetChild('potion1'):GetChild('normal'):GetChild('label')
 assert(label.visible and label.text==(spec[1]=='flex_potion' and '肌'or '速'))
 local face=require('abyss_battle_potion_view').potionText(Run.potionView(host.run)[1],host.run.combat)
 -- Keep the full compact-copy contract alongside the visible identity and detail.
 assert(face:find(spec[2]..'+5',1,true) and face:find('回合末-5',1,true),face)
 assert(panel:GetChild('potion1').visible)
 event('potion1','down',3);host:update(.4);event('potion1','up',3);event('potion1','click',3)
 local info=panel:GetChild('statusInfo')
 assert(info.visible and info:GetChild('text1').visible,'temporary potion detail must be visible through real bottle help')
 assert(info:GetChild('text1').text:find('5',1,true) and info:GetChild('text1').text:find('回合结束',1,true))
 assert(info:GetChild('tag2').text=='本回合')
 assert(info:GetChild('note2').text:find('5',1,true) and info:GetChild('note2').text:find('回合结束',1,true))
 assert(Run.usePotion(host.run,1));info:GetChild('hit').click();ui:showStatus(0)
 assert(info:GetChild('tag1').text=='本回合')
 assert(info:GetChild('note1').text:find('5',1,true))
end
print('LUA_POTION_FLEX_SPEED_UI_PASS 2')
