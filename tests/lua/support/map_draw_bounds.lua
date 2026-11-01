-- Independent native-control geometry oracle: measure what is actually painted,
-- including rotated circle corners, rather than the old half-node assumption.
return function(box,viewport)
 local x,y=box.x or box.position[1],box.y or box.position[2]
 for _,name in ipairs({'icon','ring','positionToken','emeraldLabel','hit'})do
  local part=box:GetChild(name)
  if part.visible~=false then
   local px,py=part.x or part.position and part.position[1] or 0,part.y or part.position and part.position[2] or 0
   local w,h=part.w or part.sizeDeltaX or part.size[1],part.h or part.sizeDeltaY or part.size[2]
   local angle=(part.localRotationZ or 0)*math.pi/180
   local rx=(math.abs(w*math.cos(angle))+math.abs(h*math.sin(angle)))/2
   local ry=(math.abs(w*math.sin(angle))+math.abs(h*math.cos(angle)))/2
   assert(y+py-ry>=viewport.bottom-.00001 and y+py+ry<=viewport.top+.00001,'painted '..name..' outside vertical viewport')
   assert(x+px-rx>=viewport.left-.00001 and x+px+rx<=viewport.right+.00001,'painted '..name..' outside horizontal viewport')
  end
 end
end
