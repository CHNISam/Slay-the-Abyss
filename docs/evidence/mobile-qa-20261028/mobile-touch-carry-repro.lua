local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=require('abyss_theme')
do
  local h,u,p,e=H.setup({'defend'},nil,{touchScreen=function()return true end})
  e('card1','down',7)
  e('card1','drag',7,40,-150)
  h:update(0.6)
  local card,layer=p:GetChild('card1'),p:GetChild('dragLayer')
  local bottom=card.y-Theme.layout.card.size[2]*Theme.layout.cardDrag.scale/2
  print('TOUCH_DEFEND_BEFORE_RELEASE','fingerY=-150','cardCenterY='..card.y,'cardBottomY='..bottom,'lineY='..layer:GetChild('line').y,'dropZone='..tostring(u.gesture.dropZone))
  assert(bottom>layer:GetChild('line').y and u.gesture.dropZone==false)
  e('dragLayer','up',7,40,-150)
  print('TOUCH_DEFEND_AFTER_LONG_RELEASE','carry='..tostring(u.carry~=nil),'energy='..h.run.combat.energy,'block='..h.run.combat.player.block)
  assert(u.carry and u.selected and h.run.combat.energy==3 and h.run.combat.player.block==0)
end
do
  local x,y=355,360
  local h,u,p,e,tap=H.setup({'strike','strike'},nil,{touchScreen=function()return true end,position=function()return x,y end})
  e('card1','down',7);e('card1','drag',7,-285,0);e('dragLayer','up',7,-285,0)
  local layer=p:GetChild('dragLayer')
  local oldX,oldY=layer:GetChild('reticle').x,layer:GetChild('reticle').y
  assert(u.carry and u.carry.aiming and not u.gesture and not layer:GetChild('hit').visible)
  x,y=640,360+Theme.layout.hand.y
  h:update(0.016)
  -- An actual released mobile pointer cannot move the now-hidden drag hit.
  -- Even an injected late Drag is ignored because there is no gesture owner.
  e('dragLayer','drag',7,0,Theme.layout.hand.y)
  print('TOUCH_TARGET_AFTER_RELEASE_RETURN','carry='..tostring(u.carry~=nil),'reticleUnchanged='..tostring(oldX==layer:GetChild('reticle').x and oldY==layer:GetChild('reticle').y),'hitVisible='..tostring(layer:GetChild('hit').visible))
  assert(u.carry and u.selected and layer:GetChild('reticle').x==oldX and layer:GetChild('reticle').y==oldY)
  tap('card1',8)
  assert(not u.carry and not u.selected and not layer.visible and h.run.combat.energy==3)
  print('TOUCH_TARGET_SAME_CARD_TAP_CANCELS')
end
print('TOUCH_CARRY_CURRENT_SOURCE_CONFIRMED')
