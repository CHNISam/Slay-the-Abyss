local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Map=require('abyss_map')
local cursor={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='endDrag'}
local function hit(root,panel,name)return root:GetChild(panel):GetChild(name):GetChild('hit')end
local function release(control,id)
 control.listeners.down({touchId=id});control.listeners.up({touchId=id})
end
local function tap(control,id)release(control,id);return control.click({touchId=id})end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local cases=0
local function test(name,fn)fn();cases=cases+1;print('ok map menu '..cases..' - '..name)end
test('map menu suppresses duplicate route and old room taps do not revive on close',function()
 local h,r=F.fixture(nil,nil,nil,cursor);assert(F.start(h))
 local room=F.Nodes.available(h.run,h.map)[1]
 local slot;for i,id in pairs(h.mapUI.slots)do if id==room.id then slot=i end end
 local roomHit=F.mapControl(r:GetChild('mapPanel'),'node'..assert(slot)):GetChild('hit')
 release(roomHit,1)
 local before=F.Combat.copy(h.run);local floor=h.map.floor
 assert(h:openMenu())
 local route=hit(r,'runMenu','map')
 assert(not r:GetChild('runMenu'):GetChild('map').visible and not route.interactable and not route.raycastTarget)
 assert(not tap(route,2) and not h.routeOpen,'hidden duplicate route command remained available')
 assert(tap(hit(r,'runMenu','resume'),3))
 assert(not h.exitOpen and not h.menuOpen and h.mapUI.navigationEnabled)
 assert(not roomHit.click({touchId=1}) and h.map.floor==floor,'old map tap crossed menu generation')
 assert(same(before,h.run),'opening and closing map menu changed the run')
 assert(tap(roomHit,4) and h.run.phase=='combat','fresh room tap must remain usable')
end)
test('battle and node previews return in one Back with read-only state and expired menu taps',function()
 for _,context in ipairs({'battle','node'})do
  local h,r=F.fixture(nil,nil,nil,cursor);assert(F.start(h))
  if context=='battle'then assert(Run.startCombat(h.run,'cultist_solo'));h:refresh()
  else
   local routes=dofile('tests/lua/support/map_routes.lua')
   local path=routes.to(h.map,function(node)return node.type=='camp'end)
   for i=1,#path-1 do assert(Map.choose(h.map,path[i]))end
   h.run.floor=h.map.floor
   assert(h.mapUI:choose(routes.at(h.map,path[#path]).id))
  end
  local run,map,battle,flow=h.run,h.map,h.run.combat,h.run.nodeFlow
  local before=F.Combat.copy(run);local mode=h.mode
  assert(h:openMenu());release(hit(r,'runMenu','resume'),10)
  assert(tap(hit(r,'runMenu','map'),11) and h.routeOpen)
  assert(not h.mapUI.navigationEnabled and not h.mapUI:choose('f1_l1'),'route preview must remain read-only')
  if context=='node'then assert(not h.nodeUI:press('campView/rest'))end
  assert(tap(hit(r,'mapPanel','previewBack'),12))
  assert(not h.exitOpen and not h.menuOpen and not h.routeOpen,'one Back left a parent menu')
  assert(h.mode==mode and not r:GetChild('runMenu').visible and not r:GetChild('mapPanel').visible)
  assert(h.run==run and h.map==map and run.combat==battle and run.nodeFlow==flow and same(before,run))
  assert(h:openMenu());assert(not hit(r,'runMenu','resume').click({touchId=10}),'old menu tap revived after preview')
  assert(tap(hit(r,'runMenu','resume'),13))
 end
end)
test('controller Cancel returns from route directly to battle and hides same-map focus',function()
 local focus
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},modes={Specified='specified'},
  getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
 local h,r=F.fixture(nil,nil,nil,cursor,false,nil,nil,api);assert(F.start(h))
 assert(h:openMenu());assert(not hit(r,'runMenu','map').canControllerFocus);assert(h:closeExit())
 assert(Run.startCombat(h.run,'cultist_solo'));h:refresh();assert(h:openMenu())
 local function press(control,kind)
  h:update(.01);h:syncController();assert(control.canControllerFocus);focus=control
  return control.navigationListeners[kind or 'confirm']()
 end
 assert(press(hit(r,'runMenu','map')) and h.routeOpen)
 assert(press(focus,'cancel'))
 assert(not h.exitOpen and not h.menuOpen and not h.routeOpen and h.mode=='battle' and h.battleUI.active)
 h:disable()
end)
print('MAP_MENU_RETURN_PASS '..cases)
