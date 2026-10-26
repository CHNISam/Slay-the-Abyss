-- Generated native controls, actual host commands and feedback timeline.
package.path='tests/lua/?.lua;'..package.path
local F=require('support.game_ui_fixture')
local errors,originalPrint={},print
print=function(message,...)
    if type(message)=='string' and (message:find('prepare_failed',1,true) or message:find('ABYSS_FEEDBACK recovered',1,true))then errors[#errors+1]=message end
    originalPrint(message,...)
end
local count=0
for _,role in ipairs({'hutao','arlecchino','furina','raiden'})do
    local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
    local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',
        color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,originalCharacters=true,prologue=false})
    root.ui=ui;assert(ui:start(role))
    assert(F.Nodes.enter(ui.run,ui.map,F.Nodes.available(ui.run,ui.map)[1].id));ui:refresh()
    local battle=ui.run.combat;local slot
    for i,card in ipairs(battle.hand)do if card.uid==7 then slot=i end end
    assert(slot,'fixed natural opening must contain the original E')
    F.click(root,'battlePanel','card'..slot)
    assert(ui.battleUI.selected==7)
    local energy,hand=battle.energy,#battle.hand
    F.click(root,'battlePanel',role=='raiden' and 'enemy1' or 'playArea')
    assert(battle.energy==energy-(role=='furina' and 2 or 1),'actual UI play did not commit for '..role)
    assert(#battle.hand==hand-1 and not ui.battleUI.busy)
    local v=battle.originalV4
    if role=='hutao'then assert(v.infuse==2)
    elseif role=='arlecchino'then assert(battle.enemies[1].v4Directive)
    elseif role=='furina'then assert(v.guests.usher==2 and v.guests.chevalmarin==2 and v.guests.crabaletta==2)
    else assert(v.eye.uses==3 and v.resolve==1)end
    local turn=battle.turn
    F.click(root,'battlePanel','endTurn')
    assert(not ui.battleUI.busy and battle.turn==turn+1 and ui.run.phase=='combat')
    assert(#errors==0,table.concat(errors,'\n'))
    count=count+1
end
print=originalPrint
print('ORIGINAL_V4_BATTLE_UI_PASS '..count)
