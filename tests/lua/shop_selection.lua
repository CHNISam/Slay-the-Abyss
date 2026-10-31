local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
-- Real Run/Map/Nodes and generated native controls; no gameplay rules are mocked.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local Data, Layout, Presentation = require("abyss_data"), require("abyss_ui_layout"), require("abyss_presentation")
local cursor = {CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag"}
local function control(spec, parent)
    local box = {parent=parent, visible=spec.visible~=false, children={}, listeners={},
        x=(spec.position or {})[1] or 0,y=(spec.position or {})[2] or 0,
        size=spec.size,scale={1,1,1}}
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
local function setup(touchScreen)
    local run,map=Run.new(Data,42),Map.generate(Data,42)
    -- Frozen independent relic stream used by the existing membership-card fixture.
    run.relicPool=require('abyss_relic_pool').new('2',run.data.relicSource)
    while not run.nodeFlow do
        local choices=Map.available(map) assert(#choices>0)
        for _,node in ipairs(choices) do
            if node.type=="shop" then assert(Nodes.enter(run,map,node.id)) break end
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
    local ui=UI.new(root,run,map,Presentation,"click",nil,{cursorEvents=cursor,color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,touchScreen=function() return touchScreen==true end})
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

local function test(name,fn) fn();print('ok source shop - '..name) end

-- Evaluate the generated cursor area's inherited transform each frame, then
-- deliver native-style enter/exit events. A stationary pointer must not churn
-- focus when the presentation moves underneath it.
local function pointerDriver(ui,get,emit)
 local previous,transitions=nil,0
 local function bounds(i)
  local hit=get('shopView/card'..i..'/hit')
  local x,y,w,h=0,0,hit.size[1],hit.size[2]
  local node=hit
  while node~=get('shopView') do
   x=x*node.scale[1]+node.x;y=y*node.scale[2]+node.y
   w=w*node.scale[1];h=h*node.scale[2];node=node.parent
  end
  return x-w/2,y-h/2,x+w/2,y+h/2
 end
 local function tick(x,y)
  local target
  for i=1,7 do
   local left,bottom,right,top=bounds(i)
   if x>=left and x<=right and y>=bottom and y<=top then target='shopView/card'..i end
  end
  if target~=previous then
   transitions=transitions+1
   if previous then emit(previous,'exit') end
   if target then emit(target,'enter') end
   previous=target
  end
  ui:update(1/60)
  return previous,transitions
 end
 return tick,bounds
end

test('desktop relic and potion preview cancel freely and confirm exactly once',function()
 for _,category in ipairs({'relics','potions'})do
  local ui,get,emit,tap=setup(false);local run=ui.run
  local key=category=='relics' and 'shopView/relic3' or 'shopView/potion1'
  local slot=category=='relics' and 3 or 1
  local offer=run.nodeFlow[category][slot];local gold=run.gold
  local function count()return category=='relics' and #run.relics or Run.potionCount(run)end
  local before=count();local old=ui.actions[key].handler
  assert(tap(key,1));assert(run.gold==gold and count()==before,'item preview charged')
  assert(get('shopView/detail').visible and #get('shopView/detail/description').text>0)
  assert(not old(),'pre-render item callback must be stale')
  assert(tap('back',2));assert(run.gold==gold and count()==before)
  assert(tap(key,3));local confirm=ui.actions.confirm.handler
  assert(tap('confirm',4));assert(run.gold==gold-offer.price and count()==before+1)
  assert(not confirm());assert(run.gold==gold-offer.price and count()==before+1)
 end
end)
test('desktop item confirmation cannot buy a Courier replacement',function()
 for _,category in ipairs({'relics','potions'})do
  local ui,get,emit,tap=setup(false);local run=ui.run
  run.relics[#run.relics+1]='courier';ui:render()
  local slot=category=='relics' and 3 or 1
  local key=category=='relics' and 'shopView/relic3' or 'shopView/potion1'
  local offer=run.nodeFlow[category][slot]
  assert(tap(key,1));local stale=ui.actions.confirm.handler
  if category=='relics' then assert(Nodes.buyRelic(run,offer.id)) else assert(Nodes.buyPotion(run,slot)) end
  assert(run.nodeFlow[category][slot]~=offer,'Courier must replace the selected offer')
  local before=Combat.copy(run)
  assert(not stale(),'confirmation may not buy the replacement offer');same(before,run)
 end
end)
test('hovering any card leaves every unselected card and price anchored',function()
 local ui,get,emit=setup(false)
 local base={}
 for i=1,7 do base[i]={get('shopView/card'..i).y,get('shopView/price'..i).y} end
 for focus=1,7 do
  emit('shopView/card'..focus,'enter');ui:update(.2)
  for i=1,7 do if i~=focus then
   assert(get('shopView/card'..i).y==base[i][1],'unselected card moved: '..i)
   assert(get('shopView/price'..i).y==base[i][2],'unselected price moved: '..i)
  end end
  emit('shopView/card'..focus,'exit');ui:update(.2)
 end
end)
test('stationary pointer on either lower card top edge never cycles focus or its neighbour',function()
 for i=6,7 do
  local ui,get,emit=setup(false);local gold=ui.run.gold
  local tick,bounds=pointerDriver(ui,get,emit)
  local left,_,right,top=bounds(i)
  for frame=1,60 do
   local focus,changes=tick((left+right)/2,top-.1)
   assert(focus=='shopView/card'..i and changes==1,'stationary top edge repeatedly enters/exits')
  end
  assert(get('shopView/card'..i..'/glow').visible)
  assert(not get('shopView/card'..(13-i)..'/glow').visible)
  assert(ui.run.gold==gold)
 end
end)

test('all card edges keep stable targets and moving to a neighbour or empty space releases focus',function()
 local ui,get,emit=setup(false)
 for i=1,7 do
  for _,edge in ipairs({'top','bottom','left','right'}) do
   local tick,bounds=pointerDriver(ui,get,emit)
   local left,bottom,right,top=bounds(i)
   local x=edge=='left' and left+.1 or edge=='right' and right-.1 or (left+right)/2
   local y=edge=='top' and top-.1 or edge=='bottom' and bottom+.1 or (bottom+top)/2
   for frame=1,60 do
    local focus,changes=tick(x,y)
    assert(focus=='shopView/card'..i and changes==1,'animated face changed its edge target: '..i..' '..edge)
   end
   local neighbour=i%7+1
   local nl,nb,nr,nt=bounds(neighbour)
   local focus,changes=tick((nl+nr)/2,(nb+nt)/2)
   assert(focus=='shopView/card'..neighbour and changes==2)
   focus,changes=tick(-1000,-1000)
   assert(focus==nil and changes==3)
   for frame=1,60 do tick(-1000,-1000) end
   assert(get('shopView/card'..i).scale[1]==1 and not get('shopView/card'..i..'/glow').visible)
  end
 end
end)
test('desktop hover enlarges the whole face and moves its price without purchasing',function()
 local ui,get=setup(false);local gold=ui.run.gold
 get('shopView/card1/hit').listeners.enter({})
 ui:update(.2)
 assert(get('shopView/card1').scale[1]>1.1,'shop card needs real hover enlargement')
 assert(get('shopView/price1').y < -12,'price must follow the enlarged face')
 assert(ui.run.gold==gold)
 get('shopView/card1/hit').listeners.exit({});ui:update(.2)
 assert(get('shopView/card1').scale[1]==1)
end)
test('mobile card selection previews then confirms exactly one purchase',function()
 local ui,get,emit,tap=setup(true);local gold,deck=ui.run.gold,#ui.run.deck
 local price=ui.run.nodeFlow.cards[1].price
 assert(tap('shopView/card1',1));assert(ui.run.gold==gold and #ui.run.deck==deck,'preview must not purchase')
 assert(get('confirm/label').text:find('购买'));assert(get('shopView/card1/glow').visible)
 assert(tap('confirm',2));assert(ui.run.gold==gold-price and #ui.run.deck==deck+1)
 assert(get('confirm/label').text=='离开商店')
end)
test('cancel and hide discard the mobile selection without a transaction',function()
 local ui,get,emit,tap=setup(true);local gold=ui.run.gold
 assert(tap('shopView/card6',1));assert(tap('back',2));assert(ui.run.gold==gold)
 assert(get('confirm/label').text=='离开商店')
 assert(tap('shopView/card2',3));ui:setVisible(false);ui:setVisible(true);ui:render()
 assert(get('confirm/label').text=='离开商店' and ui.run.gold==gold)
end)
test('a changed quote retires selection and an already pressed confirmation',function()
 local ui,get,emit,tap=setup(true);local gold=ui.run.gold
 assert(tap('shopView/card1',1));emit('confirm','down',2)
 ui.run.nodeFlow.cards[1].price=ui.run.nodeFlow.cards[1].price+1
 ui:update(.02);emit('confirm','up',2);assert(not emit('confirm','click',2))
 assert(ui.run.gold==gold and not ui.run.nodeFlow.complete)
 assert(get('confirm/label').text=='离开商店')
end)
test('touch relic and potion previews show complete text and require confirmation',function()
 for _,key in ipairs({'relic3','potion1'}) do
  local ui,get,emit,tap=setup(true);local gold=ui.run.gold
  assert(tap('shopView/'..key,1));assert(ui.run.gold==gold)
  assert(get('shopView/detail').visible and #get('shopView/detail/description').text>0)
  assert(tap('confirm',2));assert(ui.run.gold<gold)
 end
end)
test('desktop card preview cancels freely and confirmation buys exactly once',function()
 local ui,get,emit,tap=setup(false);local gold,deck=ui.run.gold,#ui.run.deck
 local price=ui.run.nodeFlow.cards[1].price
 assert(tap('shopView/card1',1));assert(ui.run.gold==gold and #ui.run.deck==deck)
 assert(get('confirm/label').text:find('购买'))
 assert(tap('back',2));assert(ui.run.gold==gold and #ui.run.deck==deck)
 assert(tap('shopView/card1',3));local stale=ui.actions.confirm.handler
 assert(tap('confirm',4));assert(ui.run.gold==gold-price and #ui.run.deck==deck+1)
 assert(not stale());assert(ui.run.gold==gold-price and #ui.run.deck==deck+1)
end)

test('touch can inspect unaffordable relics without arming a purchase',function()
 local ui,get,emit,tap=setup(true);ui.run.gold=0;ui:render()
 local before=Combat.copy(ui.run)
 assert(tap('shopView/relic3',1));ui:update(.2)
 assert(get('shopView/detail').visible and #get('shopView/detail/description').text>0)
 assert(get('confirm/label').text=='暂不可购买' and not ui.actions.confirm.enabled)
 assert(not tap('confirm',2));same(before,ui.run)
 assert(tap('back',3));assert(not get('shopView/detail').visible);same(before,ui.run)
end)

test('touch can inspect stocked potions with full slots and still cannot buy them',function()
 local ui,get,emit,tap=setup(true)
 while Run.potionCount(ui.run)<Run.potionCapacity(ui.run)do assert(Run.obtainPotion(ui.run,'fire_potion'))end
 ui:render();local before=Combat.copy(ui.run)
 assert(tap('shopView/potion1',1));ui:update(.2)
 assert(get('shopView/detail').visible and #get('shopView/detail/description').text>0)
 assert(get('confirm/label').text=='暂不可购买' and not ui.actions.confirm.enabled)
 assert(not tap('confirm',2));same(before,ui.run)
 ui:setVisible(false);ui:setVisible(true);ui:render()
 assert(not get('shopView/detail').visible and get('confirm/label').text=='离开商店');same(before,ui.run)
end)
