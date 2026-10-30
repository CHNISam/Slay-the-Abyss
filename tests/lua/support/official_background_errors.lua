-- This legacy artwork regression explicitly opts the candidate into background art.
package.loaded.abyss_art_features={schemaVersion=2,flags={cards=false,menuBackground=true,selectionAvatar=false,battlePortrait=false,monsters=false}}
local F=dofile('tests/lua/support/game_ui_fixture.lua')
-- Assert the actual generated fallback is a nonblank approved official image,
-- not the retired hero overlay. Runtime visibility assertions below use this tree.
local function findSpec(nodes,name)
 for _,node in ipairs(nodes)do
  if node.name==name then return node end
  local found=node.children and findSpec(node.children,name);if found then return found end
 end
end
local menuSpec=assert(findSpec(F.Layout,'menuPanel'))
local backdropSpec=assert(findSpec(menuSpec.children,'backdrop'))
assert(backdropSpec.kind=='image' and backdropSpec.image==F.Theme.image.officialBackdrops.title and backdropSpec.image>0 and backdropSpec.opacity==1)
assert(findSpec(menuSpec.children,'heroArt').visible==false,'merged title intentionally retires the hero overlay')
package.loaded.abyss_menu_background_asset={
 adapter=dofile('art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/background_adapter.lua'),
 data=dofile('art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/background_data.lua'),imagePrefabId=0}
local Background=require('abyss_menu_background')
local Asset=require('abyss_menu_background_asset')
local function make()
 local canvas=F.control({children=F.Layout})
 local root=F.Viewport.apply(canvas,1280,720)
 local host=root:GetChild('officialBackground')
 function host:SetActive()end
 function host:SetAnchorMin()end
 function host:SetAnchorMax()end
 function host:SetPivot()end
 function host:SetLocalRotation()end
 return canvas,root,host
end
local _,root,host=make()
Asset.imagePrefabId=0
local logs={}
local bg=Background.new(root,function(s)logs[#logs+1]=s end)
bg:sync('menu',false,false);assert(bg:status().phase=='failed')
assert(root:GetChild('menuPanel'):GetChild('backdrop').visible and not root:GetChild('menuPanel'):GetChild('heroArt').visible and not host.visible)
for i=1,10 do bg:tick();bg:sync('menu',false,false)end
assert(#logs==1 and logs[1]:find('unbound',1,true),'fallback must state real binding failure exactly once')
bg:release();bg:onEngineDestroy()

local canvas;canvas,root,host=make()
Asset.imagePrefabId=987654
local attempts,destroyed=0,0
Enum={ImageSource={StaticReference='static'},ImageType={Stretch='stretch'},CursorEventType={CursorClick='click'},
 Device={Controller='controller',MobileController='mobileController',Mobile='mobile'}}
Color=setmetatable({FromRGBA=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end},
 {__call=function(_,r,g,b,a)return {r=r,g=g,b=b,a=a}end})
game={InstantiateClientUIControl=function(index,parent)
 assert(index==987654 and parent==host);attempts=attempts+1;error('native create diagnostic')
end,DestroyClientUIControl=function()destroyed=destroyed+1 end,
 GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end,
 GetDevice=function()return 'desktop'end,GetCursorUIPos=function()return 0,0 end}
local updates
script={object=canvas,GetParam=function()return false end,EnableUpdate=function(_,v)updates=v end}
-- The merged native entry defers this illustration to the explicit victory
-- action. Stage only a controlled terminal run, then use its real button/factory;
-- never restore the removed eager title artwork or inject platform.background.
local function openNativeBackground(currentCanvas)
 script.object=currentCanvas
 local GameUI=require('abyss_game_ui')
 local originalNew,actual=GameUI.new
 GameUI.new=function(...)actual=originalNew(...);return actual end
 dofile('tests/lua/support/native_monster_engine.lua')(game)
 dofile('src/lua/abyss_ui.lua');OnStart()
 GameUI.new=originalNew
 assert(updates==true and actual,'actual native entry must remain interactive')
 OnUpdate(.01);assert(attempts==0,'official title must not eagerly create optional artwork')
 assert(root:GetChild('menuPanel'):GetChild('backdrop').visible and not root:GetChild('menuPanel'):GetChild('heroArt').visible)
 actual.seed='2'
 root.ui=actual
 assert(F.click(root,'menuPanel','start') and actual.characterOpen,'official fallback retains its real start click')
 assert(F.click(root,'characterPanel','traveler'))
 assert(F.click(root,'characterPanel','confirm') and actual.run,'actual fallback controls must create the run')
 actual.run.phase='victory';actual.run.nodeFlow={complete=true,result='boss_treasure_complete'};actual:refresh()
 local hit=root:GetChild('menuPanel'):GetChild('result'):GetChild('viewEasterEgg'):GetChild('hit')
 assert(hit.click() and actual.easterEggOpen,'actual victory action must open optional background')
 return actual,hit
end
local current=openNativeBackground(canvas);assert(updates==true,'background failure must not disable the game')
OnUpdate(.01);assert(attempts==1)
assert(root:GetChild('menuPanel'):GetChild('backdrop').visible and not root:GetChild('menuPanel'):GetChild('heroArt').visible and not host.visible)
for i=1,10 do OnUpdate(.01)end;assert(attempts==1,'failed creation must not retry every frame')
assert(root:GetChild('victoryEasterEgg'):GetChild('status').text:find('无法显示',1,true))
assert(root:GetChild('victoryEasterEgg'):GetChild('close'):GetChild('hit').click())
assert(not current.easterEggOpen and root:GetChild('menuPanel').visible,'failed optional artwork must return to interactive official results')
OnDestroy();assert(updates==false and destroyed==0)
OnUpdate(.01);assert(attempts==1,'engine teardown retires callbacks')
-- Engine destruction owns a partially built subtree; old callbacks must not touch it.
canvas,root,host=make();attempts,destroyed=0,0
game.InstantiateClientUIControl=function(index,parent)
 assert(index==987654 and parent==host);attempts=attempts+1
 local c=F.control({name='primitive',kind='image'},parent)
 function c:SetActive()end
 function c:SetAnchorMin()end
 function c:SetAnchorMax()end
 function c:SetPivot()end
 function c:SetLocalRotation()end
 return c
end
openNativeBackground(canvas);OnUpdate(.01)
assert(attempts==64 and destroyed==0 and not host.visible)
local lateUpdate=OnUpdate
OnDestroy();lateUpdate(.01);assert(attempts==64 and destroyed==0 and updates==false)

-- Unexpected native entry errors release art even when the overall game shuts down.
canvas,root,host=make();attempts,destroyed=0,0
openNativeBackground(canvas);OnUpdate(.01)
assert(attempts==64)
game.GetUICanvasSize=function()error('canvas diagnostic')end
OnUpdate(.01);assert(destroyed==64 and updates==false and not host.visible)
OnUpdate(.01);assert(attempts==64 and destroyed==64)
OnDestroy();assert(destroyed==64)
print('OFFICIAL_BACKGROUND_ERRORS_PASS')
