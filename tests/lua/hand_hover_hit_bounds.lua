local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=H.F.Theme
local function bounds(card)
    local hit=card:GetChild('hit')
    local a=card.localRotationZ*math.pi/180
    local z=a+hit.localRotationZ*math.pi/180
    local s=card.localScaleX
    local dx,dy=hit.x*s,hit.y*s
    local x,y=card.x+math.cos(a)*dx-math.sin(a)*dy,card.y+math.sin(a)*dx+math.cos(a)*dy
    local w,h=hit.sizeDeltaX*s/2,hit.sizeDeltaY*s/2
    local rx,ry=math.abs(math.cos(z))*w+math.abs(math.sin(z))*h,math.abs(math.sin(z))*w+math.abs(math.cos(z))*h
    return {x-rx,x+rx,y-ry,y+ry}
end
for _,count in ipairs({1,5,10})do
    local deck={};for i=1,count do deck[i]='defend'end
    local host,ui,panel=H.setup(deck)
    H.F.Combat.draw(host.run.combat,count);host:refresh();host:update(10)
    for slot=1,count do
        local card=panel:GetChild('card'..slot)
        local rest=bounds(card)
        local function fixed()
            local actual=bounds(card)
            for edge=1,4 do assert(math.abs(actual[edge]-rest[edge])<1e-6,'animated hover changed world hit bounds')end
        end
        ui:setHover(slot);fixed()
        for _=1,4 do host:update(1/60);fixed()end
        host:update(10);fixed()
        assert(card.y-Theme.layout.card.size[2]*card.localScaleY/2>=-Theme.canvas.base[2]/2+Theme.canvas.safe.y-1e-6,'settled hover left safe canvas')
        ui:setHover(nil);fixed()
        for _=1,4 do host:update(1/60);fixed()end
        host:update(10);fixed()
    end
end
print('LUA_HAND_HOVER_HIT_BOUNDS_PASS')
