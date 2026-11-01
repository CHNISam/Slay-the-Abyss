local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,C,View=require('abyss_run'),require('abyss_combat'),require('abyss_battle_intent_view')
local ui,root=F.fixture();assert(F.start(ui));assert(Run.obtainRelic(ui.run,'runic_dome'))
assert(Run.startCombat(ui.run,'cultist_solo'));ui:refresh()
local battle,panel=ui.run.combat,root:GetChild('battlePanel')
assert(C.intent(battle,1),'Dome must retain the real core intent')
local face=View.intentView(battle,1)
assert(face.hidden and face.value==''and #View.icons(face)==0)
local enemy=monsterControl(panel,'enemy1')
for _,name in ipairs({'intentIcon','intentBadge','intentExtra','intent','intentLabel','intentHit'})do
 assert(not enemy:GetChild(name).visible,'Dome leaked '..name)
end
assert(enemy:GetChild('intent').text=='')
local Content=require('abyss_battle_info_content')
local describe={intentView=function()error('hidden detail attempted numeric intent projection')end,intentColors={}}
local content=Content.new({run=ui.run},describe,Content.lines)
local card=content(ui.run.data,{},battle,{kind='intent',index=1},battle.enemies[1])
assert(#card.sections[1].rows==1 and card.sections[1].rows[1].name=='意图已隐藏')
assert(card.sections[1].rows[1].text=='符文圆顶隐藏敌人的下一步行动。')
-- Feedback frames do not carry relic lists; the owning Run still suppresses detail.
local frame=require('abyss_events').frame(battle);frame.catalog,frame.rules=battle.catalog,battle.rules
card=content(ui.run.data,{},frame,{kind='intent',index=1},frame.enemies[1])
assert(card.sections[1].rows[1].name=='意图已隐藏')
-- Ordinary owners keep all icons and the core executes exactly the same enemy action.
local plain=Run.new(require('abyss_data'),'1');assert(Run.startCombat(plain,'cultist_solo'))
assert(not View.intentView(plain.combat,1).hidden and #View.icons(View.intentView(plain.combat,1))>0)
local hidden=Run.new(require('abyss_data'),'1');assert(Run.obtainRelic(hidden,'runic_dome'));assert(Run.startCombat(hidden,'cultist_solo'))
for _=1,2 do assert(C.endTurn(plain.combat));assert(C.endTurn(hidden.combat))end
assert(plain.combat.player.hp==hidden.combat.player.hp and hidden.combat.player.hp<hidden.combat.player.maxHp)
print('LUA_BOSS_RELICS_DOME_PASS acquired source, native icon/number/hit suppression, detail/playback, unchanged real enemy damage')
