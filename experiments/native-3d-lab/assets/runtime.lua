-- Presentation-only material switch; original background state is restored.
-- Hiding artwork does not prove its allocation or background workers were freed.
local M={}
local owners=setmetatable({},{__mode='k'})
local function child(root,name)
 if not root then return nil end
 local ok,value=pcall(root.GetChild,root,name);return ok and value or nil
end
function M.toggle(root,on)
 assert(type(on)=='boolean','material toggle requires a boolean')
 local stage=child(root,'stage')or root
 local sample=assert(child(stage,'labMaterialBackdrop'),'material specimen missing from candidate')
 local owner=owners[root]
 if on then
  if not owner then owner={controls={}};owners[root]=owner end
  local function hide(control)
   if not control then return end
   if owner.controls[control]==nil then owner.controls[control]=control.visible~=false end
   control:SetVisible(false)
  end
  for _,name in ipairs({'officialBackground','officialBattleBackdrop','lowpolyScene'})do hide(child(stage,name))end
  for _,name in ipairs({'battlePanel','menuPanel'})do
   local panel=child(stage,name)
   for _,image in ipairs({'backdrop','battleBackground','vista','sceneArt','lowpolyVeil'})do hide(child(panel,image))end
  end
  sample:SetVisible(true)
  return '素材样例：官方图片 107134 + 遮罩，共 2 图片；当前战斗未证实减负，非同画质压缩'
 end
 sample:SetVisible(false)
 if owner then
  for control,was in pairs(owner.controls)do if control.alive~=false then pcall(control.SetVisible,control,was)end end
  owners[root]=nil
 end
 return '素材样例关闭，恢复原背景；缓存/官方负载未测'
end
function M.destroy(root)if owners[root]then return M.toggle(root,false)end end
return M
