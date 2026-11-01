local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map=require('abyss_map')
local Theme=require('abyss_theme')
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local function same(a,b)
 if type(a)~='table' then assert(a==b);return end
 assert(type(b)=='table');for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
for _,mobile in ipairs({false,true})do
 local ui,root=F.fixture(nil,nil,nil,cursor,nil,nil,{touchScreen=function()return mobile end})
 assert(F.start(ui))
 local routes=dofile('tests/lua/support/map_routes.lua')
 local path=routes.to(ui.map,function(node)return node.type=='shop'end)
 for i=1,#path-1 do assert(Map.choose(ui.map,path[i]))end
 assert(F.Nodes.enter(ui.run,ui.map,path[#path]));ui.run.gold=10000;ui:refresh()
 local node=root:GetChild('nodePanel')
 local back,confirm,merchant=node:GetChild('back'),node:GetChild('confirm'),node:GetChild('merchant')
 local function click(key)return F.click(root,'nodePanel',key)end
 local before=F.Combat.copy(ui.run)
 assert(click('shopView/card1'))
 assert(back.visible and back:GetChild('label').text=='取消选择')
 assert(confirm:GetChild('label').text:find('购买',1,true))
 assert(back.y==(confirm.y or Theme.layout.nativeNode.confirm[2]),'actions must share a row')
 local buyLeft=confirm.x-Theme.layout.nativeNode.confirm[3]/2
 assert(buyLeft-(back.x+Theme.layout.nativeNode.back[3]/2)<=32,'dialogue separates purchase actions')
 same(before,ui.run)
 local current=ui.nodeUI.merchant.current
 assert(click('merchant/talk'))
 same(before,ui.run)
 ui:update(.1)
 assert(ui.nodeUI.merchant.current==current and merchant.visible,'shopping must not reset or hide the active dialogue')
 before=F.Combat.copy(ui.run)
 assert(click('back'));same(before,ui.run)
 assert(confirm.x==Theme.layout.nativeNode.confirm[1],'unselected footer anchor must restore')
 assert(not back.visible and confirm:GetChild('label').text=='离开商店')
 local offer=ui.run.nodeFlow.cards[1];local gold,deck=ui.run.gold,#ui.run.deck
 assert(click('shopView/card1') and click('confirm'))
 assert(ui.run.gold==gold-offer.price and #ui.run.deck==deck+1 and ui.run.nodeFlow.cards[1].sold)
 assert(ui.nodeUI.merchant.current.kind=='buy' and merchant.visible)
 assert(not click('shopView/card1'),'sold offer cannot purchase twice')
 assert(click('confirm') and ui.nodeUI:holding())
 assert(ui.nodeUI.merchant.current.kind=='leave' and not node:GetChild('shopView').visible)
 assert(not back.visible and confirm:GetChild('label').text=='继续')
 assert(click('confirm') and not ui.nodeUI:holding())
end
print('MERCHANT_ACTION_GROUP_PASS mouse/touch cancel, buy, dialogue, farewell')
