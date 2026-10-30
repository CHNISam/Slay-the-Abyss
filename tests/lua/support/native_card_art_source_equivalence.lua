-- An isolated recording VM executes the pinned standalone export only here.
-- Game code never requires it or instantiates its placeholder prefab ID.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Display=require('abyss_card_display')
local created,errors={},{}
local function control(spec)
 spec=spec or {};local c={children={},name=spec.name,visible=spec.visible~=false}
 function c:GetChild(name)for _,v in ipairs(self.children)do if v.name==name then return v end end end
 function c:SetVisible(v)assert(type(v)=='boolean');self.visible=v end
 function c:SetImage(source,id)assert(source==31);self.image=id end
 function c:SetAnchorMin(x,y)self.anchorMin={x,y}end
 function c:SetAnchorMax(x,y)self.anchorMax={x,y}end
 function c:SetPivot(x,y)self.pivot={x,y}end
 function c:SetSizeDelta(x,y)self.size={x,y}end
 function c:SetLocalScale(x,y,z)assert(z==1);self.scale={x,y}end
 function c:SetLocalRotation(x,y,z)self.rotation={x,y,z};self.writes=(self.writes or 0)+1 end
 function c:SetAnchoredPosition(x,y)self.position={x,y}end
 function c:SetAsLastSibling()self.raised=true end
 for _,child in ipairs(spec.children or {})do c.children[#c.children+1]=control(child)end
 return c
end
local root=control()
local env=setmetatable({script={object=root},Enum={ImageSource={StaticReference=31},ImageType={Basic=17,Stretch=23}},
 Color={FromRGBA=function(...)return {...}end},printerr=function(reason)errors[#errors+1]=reason end,
 game={InstantiateClientUIControl=function(id,parent)
  assert(id==1234 and parent==root);local c=control();created[#created+1]=c;return c
 end,DestroyClientUIControl=function(c)assert(not c.destroyed);c.destroyed=true end}}, {__index=_G})
assert(load(ABYSS_EXPORTED_ART,'@isolated-upstream-literal','t',env))()
env.OnStart();assert(#created==0 and #errors==1,'source prefab ID 0 must fail closed')
local configured,n=ABYSS_EXPORTED_ART:gsub('local IMAGE_PREFAB_ID = 0','local IMAGE_PREFAB_ID = 1234',1)
assert(n==1);errors={}
assert(load(configured,'@isolated-upstream-literal-configured','t',env))()
env.OnStart();assert(#errors==0,table.concat(errors,';'))
assert(#created==#ABYSS_METADATA.slots,'upstream drawing count differs')
local source=created
local box=control({children={{name='art'},ABYSS_NATIVE_POOL}})
local platform={imageSource=31,imageTypes={basic=17,stretch=23},color=function(...)return {...}end}
assert(Display.writeNativeArt(box,{id=ABYSS_METADATA.cardId},ABYSS_METADATA,platform,box:GetChild('art')))
local pool=box:GetChild('artSamples');local visible={}
for _,group in ipairs(pool.children)do for _,c in ipairs(group.children)do if c.visible then visible[#visible+1]=c end end end
assert(#source==#visible,'runtime visible art count differs')
local function exact(a,b,key,index)
 if type(a)=='table'then assert(#a==#b,key);for i=1,#a do exact(a[i],b[i],key,index)end
 else assert(a==b,('native source mismatch %s #%s: %s ~= %s'):format(key,index,tostring(a),tostring(b)))end
end
local gallery=0
for i,want in ipairs(source)do
 local got=visible[i]
 for _,key in ipairs({'image','imageType','anchorMin','anchorMax','pivot','size','scale','rotation','position','imageColor'})do exact(want[key],got[key],key,i)end
 if want.image==106056 or want.image==106057 then gallery=gallery+1 end
 assert(want.raised,'source layer order requires explicit sibling append')
end
assert(gallery==(ABYSS_EXPECTED_GALLERY_COUNT or 3),'source gallery controls must not be discarded')
assert(Display.writeNativeArt(box,{id=ABYSS_METADATA.cardId},ABYSS_METADATA,platform,box:GetChild('art')))
for _,c in ipairs(visible)do assert(c.writes==1,'unchanged art reapplied native geometry')end
Display.clearNativeArt(box);for _,c in ipairs(visible)do assert(not c.visible,'clear leaked active shape')end
env.OnDestroy();for _,c in ipairs(source)do assert(c.destroyed,'upstream teardown incomplete')end
assert(Display.writeNativeArt(box,{id=ABYSS_METADATA.cardId},ABYSS_METADATA,platform,box:GetChild('art')))
print('NATIVE_SOURCE_EQUIVALENCE_PASS '..ABYSS_METADATA.cardId..' shapes='..#source..' gallery='..gallery..' exact XYZ/Basic/Stretch/RGBA/order; MOCK ONLY')
