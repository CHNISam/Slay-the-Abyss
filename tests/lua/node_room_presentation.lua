local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
-- Real Run/Map/Nodes and generated native controls; no gameplay rules are mocked.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local Data, Layout, Presentation = require("abyss_data"), require("abyss_ui_layout"), require("abyss_presentation")
local cursor = {CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag"}
local function control(spec, parent)
    local box = {parent=parent, visible=spec.visible~=false, children={}, listeners={}}
    function box:GetChild(key) return self.children[key] end
    function box:SetVisible(value) self.visible=value end
    function box:SetSizeDelta(width,height) NativeContract.sizeDelta(width,height);
        self.size={width,height};self.sizeDeltaX,self.sizeDeltaY=width,height
    end
    function box:SetLocalScale(x,y,z) self.scale={x,y,z} end
    function box:SetAnchoredPosition(x,y) self.x,self.y=x,y end
    function box:AddCursorEventListener(event, fn) NativeContract.listener(event,fn);
        assert(not self.listeners[event], "duplicate listener") self.listeners[event]=fn
    end
    for _, child in ipairs(spec.children or {}) do box.children[child.name]=control(child,box) end
    return box
end
local function same(a,b)
    assert(type(a)==type(b))
    if type(a)~="table" then assert(a==b, tostring(a).." ~= "..tostring(b)) return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil) end
end
local function setup(kind,linked,extraCards,source)
    source=source or Data
    local run,map=Run.new(source,42),Map.generate(source,42)
    for _=1,extraCards or 0 do assert(Run.obtainCard(run,run.deck[1].cardId))end
    -- Frozen independent relic stream used by the existing membership-card fixture.
    run.relicPool=require('abyss_relic_pool').new('2',run.data.relicSource)
    if linked then
        run.campaign,run.endingUnlocked,run.act=true,true,1;run.keys={ruby=false,emerald=false,sapphire=false}
        dofile('tests/lua/support/sapphire_source_fixture.lua').stage(run,{gold='42'})
    end
    while not run.nodeFlow do
        local choices=Map.available(map) assert(#choices>0)
        for _,node in ipairs(choices) do
            if node.type==kind then assert(Nodes.enter(run,map,node.id)) break end
        end
        if not run.nodeFlow then assert(Map.choose(map,choices[1].id)) end
    end
    run.gold=10000 -- funding fixture only; original cards, prices and rules are unchanged
    local function find(list)
        for _,spec in ipairs(list) do
            if spec.name=="nodePanel" then return spec end
            local found=spec.children and find(spec.children) if found then return found end
        end
    end
    local root=control(assert(find(Layout)))
    local sounds={}
    local ui=UI.new(root,run,map,Presentation,"click",nil,{cursorEvents=cursor,enhancedRooms=true,color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,sound=function(cue)sounds[#sounds+1]=cue end})
    ui.testSounds=sounds
    ui:setVisible(true)
    local function get(key)
        local box=root for part in key:gmatch("[^/]+") do box=assert(box:GetChild(part),key) end
        return box
    end
    local function emit(key,event,id,payload)
        local fn=get(key.."/hit").listeners[event]
        if fn then
            if payload=="nil" then return fn() end
            if payload=="empty" then return fn({}) end
            return fn({touchId=id})
        end
    end
    local function tap(key,id,payload)
        local box=get(key) while box do assert(box.visible,"hidden physical target") box=box.parent end
        emit(key,"down",id) emit(key,"up",id) return emit(key,"click",id,payload)
    end
    local function picker()
        assert(tap("shopView/removal",22)) assert(tap("pickerView/card1",22))
        assert(ui.mode=="picker" and ui.selected)
    end
    return ui,get,emit,tap,picker
end


local function test(name,fn)fn();print('ok room presentation - '..name)end
test('chest anticipates twice, bursts once, then reveals every reward without granting it',function()
 local ui,get,emit,tap=setup('treasure');local gold=ui.run.gold;local deck=#ui.run.deck
 assert(tap('treasureView/chest',1));assert(ui.presentationBusy,'opening needs an actual timeline')
 assert(#ui.testSounds==0,'opening sound belongs to the burst, not the initial click')
 assert(not ui:press('treasureView/chest'))
 ui:update(.045);local a=get('treasureView/closed').x
 ui:update(.09);local b=get('treasureView/closed').x
 assert(a~=b,'first shake must change pose')
 ui:update(.09);assert(get('treasureView/closed').x~=b,'second shake must change pose')
 ui:update(.16);assert(get('treasureView/burst').visible and get('treasureView/open').visible)
 assert(#ui.testSounds==1 and ui.testSounds[1]=='treasure_open')
 ui:update(1);assert(not ui.presentationBusy and not get('treasureView/burst').visible)
 for i,item in ipairs(ui.run.nodeFlow.reward.items)do
  assert(get('treasureView/rewardItem'..i).visible,'all rewards must be visible together')
  assert(#get('treasureView/rewardItem'..i..'/name').text>0)
 end
 assert(not get('treasureView/next').visible and not get('treasureView/previous').visible)
 assert(ui.run.gold==gold and #ui.run.deck==deck)
 assert(#ui.testSounds==1)
end)
test('visible reward rows claim gold independently and expire their old callback',function()
 local ui,get,emit,tap=setup('treasure',true)
 assert(tap('treasureView/chest',1));ui:update(2)
 local index,amount
 for i,item in ipairs(ui.run.nodeFlow.reward.items)do if item.kind=='gold' then index,amount=i,item.amount end end
 assert(index and amount>0)
 local key='treasureView/rewardItem'..index
 local old=ui.actions[key].handler;local gold=ui.run.gold;local pending=#ui.run.nodeFlow.reward.items
 assert(tap(key,2));assert(ui.run.gold==gold+amount and #ui.run.nodeFlow.reward.items==pending-1)
 assert(not old() and ui.run.gold==gold+amount)
 local pair=ui.run.nodeFlow.reward.sapphireKey;assert(pair and not ui.run.keys.sapphire)
end)
test('key and relic are simultaneously discoverable and mutually exclusive',function()
 local ui,get,emit,tap=setup('treasure',true)
 assert(tap('treasureView/chest',1));ui:update(2)
 local index,base
 for i,item in ipairs(ui.run.nodeFlow.reward.items)do
  if item.kind=='sapphire' then index=i elseif item.origin=='base' then base=item.id end
  assert(get('treasureView/rewardItem'..i).visible)
 end
 assert(index and base);local relics=#ui.run.relics
 assert(tap('treasureView/rewardItem'..index,2));assert(ui.run.keys.sapphire and #ui.run.relics==relics)
 for _,item in ipairs(ui.run.nodeFlow.reward.items)do assert(item.kind~='sapphire' and item.id~=base)end
end)
test('hover and long press expose full reward text without claiming on release',function()
 local ui,get,emit,tap=setup('treasure',true)
 assert(tap('treasureView/chest',1));ui:update(2)
 local index
 for i,item in ipairs(ui.run.nodeFlow.reward.items)do if item.origin=='base' then index=i end end
 local key='treasureView/rewardItem'..assert(index)
 local before=Combat.copy(ui.run)
 get(key..'/hit').listeners.enter({touchId=8})
 assert(get('treasureView/details').visible and #get('treasureView/details/description').text>0)
 get(key..'/hit').listeners.exit({touchId=8});assert(not get('treasureView/details').visible)
 emit(key,'down',9);ui:update(.4);assert(get('treasureView/details').visible)
 emit(key,'up',9);assert(not emit(key,'click',9));same(ui.run,before)
 ui:render();assert(not get('treasureView/details').visible)
end)
test('an interrupted animation never leaks into the next room or grants rewards',function()
 local ui,get,emit,tap=setup('treasure');local gold=ui.run.gold
 assert(tap('treasureView/chest',1));ui:update(.1);ui:setVisible(false)
 assert(not ui.presentationBusy and ui.run.gold==gold)
 ui:setVisible(true);ui:update(1)
 assert(not get('treasureView/burst').visible)
 for i in ipairs(ui.run.nodeFlow.reward.items)do assert(get('treasureView/rewardItem'..i).visible)end
end)
test('rest has a result beat and never heals twice',function()
 local ui,get,emit,tap=setup('camp');ui.run.hp=20;ui:render()
 assert(tap('campView/rest',1));local hp=ui.run.hp
 assert(ui.presentationBusy and get('roomEffect').visible)
 ui:update(2);assert(not ui.presentationBusy and ui.run.hp==hp and hp>20)
 assert(not ui:press('campView/rest'))
end)
test('smithing uses a full grid and a separate enlarged before-after confirmation',function()
 local ui,get,emit,tap=setup('camp');assert(tap('campView/forge',1))
 assert(get('pickerView/forgeGrid').visible)
 assert(tap('pickerView/forgeGrid/card1',2))
 assert(not get('pickerView/forgeGrid').visible)
 assert(get('pickerView/before').scale[1]>=1.4 and get('pickerView/after').visible)
 local uid=ui.selected;assert(uid and tap('back',3))
 assert(ui.mode=='picker' and not ui.selected and get('pickerView/forgeGrid').visible)
 assert(tap('pickerView/forgeGrid/card1',4));assert(tap('confirm',5))
 assert(ui.presentationBusy);ui:update(2)
 assert(ui.result and ui.result.choice=='upgrade')
end)
test('a thirteen-card smithing grid has separate reachable page buttons',function()
 local ui,get,emit,tap=setup('camp',nil,3)
 assert(tap('campView/forge',1));assert(ui.pageCount==2)
 assert(get('pickerView/forgeNext').visible)
 assert(tap('pickerView/forgeNext',2) and ui.pickPage==2)
 assert(tap('pickerView/forgeGrid/card1',3) and ui.selected==ui.run.deck[13].uid)
 assert(tap('back',4) and get('pickerView/forgePrevious').visible)
end)
test('a remaining mandatory upgrade returns to the grid and retires the upgraded card',function()
 local source=Combat.copy(Data);source.rules.camp.upgradeCount=2
 local ui,get,emit,tap=setup('camp',nil,nil,source)
 assert(tap('campView/forge',1));assert(tap('pickerView/forgeGrid/card1',2));assert(tap('confirm',3));ui:update(2)
 assert(ui.run.phase=='node' and not ui.selected and not get('back').visible)
 assert(get('pickerView/forgeGrid/card1/stamp').text=='已升级')
 assert(not tap('pickerView/forgeGrid/card1',4))
 assert(tap('pickerView/forgeGrid/card2',5));assert(tap('confirm',6));ui:update(2)
 assert(ui.run.phase=='map' and ui.result.choice=='upgrade')
end)
