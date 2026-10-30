-- This legacy artwork regression explicitly opts the candidate into background art.
package.loaded.abyss_art_features={schemaVersion=1,flags={cards=false,menuBackground=true,selectionAvatar=false,battlePortrait=false}}
local F=dofile('tests/lua/support/game_ui_fixture.lua')
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
assert(root:GetChild('menuPanel'):GetChild('heroArt').visible and not host.visible)
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
dofile('src/lua/abyss_ui.lua');OnStart();assert(updates==true,'background failure must not disable the game')
OnUpdate(.01);assert(attempts==1)
assert(root:GetChild('menuPanel'):GetChild('heroArt').visible and not host.visible)
for i=1,10 do OnUpdate(.01)end;assert(attempts==1,'failed creation must not retry every frame')
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
script.object=canvas;dofile('src/lua/abyss_ui.lua');OnStart();OnUpdate(.01)
assert(attempts==64 and destroyed==0 and not host.visible)
local lateUpdate=OnUpdate
OnDestroy();lateUpdate(.01);assert(attempts==64 and destroyed==0 and updates==false)

-- Unexpected native entry errors release art even when the overall game shuts down.
canvas,root,host=make();attempts,destroyed=0,0
script.object=canvas;dofile('src/lua/abyss_ui.lua');OnStart();OnUpdate(.01)
assert(attempts==64)
game.GetUICanvasSize=function()error('canvas diagnostic')end
OnUpdate(.01);assert(destroyed==64 and updates==false and not host.visible)
OnUpdate(.01);assert(attempts==64 and destroyed==64)
OnDestroy();assert(destroyed==64)
print('OFFICIAL_BACKGROUND_ERRORS_PASS')
