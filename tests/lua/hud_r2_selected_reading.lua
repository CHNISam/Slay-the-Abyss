local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=H.F.Theme
for _,size in ipairs({{1280,720},{2048,1150},{2048,1171},{2048,1152}})do
 local host,ui,panel=H.setup({'defend','defend','defend','defend','defend'})
 host:resize(size[1],size[2]);host:update(10)
 local order={}
 for slot=1,5 do
  local card=panel:GetChild('card'..slot)
  local previous=card.SetAsLastSibling
  card.SetAsLastSibling=function(self)previous(self);order[#order+1]=self end
 end
 for _,slot in ipairs({1,3,5})do
  ui:setHover(slot);host:update(10)
  local card=panel:GetChild('card'..slot)
  assert(order[#order]==card,'readable card must be final raised sibling')
  assert(card.localRotationZ==0,'reading pose must be upright')
  local halfH=Theme.layout.card.size[2]*card.localScaleY/2
  assert(card.y-halfH>=-Theme.canvas.base[2]/2+Theme.canvas.safe.y-1e-6,'reading bottom clipped')
  assert(card.y+halfH<=Theme.canvas.base[2]/2-Theme.canvas.safe.y+1e-6,'reading top clipped')
  assert(math.abs(card.x)+Theme.layout.card.size[1]*card.localScaleX/2<=Theme.canvas.base[1]/2-Theme.canvas.safe.x,'reading side clipped')
 end
end
print('HUD_R2_READING_PASS')
