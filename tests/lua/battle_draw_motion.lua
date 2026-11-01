local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Combat,Theme=H.F.Combat,H.F.Theme
local count=0
local function test(name,fn) fn();count=count+1;print('ok draw motion '..count..' - '..name) end
local function near(a,b) assert(math.abs(a-b)<0.000001,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end

test('a real draw enters from the approved pile anchor and grows at the fixed source rate',function()
    for _,fast in ipairs({false,true}) do
        local host,ui,panel=H.setup({'defend','defend','defend','defend','defend','defend'})
        local b=host.run.combat
        local uid=b.draw[#b.draw].uid
        ui.fastMode=fast
        Combat.draw(b,1)
        local before=Combat.copy(host.run)
        ui:render()
        local box=panel:GetChild('card6')
        near(box.x,Theme.layout.drawPile.position[1]);near(box.y,Theme.layout.drawPile.position[2])
        near(box.scale[1],0.16)
        local gap=336-Theme.layout.drawPile.position[1]
        ui:update(0.05)
        near(box.x,Theme.layout.drawPile.position[1]+gap*(fast and 0.51 or 0.3))
        near(box.scale[1],0.16+0.84*0.375)
        near(ui.cardPositions[uid][1],box.x)
        assert(same(before,host.run),'visual draw changed cards triggers or RNG')
    end
end)

test('a real empty-deck reshuffle moves the existing discard UID into the same draw entrance',function()
    local host,ui,panel=H.setup({'defend'})
    local b=host.run.combat
    b.draw={};b.discard={{uid=99,cardId='strike',upgraded=true}}
    ui:render();Combat.draw(b,1)
    local before=Combat.copy(host.run)
    ui:render()
    local box=panel:GetChild('card2')
    local shuffle=b.events[#b.events]
    assert(shuffle.kind=='reshuffle'and shuffle.frame.draw[1].uid==99,'real draw must capture its intermediate shuffle destination')
    near(box.x,Theme.layout.drawPile.position[1]);near(box.y,Theme.layout.drawPile.position[2]);near(box.scale[1],0.16)
    assert(b.hand[2].uid==99 and b.hand[2].upgraded)
    for _=1,100 do ui:update(1/60) end
    near(box.x,70);near(box.scale[1],1)
    assert(same(before,host.run),'reshuffle visual consumed additional RNG')
end)

test('opening draws enter from the draw pile while unknown generated UIDs do not invent an origin',function()
    local host,ui,panel=H.setup({'defend'})
    local b=host.run.combat
    near(panel:GetChild('card1').x,Theme.layout.drawPile.position[1])
    near(panel:GetChild('card1').y,Theme.layout.drawPile.position[2])
    for _=1,100 do ui:update(1/60)end
    near(panel:GetChild('card1').x,0);near(panel:GetChild('card1').scale[1],1)
    b.hand[#b.hand+1]={uid=99,cardId='strike',upgraded=false}
    ui:render()
    near(panel:GetChild('card2').x,70);near(panel:GetChild('card2').scale[1],1)
    host.run.combat=Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist'}})
    ui:render();near(panel:GetChild('card1').x,Theme.layout.drawPile.position[1])
    for _=1,100 do ui:update(1/60)end
    near(panel:GetChild('card1').x,0);near(panel:GetChild('card1').scale[1],1)
end)

test('direct discard and exhaust recoveries keep their real origin and ignore an old reshuffle',function()
    local Cards=require('abyss_card_actions')
    for _,pile in ipairs({'discard','exhaust'})do
        local host,ui,panel=H.setup({'defend'})
        local b=host.run.combat
        b.draw={};b.discard={{uid=99,cardId='strike',upgraded=true}}
        ui:render();Combat.draw(b,1);ui:render()
        assert(b.events[#b.events].kind=='reshuffle')
        for _=1,100 do ui:update(1/60)end
        local returned=table.remove(b.hand,2)
        b[pile][#b[pile]+1]=returned
        ui:render()
        local shuffleCount=#b.events
        Cards.toHand(b,table.remove(b[pile]))
        assert(#b.events==shuffleCount,'direct recovery must not add a reshuffle event')
        local committed=Combat.copy(host.run)
        ui:render()
        local box=panel:GetChild('card2')
        local origin=pile=='discard'and Theme.layout.discardPile.position or{Theme.layout.topBar.exhaustIcon[1],Theme.layout.topBar.y}
        near(box.x,origin[1]);near(box.y,origin[2]);near(box.scale[1],0.16)
        assert(b.hand[2].uid==99 and b.hand[2].upgraded,'recovery must preserve the original card')
        for _=1,100 do ui:update(1/60)end
        near(box.x,70);near(box.scale[1],1)
        assert(same(committed,host.run),'recovery visual changed committed rules or RNG')
        -- Core consumption reuses the event array: a new short batch is still new.
        b.discard[#b.discard+1]=table.remove(b.hand,2)
        ui:render()
        for index=#b.events,1,-1 do b.events[index]=nil end
        Combat.draw(b,1)
        local reshuffled=Combat.copy(host.run)
        ui:render()
        near(box.x,Theme.layout.drawPile.position[1]);near(box.y,Theme.layout.drawPile.position[2])
        near(box.scale[1],0.16)
        assert(same(reshuffled,host.run),'new-batch shuffle visual consumed extra RNG')
    end
end)

test('the normal Shrug It Off command reaches the draw entrance through committed feedback frames',function()
    local host,ui,panel=H.setup({'shrug_it_off','shrug_it_off','shrug_it_off','shrug_it_off','shrug_it_off','shrug_it_off'})
    local b=host.run.combat
    local uid=b.draw[#b.draw].uid
    ui:playSlot(1);ui:playSelected()
    assert(b.energy==2 and #b.hand==5 and #b.draw==0 and #b.discard==1)
    local seen=false
    for _=1,200 do
        ui:update(0.01)
        local point=ui.cardPositions[uid]
        if point then
            assert(point[1]<280 and panel:GetChild('card5').scale[1]<1,'real draw bypassed its entrance')
            seen=true;break
        end
    end
    assert(seen,'committed frame never displayed the real drawn UID')
    for _=1,200 do ui:update(0.01) end
    near(panel:GetChild('card5').x,280)
    assert(not ui.busy and b.energy==2 and b.hand[5].uid==uid and b.player.block==8)
end)
print('LUA_DRAW_MOTION_PASS '..count)
