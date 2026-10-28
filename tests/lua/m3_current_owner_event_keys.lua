local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
-- Mock-native generated controls with real GameUI/NodeUI/Nodes. Room navigation,
-- event source, key qualification and owner replacement are staged, not earned
-- history, natural campaign, native rendering or performance measurements.
package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local F=require('support.game_ui_fixture')
local H=dofile('tests/helpers/act2_event_ui.lua')
local Run,Map=H.Run,H.Map
local eq=H.eq
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local ui,root=F.fixture(nil,nil,nil,cursor)
local node,mapController=ui.nodeUI,ui.mapUI
local function get(path)local n=root:GetChild('nodePanel');for part in path:gmatch('[^/]+')do n=assert(n:GetChild(part),path)end;return n end
local function click(path,id)
 local hit=get(path):GetChild('hit');id=id or 1;local p=hit;while p do assert(p.visible,'hidden '..path);p=p.parent end
 if hit.listeners.down then hit.listeners.down({touchId=id});hit.listeners.up({touchId=id})end;return hit.listeners.click({touchId=id})
end
local function bind(r,m)
 ui.run,ui.map=r,m;node.run,node.map=r,m;mapController.map=m;node.result,node.notice=nil,'';ui:refresh();eq(ui.mode,'node')
end
assert(ui.run==nil and ui.map==nil and node.run==nil and mapController.map==nil)
eq(node.visible,false);local ok,why=node:render();eq(ok,false);eq(why,'node_unbound')
ok,why=node:setVisible(true);eq(ok,false);eq(why,'node_unbound');eq(node.visible,false)
eq(node:press('confirm'),false);eq(mapController:choose('unbound'),false)
local original=Map.generate;Map.generate=function()error('combined initial Map failure')end
local called,reason=pcall(testStart,ui);Map.generate=original;assert(not called and tostring(reason):find('combined initial Map failure',1,true));assert(ui:closeCharacters())
assert(ui.run==nil and ui.map==nil and node.run==nil and mapController.map==nil);eq(ui.seed,1);assert(testStart(ui))
eq(ui.nodeUI,node);eq(ui.mapUI,mapController);assert(node.run==ui.run and node.map==ui.map and mapController.map==ui.map)
-- The same initially-unbound listener/controller now executes canonical Beggar.
local r,m=H.fixture('beggar',{{uid=7,cardId='strike'},{uid=8,cardId='defend'}},100);bind(r,m)
H.parity(r,m,'donate',nil,function()return click('eventView/option1')end)
H.parity(r,m,'confirm',nil,function()return click('eventView/option1')end)
assert(click('pickerView/card1'));local old=node.actions.confirm.handler;local hit=get('confirm/hit');hit.listeners.down({touchId=31})
-- Stage a qualified camp; an old mandatory purge gesture cannot become Recall.
local kr=Run.new(H.Data,'42',{experimental=true,campaign=true});kr.endingUnlocked=true
local km=Map.generate(H.Data,'42',1);local target
while not target do
 local available=Map.available(km);assert(#available>0)
 for _,n in ipairs(available)do if n.type=='camp'then target=n;break end end
 if not target then assert(Map.choose(km,available[1].id))end
end
assert(H.Nodes.enter(kr,km,target.id));bind(kr,km);eq(get('confirm/label').text,'Recall')
H.unchanged(kr,km,function()hit.listeners.up({touchId=31});return hit.listeners.click({touchId=31})end);H.unchanged(kr,km,old)
local expected,em=H.snapshot(kr),H.Copy(km);assert(H.Nodes.recall(expected,em,assert(H.Nodes.recallSource(expected,em))))
assert(click('confirm',32));H.same(kr,expected);H.same(km,em);eq(kr.keys.ruby,true);eq(r.gold,25);eq(#r.deck,2)
-- Failed restart retains all old published owners; successful retry publishes a
-- fresh Run/Map into the same original controllers, never an old event callback.
kr.phase='defeat';ui:refresh();local seed=ui.seed
Map.generate=function()error('combined restart Map failure')end
called,reason=pcall(testStart,ui);Map.generate=original;assert(not called and tostring(reason):find('combined restart Map failure',1,true));assert(ui:closeCharacters())
eq(ui.run,kr);eq(ui.map,km);eq(node.run,kr);eq(mapController.map,km);eq(ui.seed,seed)
assert(testStart(ui));assert(ui.run~=kr and ui.map~=km);eq(ui.nodeUI,node);eq(ui.mapUI,mapController)
local fresh,freshMap=H.snapshot(ui.run),H.Copy(ui.map);eq(old(),false);H.same(ui.run,fresh);H.same(ui.map,freshMap)
print('M3_CURRENT_OWNER_EVENT_KEYS_PASS nil-owner/factory-failure/start/Beggar/stale-purge/Recall/restart')
