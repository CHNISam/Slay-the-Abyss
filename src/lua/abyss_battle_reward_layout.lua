-- Preserve the approved ordinary list; expand only independent multi-item rows.
local Theme=require('abyss_theme')
local M={}
local names={'goldReward','stolenGold','relicReward1','relicReward2','emeraldKeyReward','claimPotion','cardReward'}
function M.render(frame,child)
 local run=frame.run
 local rewards=frame.listing and run.rewards
 local visible={goldReward=rewards and not rewards.goldClaimed,stolenGold=frame.stolen and not frame.stolen.claimed,
  emeraldKeyReward=rewards and rewards.emeraldKey and not rewards.emeraldKey.claimed,
  claimPotion=frame.pendingPotion,cardReward=rewards and not rewards.cardResolved}
 for i=1,2 do
  local item=rewards and rewards.relics and rewards.relics[i]
  visible['relicReward'..i]=item and not item.claimed
 end
 local count=0;for _,name in ipairs(names)do if visible[name]then count=count+1 end end
 local base=Theme.layout.battleRewards
 local layout=count>4 and base.expanded or base
 local box=child('rewardList');local stage=layout.stage
 box:SetAnchoredPosition(stage[1],stage[2]);box:SetSizeDelta(stage[3],stage[4])
 box:GetChild('border'):SetSizeDelta(stage[3],stage[4])
 box:GetChild('plate'):SetSizeDelta(stage[3]-Theme.space.border*2,stage[4]-Theme.space.border*2)
 for _,name in ipairs({'title','subtitle'})do
  local position=layout[name];local control=box:GetChild(name)
  control:SetAnchoredPosition(position[1]-stage[1],position[2]-stage[2])
  control:SetSizeDelta(position[3],position[4])
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
 caption:SetAnchoredPosition(position[1],position[2]);caption:SetSizeDelta(position[3],position[4])
 frame.rewardRows=count
end
return M
