package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Display=require('abyss_card_display')
local realPrint,diagnostics=print,{}
print=function(message)if tostring(message):find('ABYSS_NATIVE_ART rejected',1,true)then diagnostics[#diagnostics+1]=message else realPrint(message)end end
assert(type(Display.writeNativeArt)=='function','shared native art binding is missing')
local function shape(name)return {name=name,kind='image',size={1,1},visible=false}end
local box=F.control({name='card',kind='container',children={{name='art',kind='image',size={40,40}},
 {name='artSamples',kind='container',children={{name='group000',kind='container',children={shape('shape0000'),shape('shape0001')}}}}}})
Native.decorate(box)
local fallback=box:GetChild('art');local pool=box:GetChild('artSamples')
local first=pool:GetChild('group000'):GetChild('shape0000');local second=pool:GetChild('group000'):GetChild('shape0001')
local function slot(index,id,kind)return {path={'group000','shape000'..index},image=id,position={1.125,-2.25},size={3.5,4.75},
 anchorMin={.5,.5},anchorMax={.5,.5},pivot={.5,.5},scale={1,1},rotation={23.125,-45.25,9.75},colour={12,34,56,78},imageType=kind}end
local a={cardId='cleave',luaSha256='aaa',capacity=2,slots={slot(0,100003,'stretch'),slot(1,106057,'basic')}}
local b={cardId='heavy_blade',luaSha256='bbb',capacity=2,slots={slot(0,106056,'basic')}}
local platform={imageSource='static',imageTypes={basic=17,stretch=23},color=function(...)return {...}end}
local function bind(meta)return Display.writeNativeArt(box,{id=meta and meta.cardId or 'strike'},meta,platform,fallback)end
assert(bind(a));assert(pool.visible and not fallback.visible)
assert(first.rotation[1]==23.125 and first.rotation[2]==-45.25 and first.rotation[3]==9.75,'XYZ lost')
assert(first.imageType==23 and second.imageType==17 and first.imageColor[4]==78,'native type/RGBA lost')
assert(first.sizeDeltaX==3.5 and first.x==1.125 and first.y==-2.25)
local writes=first.rotationWrites
for _=1,8 do assert(bind(a))end
assert(first.rotationWrites==writes,'same binding rewrote geometry')
assert(bind(b));assert(first.imageType==17 and not second.visible,'smaller art left stale tail/type')
assert(not bind(nil));assert(not pool.visible and fallback.visible)
assert(bind(a));assert(second.visible)
-- Missing, explicit-false and ignored native XYZ/type fail closed; a failed
-- version is not retried every frame. Clear/rebind is the explicit retry edge.
for _,mode in ipairs({'missing','false','throw','ignored-type'})do
 Display.clearNativeArt(box)
 local saved=first.SetLocalRotation;local mt=getmetatable(first)
 if mode=='missing' then first.SetLocalRotation=nil;setmetatable(first,nil)
 elseif mode=='false' then first.SetLocalRotation=function()return false end
 elseif mode=='throw' then first.SetLocalRotation=function()error('native test failure')end
 else
  first.imageType=nil
  setmetatable(first,{__index=mt.__index,__newindex=function(t,k,v)if k~='imageType'then rawset(t,k,v)end end})
 end
 local logged=#diagnostics
 assert(not bind(b),'bad native API must not expose art: '..mode)
 assert(not pool.visible and fallback.visible)
 assert(#diagnostics==logged+1 and diagnostics[#diagnostics]:find('lua_sha256=bbb',1,true),'missing candidate failure diagnostic')
 first.SetLocalRotation=saved;setmetatable(first,mt)
 assert(not bind(b),'failed binding retried without explicit invalidation')
 assert(#diagnostics==logged+1,'cached failure flooded diagnostics')
 Display.clearNativeArt(box);assert(bind(a))
end
assert(bind(a));local enums=platform.imageTypes;platform.imageTypes=nil
assert(not bind(b));assert(not first.visible and not second.visible,'missing enum leaked old/partial slots')
platform.imageTypes=enums;Display.clearNativeArt(box);assert(bind(a))
for _=1,3 do Display.clearNativeArt(box);assert(not pool.visible);assert(bind(a));assert(pool:GetChild('group000'):GetChild('shape0000')==first)end
print('NATIVE_CARD_ART_BINDING_PASS XYZ/type/RGBA/cache/fallback/tail/failure/reuse')
