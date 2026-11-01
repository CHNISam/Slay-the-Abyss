local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Portraits=require('abyss_traveler_portraits')
local binding=require('abyss_traveler_portrait_assets')
local backgroundAsset=require('abyss_menu_background_asset')
assert(backgroundAsset.renderProfile=='background-budget-v1','test must use the adaptive background experiment')
assert(#backgroundAsset.data.rows==4500 and backgroundAsset.data.width==480 and backgroundAsset.data.height==270,'background budget or source resolution changed')
binding.imagePrefabId,binding.containerPrefabId=41,73
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local created,destroyed,childCounts={},0,{}
local methods={}
function methods:SetVisible(v)self.visible=v end
function methods:SetActive(v)self.active=v end
for _,pair in ipairs({{'SetAnchorMin','anchorMin'},{'SetAnchorMax','anchorMax'},{'SetPivot','pivot'},
 {'SetSizeDelta','size'},{'SetLocalScale','scale'},{'SetLocalRotation','rotation'},{'SetAnchoredPosition','position'}})do
 methods[pair[1]]=function(self,...)self[pair[2]]={...}end
end
local host=root:GetChild('officialBackground')
for k,v in pairs(methods)do host[k]=v end
Enum={ImageSource={StaticReference='static'},ImageType={Stretch=23}}
Color={FromRGBA=function(...)return {...}end}
game={InstantiateClientUIControl=function(index,parent)
 assert(index==41 or index==73)
 if index==41 then assert(parent.active==false,'native rectangles must be built under inactive groups')end
 childCounts[parent]=(childCounts[parent]or 0)+1
 assert(childCounts[parent]<=60,'compact subtree exceeded native child bound')
 local c=setmetatable({kind=index==41 and 'image' or 'container',parent=parent,alive=true,image=100001,
  anchorMin={.5,.5},anchorMax={.5,.5},pivot={.5,.5},scale={1,1,1},rotation={0,0,0}},
  {__index=methods,__newindex=function(t,k,v)assert(k~='raycastTarget','unsupported image field');rawset(t,k,v)end})
 created[#created+1]=c;return c
end,DestroyClientUIControl=function(c)destroyed=destroyed+1;c.alive=false end}
local bg=require('abyss_menu_background').new(root,print,Portraits.createController)
local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',color=function(...)return {...}end,background=bg})
ui:update(.016)
assert(#created<=256 and root:GetChild('menuPanel'):GetChild('summary').visible,'loading must be bounded and visible')
for _=1,2000 do if bg:status().phase=='ready'then break end;ui:update(.016)end
assert(bg:status().phase=='ready' and host.visible,'compact background never became visible')
assert(#created==backgroundAsset.data.count+math.ceil(backgroundAsset.data.count/60)+math.ceil(backgroundAsset.data.count/3600))
assert(not root:GetChild('menuPanel'):GetChild('summary').visible,'ready loading label remained visible')
local count=#created
bg:sync('node',false,false)
assert(destroyed==0 and not host.visible and not host.active,'navigation must pause without synchronous destruction')
bg:sync('menu',false,false);bg:tick()
assert(#created==count and host.visible and host.active,'return rebuilt a cached background')
bg:onEngineDestroy();assert(destroyed==0,'engine teardown recursively destroyed controls')
for _,c in ipairs(created)do
 if c.kind=='image'then assert(c.image==100001 and c.imageType==23 and c.rotation[3]==0 and c.scale[1]==1)end
end
print('COMPACT_ART_LOADING_PASS '..count..' controls / zero navigation destroys / zero engine destroys')
