-- Preserve the approved ordinary list; expand only independent multi-item rows.
local Theme=require('abyss_theme')
local M={}
-- Last successful size writer per native handle; owner tokens hold no view references.
local sizes=setmetatable({},{__mode='k'})
local function size(control,width,height,owner)
 local painted=sizes[control]
 if owner and painted and painted.owner==owner and painted.width==width
  and painted.height==height and control.alive~=false then return end
 -- A native setter can partially apply before returning false or throwing.
 sizes[control]=nil
 if control:SetSizeDelta(width,height)~=false and owner then
  sizes[control]={owner=owner,width=width,height=height}
 end
end
local names={'goldReward','stolenGold','relicReward1','relicReward2','emeraldKeyReward','claimPotion','cardReward'}
local function visibleRewards(frame)
 local run=frame.run
 local rewards=frame.listing and run.rewards
 local visible={goldReward=rewards and not rewards.goldClaimed,stolenGold=frame.stolen and not frame.stolen.claimed,
  emeraldKeyReward=rewards and rewards.emeraldKey and not rewards.emeraldKey.claimed,
  claimPotion=frame.pendingPotion,cardReward=rewards and not rewards.cardResolved}
 for i=1,2 do
  local item=rewards and rewards.relics and rewards.relics[i]
  visible['relicReward'..i]=item and not item.claimed
 end
 return visible
end
function M.render(frame,child,sizeOwner)
 local visible=visibleRewards(frame)
 local count=0;for _,name in ipairs(names)do if visible[name]then count=count+1 end end
 local base=Theme.layout.battleRewards
 local layout=count>4 and base.expanded or base
 local box=child('rewardList');local stage=layout.stage
 box:SetAnchoredPosition(stage[1],stage[2]);size(box,stage[3],stage[4],sizeOwner)
 size(box:GetChild('border'),stage[3],stage[4],sizeOwner)
 size(box:GetChild('plate'),stage[3]-Theme.space.border*2,stage[4]-Theme.space.border*2,sizeOwner)
 for _,name in ipairs({'title','subtitle'})do
  local position=layout[name];local control=box:GetChild(name)
  control:SetAnchoredPosition(position[1]-stage[1],position[2]-stage[2])
  size(control,position[3],position[4],sizeOwner)
 end
 local row=0
 for _,name in ipairs(names)do
  local control=child(name);control:SetVisible(not not visible[name])
  if visible[name]then
   control:SetAnchoredPosition(layout.rowOrigin[1],layout.rowOrigin[2]-row*layout.rowStep)
   row=row+1
  end
 end
 if frame.manual then child('continue'):SetAnchoredPosition(layout.continue[1],layout.continue[2])end
 local caption=child('potionReward');local position=layout.potionLabel
 caption:SetVisible(frame.pendingPotion==true)
 caption:SetAnchoredPosition(position[1],position[2]);size(caption,position[3],position[4],sizeOwner)
 frame.rewardRows=count
end
return M
