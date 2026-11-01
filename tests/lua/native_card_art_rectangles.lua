package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/bounded_native_art_fixture.lua')
local Display=require('abyss_card_display')
local Runtime=require('abyss_card_art_runtime')
F.configure(Runtime)
local whole='00009040123456'
local small='02030507abcdef'
local function metadata(data,count)
 return {runtime=true,cardId='strike',rectangleEncoding='xywh-rgb24-hex14',rectangles=data,rectangleCount=count}
end
local function bind(box,art)return Display.writeNativeArt(box,{id='strike'},art,F.platform,box:GetChild('art'),1)end
local box=F.face();local art=metadata(whole..small,2)
assert(not bind(box,art));assert(#F.created==0,'compact request allocated native controls synchronously')
Runtime.update();assert(bind(box,art),'compact rectangle artwork was not rendered')
assert(#F.created==3,'compact rectangle count did not drive exact native allocation')
local a,b=F.created[2],F.created[3]
assert(a.image==100001 and a.imageType==23,'compact rectangle must use native stretch rectangle')
assert(a.position[1]==0 and a.position[2]==0 and a.size[1]==144 and a.size[2]==64,'full canvas transform mismatch')
assert(a.imageColor[1]==0x12 and a.imageColor[2]==0x34 and a.imageColor[3]==0x56 and a.imageColor[4]==255,'RGB/opaque colour mismatch')
assert(b.position[1]==-67.5 and b.position[2]==25.5 and b.size[1]==5 and b.size[2]==7,'top-left pixel transform mismatch')
assert(b.rotation[1]==0 and b.rotation[2]==0 and b.rotation[3]==0 and b.scale[1]==1 and b.scale[2]==1)
assert(b.anchorMin[1]==.5 and b.anchorMax[2]==.5 and b.pivot[1]==.5 and not b.raycastTarget)
assert(art.slots==nil and art.rectangles==whole..small,'compact metadata was eagerly expanded/mutated')
Runtime.clear()
-- All malformed rows, including a bad tail, must fail before the first create.
local invalid={metadata(whole,0),metadata(whole,-1),metadata(whole,0/0),metadata(whole,math.huge),metadata(whole,2658),
 metadata(whole,2),metadata('zz009040123456',1),metadata('00000040123456',1),metadata('00009000123456',1),
 metadata('01009040123456',1),metadata('00019040123456',1),metadata(whole..'00009000123456',2)}
local wrong=metadata(whole,1);wrong.rectangleEncoding='unknown';invalid[#invalid+1]=wrong
local mixed=metadata(whole,1);mixed.slots={};invalid[#invalid+1]=mixed
for _,bad in ipairs(invalid)do
 local before=#F.created
 assert(not bind(box,bad));Runtime.update()
 assert(#F.created==before and Runtime.status().livePools==0 and Runtime.status().waitingPools==0,'invalid compact row allocated a partial native pool')
end
-- A large compact asset uses the SAME global scheduler; it is not eager data.
art=metadata(string.rep(small,2657),2657);assert(not bind(box,art));local before=#F.created
Runtime.update();assert(#F.created-before==64 and not box:GetChild('artSamples').visible)
for _=1,50 do Runtime.update()end
assert(bind(box,art));assert(#F.created-before==2657+45)
assert(art.slots==nil,'large compact source was expanded into persistent slot tables')
Runtime.clear();assert(Runtime.status().livePools==0)
print('NATIVE_CARD_ART_RECTANGLES_PASS hex14/lazy/coordinates/RGB/preflight/cap/batch')
