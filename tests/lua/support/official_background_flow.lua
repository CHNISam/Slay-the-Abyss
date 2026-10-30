local F=dofile('tests/lua/support/game_ui_fixture.lua')
package.loaded.abyss_menu_background_asset={
 adapter=dofile('art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/background_adapter.lua'),
 data=dofile('art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/background_data.lua'),imagePrefabId=0}
local Background=require('abyss_menu_background')
local Asset=require('abyss_menu_background_asset')
Asset.imagePrefabId=987654
local canvas=F.control({children=F.Layout})
local root=F.Viewport.apply(canvas,1280,720)
local dedicated=assert(root:GetChild('officialBackground'))
local created,live,logs={},0,{}
local function native(c)
 function c:SetActive(v)self.enabled=v end
 function c:SetAnchorMin(x,y)self.anchorMin={x,y}end
 function c:SetAnchorMax(x,y)self.anchorMax={x,y}end
 function c:SetPivot(x,y)self.pivot={x,y}end
 function c:SetLocalRotation(x,y,z)self.rotation={x,y,z}end
 return c
end
native(dedicated)
Enum={ImageSource={StaticReference='static'},ImageType={Stretch='stretch'}}
Color={FromRGBA=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
game={InstantiateClientUIControl=function(index,parent)
 assert(index==987654,'must use bound template index, never gallery ID')
 assert(parent==dedicated,'only one stage host')
 local c=native(F.control({name='primitive',kind='image'},parent));created[#created+1]=c;live=live+1;return c
end,DestroyClientUIControl=function(c)
 assert(not c.destroyed);c.destroyed=true;live=live-1
end}
local background=Background.new(root,function(s)logs[#logs+1]=s end)
local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,background=background})
assert(background:status().phase=='building' and not dedicated.visible)
assert(root:GetChild('menuPanel'):GetChild('heroArt').visible)
ui:update(.01);assert(#created==64 and live==64 and not dedicated.visible)
assert(ui:start() and ui.characterOpen)
local token=background:status().generation
ui:update(.01);assert(#created==128 and background:status().generation==token)
assert(ui:closeCharacters());assert(background:status().generation==token)
for i=1,205 do ui:update(.01)end
assert(background:status().phase=='ready' and live==13201 and #created==13201 and dedicated.visible)
local menu=root:GetChild('menuPanel')
assert(not menu:GetChild('heroArt').visible and not menu:GetChild('backdrop').visible)
assert(menu:GetChild('start').visible,'approved start controls must remain')
assert(ui:start() and ui.characterOpen)
assert(not root:GetChild('characterPanel'):GetChild('face').visible,'opaque character base must not cover art')
assert(root:GetChild('characterPanel'):GetChild('blocker').visible,'input shield remains')
ui:update(.01);assert(#created==13201,'ready page switch must not rebuild')
assert(F.confirmStart(ui));assert(live==0 and not dedicated.visible,'release synchronously before any game page')
assert(background:status().phase=='released');ui:update(.01);assert(#created==13201)
assert(menu:GetChild('heroArt').visible,'fallback restored outside title pages')
ui.run=nil;ui.battleUI.run=nil;ui:refresh();ui:update(.01)
assert(live==64 and #created==13265,'reentry creates only fresh bounded batch')
ui:disable();assert(live==0 and not dedicated.visible)
ui:update(.01);assert(live==0)
assert(#logs>=2,'readiness and release diagnostic facts retained')
print('OFFICIAL_BACKGROUND_FLOW_PASS')
