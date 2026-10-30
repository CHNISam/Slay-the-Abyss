local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Asset=require('abyss_traveler_portrait_assets')
Asset.imagePrefabId,Asset.containerPrefabId=41,73
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local panel=root:GetChild('characterPanel')
panel:SetVisible(false)
local selection=panel:GetChild('details'):GetChild('officialSelectionFigure')
local avatar=panel:GetChild('traveler'):GetChild('officialAvatar')
local battle=root:GetChild('battlePanel'):GetChild('hero'):GetChild('officialFigure')
local created,destroyed=0,0
local methods={}
function methods:SetVisible(value)self.visible=value end
function methods:SetActive(value)self.active=value end
for _,name in ipairs({'SetAnchorMin','SetAnchorMax','SetPivot','SetSizeDelta','SetLocalScale','SetLocalRotation','SetAnchoredPosition'})do
 methods[name]=function()end
end
for _,host in ipairs({selection,avatar,battle})do for name,method in pairs(methods)do host[name]=method end end
Enum={ImageSource={StaticReference='static'},ImageType={Stretch=23}}
Color={FromRGBA=function(...)return {...}end}
game={InstantiateClientUIControl=function(_,parent)
 created=created+1
 if created==1 then assert(parent==selection,'thumbnail preloaded before the main figure')end
 local owner=parent
 while owner.parent do owner=owner.parent;if owner==battle then error('battle art was preloaded')end end
 return setmetatable({parent=parent,alive=true},{__index=methods})
end,DestroyClientUIControl=function()destroyed=destroyed+1 end}
local portraits=require('abyss_traveler_portraits').new(root,nil,{selectionAvatar=true,battlePortrait=true})
portraits:sync('menu',false,false,'ironclad')
portraits:tick();assert(created==0,'legacy sync unexpectedly enabled preloading')
portraits:sync('menu',false,false,'ironclad',true)
assert(created==0,'preload sync created geometry synchronously')
portraits:tick();assert(created>0 and created<=64 and not panel.visible,'preload was unbounded or revealed selection')
local partial=created
portraits:sync('map',false,false,'ironclad',true)
for _=1,10 do portraits:tick()end
assert(created==partial and destroyed==0,'leaving preload did not pause without destroying')
portraits:sync('menu',false,false,'ironclad',true)
for _=1,500 do portraits:tick();if portraits:status().avatar.phase=='ready'then break end end
local status=portraits:status()
assert(status.selection.phase=='ready' and status.avatar.phase=='ready' and status.battle.phase=='idle')
assert(created==2440 and destroyed==0 and not panel.visible,'unexpected preload budget or visible selection')
panel:SetVisible(true)
portraits:sync('menu',true,false,'ironclad',true);portraits:tick()
assert(created==2440 and destroyed==0,'entering selection rebuilt preloaded art')
portraits:sync('menu',false,true,'ironclad',true);portraits:tick()
assert(created==2440 and destroyed==0 and not selection.visible and not avatar.visible,'stopped preload kept active hosts')
portraits:onEngineDestroy();portraits:tick()
assert(destroyed==0 and created==2440,'engine teardown called native destruction')
print('SELECTION_PORTRAIT_PRELOAD_PASS')
