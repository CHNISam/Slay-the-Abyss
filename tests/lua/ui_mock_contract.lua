package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local constructors = {{name='game', new=dofile('tests/lua/support/game_ui_fixture.lua').control}}
for _,name in ipairs({'node_ui_cases','battle_ui_cases','growing_card_text_cases','sapphire_treasure_ui_cases'}) do
    local _,new = dofile('tests/lua/support/' .. name .. '.lua')(1,0)
    assert(type(new)=='function', 'missing fixture constructor: ' .. name)
    constructors[#constructors+1]={name=name,new=new}
end
local function fresh(row)
    return row.new({name='contract',kind='cursorArea',size={1,1}})
end
local count=0
local function test(name,fn) fn();count=count+1;print('ok UI mock contract '..count..' - '..name) end
local function rejects(fn,message)
    local ok,reason=pcall(fn)
    assert(not ok and tostring(reason):find(message,1,true), 'expected '..message..', got '..tostring(reason))
end
test('all five real mock factories accept signed fractional size deltas and zero',function()
    for _,row in ipairs(constructors)do
        local c=fresh(row)
        for _,size in ipairs({{0,0},{12.5,4.25},{-8,-2.5}})do
            c:SetSizeDelta(size[1],size[2])
            assert(c.sizeDeltaX==size[1] and c.sizeDeltaY==size[2],row.name)
        end
    end
end)
test('malformed or unusable synthetic geometry is rejected before changing each scene',function()
    for _,row in ipairs(constructors)do
        local c=fresh(row);c:SetSizeDelta(12,24)
        local previousSize=c.size
        local invalid={false,true,'12',{},0/0,math.huge,-math.huge}
        for _,value in ipairs(invalid)do
            rejects(function()c:SetSizeDelta(value,24)end,'SetSizeDelta')
            rejects(function()c:SetSizeDelta(12,value)end,'SetSizeDelta')
            assert(c.sizeDeltaX==12 and c.sizeDeltaY==24 and c.size==previousSize,row.name)
        end
        rejects(function()c:SetSizeDelta(nil,24)end,'SetSizeDelta')
        rejects(function()c:SetSizeDelta(12)end,'SetSizeDelta')
        assert(c.sizeDeltaX==12 and c.sizeDeltaY==24 and c.size==previousSize,row.name)
    end
end)
test('cursor registrations require a callable callback in every real mock',function()
    for _,row in ipairs(constructors)do
        for _,value in ipairs({false,true,1,'callback',{}})do
            local c=fresh(row)
            rejects(function()c:AddCursorEventListener('click',value)end,'callback')
            assert(c.click==nil and (not c.listeners or c.listeners.click==nil),row.name)
        end
        rejects(function()fresh(row):AddCursorEventListener('click',nil)end,'callback')
        rejects(function()fresh(row):AddCursorEventListener(nil,function()end)end,'event')
        local c=fresh(row);local calls=0
        c:AddCursorEventListener('click',function()calls=calls+1 end)
        local callback=c.click or c.listeners.click
        callback();assert(calls==1,row.name)
    end
end)
test('game key and navigation registrations keep enum values opaque and callbacks callable',function()
    local row=constructors[1]
    for _,method in ipairs({'AddKeyEventListener','AddNavigationEventListener'})do
        local c=fresh(row);local calls=0
        c[method](c,17,function()calls=calls+1 end)
        local listeners=method=='AddKeyEventListener' and c.keyListeners or c.navigationListeners
        listeners[17]();assert(calls==1)
        local invalid=fresh(row)
        rejects(function()invalid[method](invalid,'event',false)end,'callback')
        rejects(function()invalid[method](invalid,nil,function()end)end,'event')
    end
end)
test('independent controls keep separate geometry and listener state',function()
    for _,row in ipairs(constructors)do
        local a,b=fresh(row),fresh(row)
        a:SetSizeDelta(4,8);b:SetSizeDelta(16,32)
        local calls=0;a:AddCursorEventListener('click',function()calls=calls+1 end)
        assert(b.click==nil and (not b.listeners or not b.listeners.click),row.name)
        assert(a.sizeDeltaX==4 and b.sizeDeltaX==16,row.name)
        local callback=a.click or a.listeners.click
        callback();assert(calls==1)
    end
end)
print('UI_MOCK_CONTRACT_PASS '..count)
