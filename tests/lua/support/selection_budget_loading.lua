local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Asset=require('abyss_traveler_portrait_assets')
assert(#Asset.avatar96.rows==457 and #Asset.selection133.rows==1940 and #Asset.battle133.rows==4315)
Asset.imagePrefabId,Asset.containerPrefabId=41,73
local lowpolyHero=assert(Asset.lowpolyHero)
assert(#lowpolyHero.rows==2011)
local function profile(useLowpoly,expected)
Asset.lowpolyHero=useLowpoly and lowpolyHero or nil
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local selection=root:GetChild('characterPanel'):GetChild('details'):GetChild('officialSelectionFigure')
local created,destroyed=0,0
local images={}
local methods={}
function methods:SetVisible(value)self.visible=value end
function methods:SetActive(value)self.active=value end
function methods:SetImage(source,id)
 assert(source=='static');self.imageId=id;images[#images+1]=self
end
function methods:SetLocalRotation(x,y,z)self.rotation={x,y,z}end
function methods:SetAsLastSibling()self.ordered=true end
for _,name in ipairs({'SetAnchorMin','SetAnchorMax','SetPivot','SetSizeDelta','SetLocalScale','SetAnchoredPosition'})do
 methods[name]=function()end
end
for _,host in ipairs({selection,root:GetChild('characterPanel'):GetChild('traveler'):GetChild('officialAvatar'),root:GetChild('battlePanel'):GetChild('hero'):GetChild('officialFigure')})do
 for name,method in pairs(methods)do host[name]=method end
end
Enum={ImageSource={StaticReference='static'},ImageType={Stretch=23}}
Color={FromRGBA=function(...)return {...}end}
game={InstantiateClientUIControl=function(index,parent)
 assert(index==41 or index==73,'selection must use bound image/container templates')
 created=created+1
 local c=setmetatable({parent=parent,alive=true},{__index=methods})
 if created==1 then assert(parent==selection,'thumbnail delayed the main figure')end
 return c
end,DestroyClientUIControl=function()destroyed=destroyed+1 end}
local portraits=require('abyss_traveler_portraits').new(root,nil,{selectionAvatar=true,battlePortrait=true})
portraits:sync('menu',true,false,'ironclad')
for _=1,500 do
 local before=created;portraits:tick()
 assert(created-before<=64,'selection exceeded shared per-tick creation budget')
 if portraits:status().avatar.phase=='ready'then break end
end
local status=portraits:status()
assert(status.selection.phase=='ready' and status.avatar.phase=='ready',status.selection.phase..':'..tostring(status.selection.reason)..' / '..status.avatar.phase..':'..tostring(status.avatar.reason))
assert(status.batchSize==64 and status.battle.phase=='idle','selection must retain batch budget and leave battle art unloaded')
assert(created==expected,'unexpected selection native control count: '..created)
if useLowpoly then
 assert(#images==2011,'current selection did not render every low-poly image')
 for i,c in ipairs(images)do
  local row=lowpolyHero.rows[i]
  assert(c.imageId==row[1] and c.rotation[1]==row[19] and c.rotation[2]==row[20]
   and c.rotation[3]==row[14] and c.ordered,'low-poly image/rotation/order drift at row '..i)
 end
else assert(#images==0,'legacy selection must use its rectangle-only profile')end
portraits:sync('map',false,false,'ironclad')
portraits:sync('menu',true,false,'ironclad');portraits:tick()
assert(created==expected and destroyed==0,'return to selection rebuilt cached images')
portraits:onEngineDestroy();assert(destroyed==0)
end
profile(true,2512)
-- Retain the exact legacy selection133 contract, independently of the default low-poly branch.
profile(false,2440)
Asset.lowpolyHero=lowpolyHero
print('SELECTION_BUDGET_LOADING_PASS')
