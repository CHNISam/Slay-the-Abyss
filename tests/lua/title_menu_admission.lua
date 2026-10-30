local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function route(root)return root:GetChild('runMenu'):GetChild('map'):GetChild('hit')end
local function state(root,enabled)
 local box=root:GetChild('runMenu'):GetChild('map')
 assert(box.visible==enabled,'map entry must be hidden until a real route can be viewed')
 local hit=route(root);assert(hit.interactable==enabled and hit.raycastTarget==enabled,'native map enabled state must match real route admission')
 for _,name in ipairs({'normal','hover','pressed','disabled'})do
  assert(hit:GetChild(name):GetChild('label').text=='查看地图')
 end
end
do
 local h,r=F.fixture();assert(not h.fastMode)
 assert(h:openMenu());state(r,false);assert(not route(r).click() and not h.routeOpen);assert(h:closeExit())
 assert(h:start());assert(h:openMenu());state(r,false);assert(not route(r).click());assert(h:closeExit());assert(h:closeCharacters())
 assert(F.start(h));assert(h:openMenu());state(r,true);assert(route(r).click() and h.routeOpen)
 assert(h:closeExit() and h.menuOpen and not h.routeOpen);assert(h:closeExit())
end
do
 local h,r=F.fixture(nil,nil,nil,nil,true);assert(F.start(h));assert(not h.prologue and h.mode=='map')
 assert(h:openMenu());state(r,true);assert(route(r).click() and h.routeOpen)
end
print('TITLE_MENU_ADMISSION_PASS 4')
