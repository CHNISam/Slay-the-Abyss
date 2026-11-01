local F=dofile('tests/lua/support/game_ui_fixture.lua')
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local Map=require('abyss_map')
local test,finish=H.suite('ROUTE_PREVIEW_RETURN')
local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorEndDrag='endDrag'}
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function emit(hit,kind,id)
 local f=assert(hit.listeners[kind],kind)
 return f({touchId=id,GetUIPos=function()return 640,200 end})
end
local function hit(box)return box:GetChild('hit')end
local function tap(box,id)local h=hit(box);emit(h,'down',id);if h.listeners.up then emit(h,'up',id)end;return emit(h,'click',id)end
local function setup(mode)
 local h,r=F.fixture(nil,nil,nil,cursor);h.seed=42;assert(F.start(h))
 if mode=='battle'then assert(require('abyss_run').startCombat(h.run,'cultist_solo'));h:refresh()
 elseif mode=='shop'then
  local shop
  while not shop do
   local choices=Map.available(h.map);assert(#choices>0)
   for _,n in ipairs(choices)do if n.type=='shop'then shop=n;break end end
   if not shop then assert(Map.choose(h.map,choices[1].id))end
  end
  h.run.floor=h.map.floor;h:refresh();assert(F.Nodes.restoreMap(h.run,h.map));assert(h.mapUI:choose(shop.id))
  assert(h.mode=='node' and h.run.nodeFlow.type=='shop')
 end
 return h,r
end
test('map menu cannot create another map preview',function()
 local h,r=setup('map');local run,map=F.Combat.copy(h.run),F.Combat.copy(h.map)
 assert(tap(r:GetChild('exitEntry'):GetChild('open'),1))
 local box=r:GetChild('runMenu'):GetChild('map')
 assert(not box.visible and not hit(box).interactable and not hit(box).raycastTarget,'map must not preview itself')
 assert(not tap(box,2) and not h.routeOpen)
 assert(tap(r:GetChild('runMenu'):GetChild('resume'),3))
 assert(not h.exitOpen and h.mapUI.visible and same(run,h.run) and same(map,h.map))
end)
for _,mode in ipairs({'battle','shop'})do
 test(mode..' preview returns directly once and rejects stale return/map input',function()
  local h,r=setup(mode);local beforeRun,beforeMap=F.Combat.copy(h.run),F.Combat.copy(h.map)
  local caller=h.mode;local menu=r:GetChild('runMenu')
  assert(tap(r:GetChild('exitEntry'):GetChild('open'),10))
  assert(tap(menu:GetChild('map'),11))
  assert(h.routeOpen and not h.mapUI.navigationEnabled)
  assert(not h.mapUI:choose(Map.available(h.map)[1].id))
  local back=r:GetChild('mapPanel'):GetChild('previewBack')
  assert(tap(back,12))
  assert(not h.routeOpen and not h.menuOpen and not h.exitOpen and not menu.visible,'one return must restore caller without paused menu')
  assert(h.mode==caller and (mode=='battle' and h.battleUI.active or mode=='shop' and h.nodeUI.visible))
  assert(same(beforeRun,h.run) and same(beforeMap,h.map),'preview changed state or RNG')
  assert(not emit(hit(back),'click',12),'old return remained live')
  assert(tap(r:GetChild('exitEntry'):GetChild('open'),20));assert(tap(menu:GetChild('map'),21))
  assert(not emit(hit(back),'click',12) and h.routeOpen,'old return closed new preview')
  assert(tap(back,22) and not h.exitOpen)
  assert(same(beforeRun,h.run) and same(beforeMap,h.map))
 end)
end
finish()
