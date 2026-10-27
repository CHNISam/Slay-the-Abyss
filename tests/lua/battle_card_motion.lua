local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Combat=H.F.Combat
local Theme=H.F.Theme
local count=0
local function near(a,b) assert(math.abs(a-b)<0.000001,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();count=count+1;print('ok hand motion '..count..' - '..name) end

test('hover and return follow fixed source position scale and angle rates without changing rules',function()
    local host,ui,panel=H.setup()
    local box=panel:GetChild('card1')
    local x,y,scale,angle=box.x,box.y,box.scale[1],box.localRotationZ
    local before=Combat.copy(host.run)
    ui:setHover(1)
    near(box.x,x);near(box.y,y);near(box.scale[1],scale)
    host:update(0.05)
    near(box.y,y+Theme.motion.hoverLift*0.3)
    near(box.scale[1],scale+(Theme.motion.hoverScale-scale)*0.375)
    near(box.localRotationZ,angle*0.4)
    ui:setHover(nil)
    local fromY,fromScale=box.y,box.scale[1]
    host:update(0.05)
    near(box.y,fromY+(y-fromY)*0.3)
    near(box.scale[1],fromScale+(1-fromScale)*0.375)
    assert(host.run.combat.energy==before.combat.energy)
    assert(#host.run.combat.hand==#before.combat.hand)
    for i=1,#before.combat.hand do assert(host.run.combat.hand[i].uid==before.combat.hand[i].uid) end
    for _=1,80 do host:update(1/60) end
    near(box.y,y);near(box.scale[1],1);near(box.localRotationZ,angle)
end)

test('fast mode performs the extra position step but retains scale and angle rates',function()
    local host,ui,panel=H.setup()
    local box=panel:GetChild('card1')
    local y,angle=box.y,box.localRotationZ
    ui.fastMode=true;ui:setHover(1);host:update(0.05)
    near(box.y,y+Theme.motion.hoverLift*(1-0.7*0.7))
    near(box.scale[1],1+(Theme.motion.hoverScale-1)*0.375)
    near(box.localRotationZ,angle*0.4)
end)

test('reflow keeps each card current position by UID instead of borrowing its new slot',function()
    local host,ui,panel=H.setup({'defend','defend','defend'})
    local uid=host.run.combat.hand[2].uid
    local old=panel:GetChild('card2').x
    table.remove(host.run.combat.hand,1);ui:render()
    local box=panel:GetChild('card1')
    near(box.x,old)
    local goal=-(Theme.layout.hand.spacingMax/2)
    host:update(0.05)
    near(box.x,old+(goal-old)*0.3)
    near(ui.cardPositions[uid][1],box.x)
end)

test('cancelled drag returns from its last actual pose and interpolation does not redraw card previews',function()
    local host,ui,panel,event=H.setup()
    local box=panel:GetChild('card1')
    local restX,restY=box.x,box.y
    event('card1','down',7);event('card1','drag',7,100,0)
    near(box.x,100);near(box.y,0)
    host:update(0.5) -- A source short drag intentionally remains selected; exercise long-drag cancellation.
    event('dragLayer','up',7,100,-300)
    near(box.x,100);near(box.y,-300)
    local original,calls=Combat.cardPreview,0
    Combat.cardPreview=function(...)calls=calls+1;return original(...) end
    host:update(0.05)
    Combat.cardPreview=original
    near(box.x,100+(restX-100)*0.3);near(box.y,-300+(restY+300)*0.3)
    assert(calls==0,'pose updates recalculated card rules')
    assert(host.run.combat.energy==3 and #host.run.combat.hand==2)
end)

test('new battle with reused UIDs starts at its own pose and zero delta does not advance',function()
    local host,ui,panel=H.setup()
    ui:setHover(1);host:update(0.05)
    host.run.combat=Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist'}})
    ui:render()
    local box=panel:GetChild('card1')
    near(box.x,0)
    ui:setHover(nil);local y=box.y;host:update(0);near(box.y,y)
    host:update(10)
    assert(box.y==box.y and math.abs(box.y)<Theme.canvas.base[2],'stalled frame sent cards outside the canvas')
end)
print('LUA_HAND_MOTION_PASS '..count)
