local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Asset=require('abyss_traveler_portrait_assets')
assert(#Asset.avatar96.rows==457 and #Asset.selection133.rows==1940 and #Asset.battle133.rows==4315)
Asset.imagePrefabId,Asset.containerPrefabId=41,73
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local selection=root:GetChild('characterPanel'):GetChild('details'):GetChild('officialSelectionFigure')
local created,destroyed=0,0
local methods={}
function methods:SetVisible(value)self.visible=value end
function methods:SetActive(value)self.active=value end
for _,name in ipairs({'SetAnchorMin','SetAnchorMax','SetPivot','SetSizeDelta','SetLocalScale','SetLocalRotation','SetAnchoredPosition'})do
 methods[name]=function()end
end
for _,host in ipairs({selection,root:GetChild('characterPanel'):GetChild('traveler'):GetChild('officialAvatar'),root:GetChild('battlePanel'):GetChild('hero'):GetChild('officialFigure')})do
 for name,method in pairs(methods)do host[name]=method end
end
Enum={ImageSource={StaticReference='static'},ImageType={Stretch=23}}
Color={FromRGBA=function(...)return {...}end}
game={InstantiateClientUIControl=function(index,parent)
 created=created+1
 local c=setmetatable({parent=parent,alive=true},{__index=methods})
 if created==1 then assert(parent==selection,'thumbnail delayed the main figure')end
 return c
end,DestroyClientUIControl=function()destroyed=destroyed+1 end}
local portraits=require('abyss_traveler_portraits').new(root,nil,{selectionAvatar=true,battlePortrait=true})
portraits:sync('menu',true,false,'ironclad')
for _=1,500 do portraits:tick();if portraits:status().avatar.phase=='ready'then break end end
local status=portraits:status()
assert(status.selection.phase=='ready' and status.avatar.phase=='ready',status.selection.phase..':'..tostring(status.selection.reason)..' / '..status.avatar.phase..':'..tostring(status.avatar.reason))
assert(created==2440,'unexpected selection native control budget: '..created)
portraits:sync('map',false,false,'ironclad')
portraits:sync('menu',true,false,'ironclad');portraits:tick()
assert(created==2440 and destroyed==0,'return to selection rebuilt cached images')
portraits:onEngineDestroy();assert(destroyed==0)
print('SELECTION_BUDGET_LOADING_PASS')
