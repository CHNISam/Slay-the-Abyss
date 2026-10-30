package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/bounded_native_art_fixture.lua')
local Display=require('abyss_card_display')
local Runtime=require('abyss_card_art_runtime')
F.configure(Runtime)
local art,source=ABYSS_RECTANGLE_METADATA,ABYSS_RECTANGLE_SOURCE
assert(art.rectangleCount==#source,'compact source count mismatch')
local box=F.face();assert(not Display.writeNativeArt(box,{id=art.cardId},art,F.platform,box:GetChild('art'),1))
for _=1,50 do Runtime.update()end
assert(Display.writeNativeArt(box,{id=art.cardId},art,F.platform,box:GetChild('art'),1))
local index=0
for _,control in ipairs(F.created)do
 if control.kind=='image' then
  index=index+1;local row=assert(source[index]);local color=row[5]
  assert(control.image==100001 and control.imageType==23,'native rectangle image/type mismatch')
  assert(control.position[1]==row[1]+row[3]/2-72 and control.position[2]==32-row[2]-row[4]/2,'native rectangle coordinate mismatch')
  assert(control.size[1]==row[3] and control.size[2]==row[4],'native rectangle size mismatch')
  assert(control.imageColor[1]==math.floor(color/65536) and control.imageColor[2]==math.floor(color/256)%256
   and control.imageColor[3]==color%256 and control.imageColor[4]==255,'native rectangle RGB mismatch')
  assert(control.rotation[1]==0 and control.rotation[2]==0 and control.rotation[3]==0,'native rectangle rotation mismatch')
  assert(control.scale[1]==1 and control.scale[2]==1 and control.anchorMin[1]==.5 and control.anchorMax[2]==.5
   and control.pivot[1]==.5 and control.pivot[2]==.5,'native rectangle frame mismatch')
  assert(rawget(control,'raycastTarget')==nil,'image must not use cursor-area fields')
 end
end
assert(index==#source and art.slots==nil,'native rectangle count/eager expansion mismatch')
Runtime.clear();assert(Runtime.status().livePools==0)
print('NATIVE_CARD_ART_RECTANGLE_EQUIVALENCE_PASS '..art.cardId..' '..index)
