package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/bounded_native_art_fixture.lua')
local Display=require('abyss_card_display')
local loaded,Runtime=pcall(require,'abyss_card_art_runtime')
assert(loaded,'bounded native art runtime is missing')
F.configure(Runtime)
local function bind(box,meta,uid)return Display.writeNativeArt(box,{id=meta and meta.cardId or 'strike'},meta,F.platform,box:GetChild('art'),uid)end
local function drain()for _=1,100 do Runtime.update()end end
local a=F.metadata('cleave',130);local box=F.face();assert(not bind(box,a,1))
assert(#F.created==0 and box:GetChild('art').visible,'write must defer bounded allocation')
Runtime.update();assert(#F.created==64 and Runtime.status().createdLastUpdate==64,'global creation budget not enforced')
assert(box:GetChild('art').visible and not box:GetChild('artSamples').visible,'partial artwork exposed')
drain();assert(bind(box,a,1));assert(not box:GetChild('art').visible)
assert(#F.created==133,'only the required shapes and 60-child groups may be created')
local first=F.created[2];assert(first.image==106057 and first.rotation[1]==11 and first.imageColor[4]==7 and rawget(first,'raycastTarget')==nil)
local count=#F.created;for _=1,8 do bind(box,a,1);Runtime.update()end;assert(#F.created==count,'unchanged art rebuilt')
local writes=first.writes;assert(bind(box,a,91),'same artwork/new UID unnecessarily returned to fallback')
Runtime.update();assert(#F.created==count and first.alive and first.writes==writes,'same artwork/new UID rebuilt ready geometry')
local b=F.metadata('heavy_blade',1);assert(not bind(box,b,2));assert(not first.alive,'metadata replacement retained old shapes')
drain();assert(bind(box,b,2));Display.clearNativeArt(box);assert(Runtime.status().livePools==0)
-- One global budget and one ten-pool bound, not a budget per card/context.
local faces={};for i=1,12 do faces[i]=F.face();bind(faces[i],a,i)end
local before=#F.created;Runtime.update();assert(#F.created-before==64);assert(Runtime.status().livePools==10)
drain();assert(faces[11]:GetChild('art').visible and faces[12]:GetChild('art').visible)
Display.clearNativeArt(faces[1]);drain();assert(not faces[11]:GetChild('art').visible,'waiting face never acquired released capacity')
assert(faces[12]:GetChild('art').visible,'eleventh pool allocated')
Runtime.clear();assert(Runtime.status().livePools==0)
for _,f in ipairs(faces)do assert(not f:GetChild('artSamples').visible and f:GetChild('art').visible)end
count=#F.created;Runtime.update();assert(#F.created==count,'clear resurrected pending art')
-- Art images have no event callbacks: a same-art UID rebind can retain even
-- partial geometry; explicit metadata/lifetime changes still cancel it.
box=F.face();bind(box,a,1);Runtime.update();first=F.created[#F.created];count=#F.created
bind(box,a,2);assert(first.alive and #F.created==count,'same artwork/new UID discarded pending geometry')
Runtime.update();box.alive=false
Runtime.update();assert(Runtime.status().livePools==0)
-- Failed versions remain fallback without frame retries; explicit clear retries.
box=F.face();F.failCreate=true;bind(box,b,8);Runtime.update();F.failCreate=false
count=#F.created;for i=1,3 do bind(box,b,8+i);Runtime.update()end
assert(#F.created==count and box:GetChild('art').visible,'failed candidate retried each frame')
Display.clearNativeArt(box);bind(box,b,8);drain();assert(not box:GetChild('art').visible)
F.failDestroy=true;local destroys=F.destroyCalls;Display.clearNativeArt(box)
assert(F.destroyCalls==destroys+1,'failed destruction retried within one release')
assert(Runtime.status().livePools==1 and Runtime.status().failedPools==1,'failed destruction escaped global bound')
Runtime.clear();Runtime.update();assert(Runtime.status().livePools==1 and box:GetChild('art').visible)
F.failDestroy=false;Runtime.clear();assert(Runtime.status().livePools==0)
-- A replaced/dropped holder cannot strand the previous pointer's allocation.
box=F.face();bind(box,b,9);drain();box.children.artSamples=nil
assert(not bind(box,b,9));assert(Runtime.status().livePools==0,'missing holder retained stale native allocation')
box=F.face();local enums=F.platform.imageTypes;F.platform.imageTypes=nil;bind(box,b,9);Runtime.update()
assert(Runtime.status().livePools==0 and box:GetChild('art').visible,'slot writer failure exposed partial art')
F.platform.imageTypes=enums;count=#F.created;bind(box,b,9);drain();assert(#F.created==count,'slot failure retried per frame')
Display.clearNativeArt(box);bind(box,a,10);Runtime.update();Runtime.clear();count=#F.created
Runtime.update();assert(#F.created==count and Runtime.status().livePools==0,'partial cancellation resumed')
for _,index in ipairs({0,-1,.5})do
 local ok=pcall(Runtime.configure,{instantiate=F.instantiate,destroy=F.destroy,imageTemplateIndex=index,containerTemplateIndex=73})
 assert(not ok,'unbound/invalid template index admitted')
end
Runtime.configure(nil);box=F.face();assert(not bind(box,b,9));assert(box:GetChild('art').visible)
local deadFallback=box:GetChild('art');box.alive=false;deadFallback.alive=false
assert(not Display.writeNativeArt(box,{id=b.cardId},b,F.platform,deadFallback,9),'dead binding must fail closed')
F.configure(Runtime);box=F.face();bind(box,a,12);Runtime.update()
local destroys=F.destroyCalls or 0
Runtime.onEngineDestroy();Runtime.update()
assert((F.destroyCalls or 0)==destroys,'engine lifecycle must never recursively destroy native controls')
assert(Runtime.status().livePools==0 and not bind(box,a,12),'engine teardown retained active pools')
-- Native static setters can synchronously tear the world down. The guarded
-- publication must expire before the remaining geometry/property writes resume.
box=F.face()
local pool,fallback=box:GetChild('artSamples'),box:GetChild('art')
local group=F.control('container',pool);pool.children.group000=group
local shape=F.control('image',group);group.children.shape0000=shape
local second=F.control('image',group);group.children.shape0001=second
local static=F.metadata('static_teardown',2);static.runtime=nil
local teardown,staleWrites,publication=false,0,nil
local originalImage=shape.SetImage
local originalGuard=Runtime.guardPublication
Runtime.guardPublication=function(intent,control)publication=intent;return originalGuard(intent,control)end
local mt=getmetatable(shape)
setmetatable(shape,{__index=mt.__index,__newindex=function(control,key,value)
 if control.alive==false then staleWrites=staleWrites+1 end
 mt.__newindex(control,key,value)
end})
shape.SetImage=function(self,...)
 originalImage(self,...)
 Runtime.onEngineDestroy();teardown=true
 self.alive=false;second.alive=false;group.alive=false;pool.alive=false;fallback.alive=false;box.alive=false
end
destroys=F.destroyCalls or 0
local published=bind(box,static,13)
Runtime.guardPublication=originalGuard
assert(teardown,'static setter did not re-enter engine teardown')
assert(not published and not Runtime.owns(publication),'engine teardown left a static intent current')
assert(staleWrites==0,'stale static publication wrote an engine-destroyed control')
assert(second.image==nil,'old static publication continued to the next shape')
assert((F.destroyCalls or 0)==destroys,'static teardown invoked native destruction')
print('BOUNDED_NATIVE_ART_PASS batch64/pools10/fairness/metadata/uid/cancel/failure/dead/engine-teardown')
