-- Existing chest controls display every source reward; commands retain node ownership.
local Nodes=require('abyss_nodes')
local Theme=require('abyss_theme')
local M={}
local kinds={small='小型宝箱',medium='中型宝箱',large='大型宝箱',boss='首领宝箱'}
function M.render(c)
 local self,node=c.self,c.node
 local chest,reward=node.chest,node.reward
 local panel=c.child('treasureView')
 local boss=node.roomKind=='boss_treasure'
 local opened=chest.opened==true
 self.opened=opened
 local items=reward.items
 self.treasureChoice=math.max(1,math.min(self.treasureChoice or 1,#items))
 local item=items[self.treasureChoice]
 local row,take=panel:GetChild('reward'),panel:GetChild('take')
 c.show(panel:GetChild('closed'),not opened);c.show(panel:GetChild('open'),opened)
 c.show(panel:GetChild('hint'),not opened)
 c.tint(panel:GetChild('glow'),opened and Theme.color.gold or Theme.color.goldDim)
 for _,name in ipairs({'previous','next','page','bossDescription'})do c.show(panel:GetChild(name),opened and #items>0)end
 c.show(row,opened and item~=nil);c.show(take,opened and item~=nil)
 local label=''
 if item then
  label=item.kind=='gold' and (item.amount..' 金币') or item.kind=='sapphire' and '蓝钥匙' or c.relicName(item.id)
  local available=item.kind~='relic' or item.available==true
  row:GetChild('name').text=(item.kind=='relic' and '遗物 · ' or '')..label
  row:GetChild('description').text=item.kind=='sapphire' and ('放弃关联遗物「'..c.relicName(item.relicId)..'」；保留金币和额外遗物。')
   or item.kind=='gold' and '独立领取宝箱金币。'
   or available and c.relicText(item.id) or '此遗物尚不可领取；可以领取其他奖励或离开。'
  c.picture(row:GetChild('icon'),item.kind=='gold' and Theme.icon.gold or Theme.icon.relic[item.id] or Theme.icon.node.treasure)
  take:GetChild('label').text=item.kind=='sapphire' and '选择蓝钥匙' or '领取奖励'
  c.state(take,available,false,true)
  panel:GetChild('page').text=(kinds[chest.kind] or '宝箱')..' · '..self.treasureChoice..' / '..#items
  panel:GetChild('bossDescription').text=boss and '选择一件遗物，其余奖励将放弃。' or '各项奖励可以分别领取；遗物与其关联蓝钥匙只能选择一项。'
 end
 for _,step in ipairs({{name='previous',delta=-1},{name='next',delta=1}})do
  local index=self.treasureChoice+step.delta
  c.state(panel:GetChild(step.name),opened and index>=1 and index<=#items)
  c.action('treasureView/'..step.name,opened and index>=1 and index<=#items,function()
   self.treasureChoice=index;self:render();return true
  end)
 end
 c.action('treasureView/chest',not opened,function()
  return c.commit('openTreasure',nil,function()return '已打开宝箱' end)
 end)
 local token=item and Nodes.treasureRewardSource(self.run,item.slot)
 local sourceRun,sourceMap,sourceFlow,sourceReward=self.run,self.map,self.run.nodeFlow,self.run.nodeFlow.reward
 local function owned()
  return self.run==sourceRun and self.map==sourceMap and self.visible and not self.busy
   and self.run.nodeFlow==sourceFlow and sourceFlow.reward==sourceReward and sourceFlow.complete==false
   and self.run.roomGeneration==(token and token.roomGeneration)
 end
 local function takeReward()
  if not owned()then return false,'stale_action' end
  return c.commit(boss and 'claimBossTreasure' or 'claimTreasureReward',boss and self.treasureChoice or token,
   function()return '已领取「'..label..'」'end)
 end
 c.action('treasureView/take',opened and item~=nil and (item.kind~='relic' or item.available==true),takeReward,nil,nil,owned)
 return opened and '领取所需奖励，或离开宝箱。' or ((kinds[chest.kind] or '宝箱')..'就在眼前；可以打开或直接离开。')
end
return M
