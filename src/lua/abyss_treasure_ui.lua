-- Existing chest controls display source rewards; Nodes owns every transaction.
local Nodes=require('abyss_nodes')
local Theme=require('abyss_theme')
local M={}
local kinds={small='小型宝箱',medium='中型宝箱',large='大型宝箱',boss='首领宝箱'}
local displayed=setmetatable({},{__mode='k'})
local function sameToken(a,b)
 if type(a)~='table' or type(b)~='table' then return false end
 for key,value in pairs(a)do if b[key]~=value then return false end end
 for key,value in pairs(b)do if a[key]~=value then return false end end
 return true
end
local function ancestry(root,host,key,box)
 local control,links=root,{}
 for part in key:gmatch('[^/]+')do
  local owner=control;control=owner and owner:GetChild(part)
  links[#links+1]={child=control,owner=owner}
 end
 local attached=not host or host:GetChild('nodePanel')==root
 for _,link in ipairs(links)do if not link.child or link.child.parent~=link.owner then return false end end
 if not attached or control~=box or root.parent~=host then return false end
 local parent=box
 while parent do if not parent.visible then return false end;parent=parent.parent end
 return true
end
local function bind(c,key,box,token,projection,command,argument,describe,choice,expectOpened,itemSnapshot)
 local self=c.self
 local run,map,flow,view=self.run,self.map,self.run.nodeFlow,self.view
 local reward,root=flow.reward,self.root
 local chest,items=flow.chest,reward.items
 local host,parent,link=root.parent,box.parent,reward.sapphireKey
 local generation,act,floor,selection=run.roomGeneration,run.act,run.floor,self.treasureChoice
 local mapId,mapFloor,mapSignature=map.currentNodeId,map.floor,map.sourceSignature
 local desiredOpen=expectOpened~=false
 local handler
 local function owned()
  -- Every logical check follows the final native read, which can reenter render.
  if not ancestry(root,host,key,box)then return false end
  if itemSnapshot then
   local live
   for _,item in ipairs(reward.items)do if item.slot==itemSnapshot.slot then live=item;break end end
   if not live then return false end
   for field,value in pairs(itemSnapshot)do if type(value)~='table' and live[field]~=value then return false end end
  end
  local action=self.actions[key]
  return self.root==root and self.visible and not self.busy and not self.presentationBusy and self.mode=='main'
   and self.run==run and self.map==map and self.view==view and self.opened==desiredOpen
   and run.nodeFlow==flow and flow.reward==reward and flow.complete==false and flow.chest==chest
   and chest.opened==desiredOpen and reward.items==items
   and map.currentNodeId==mapId and map.floor==mapFloor and map.sourceSignature==mapSignature
   and reward.sapphireKey==link and run.roomGeneration==generation and run.act==act and run.floor==floor
   and self.treasureChoice==selection and box.parent==parent
   and action and action.enabled and action.handler==handler
 end
 local function observe()
  if not owned() or type(projection)~='function' then return false end
  local current=projection()
  return sameToken(token,current) and owned()
 end
 handler=function()
  if not observe() then return false,'stale_action' end
  return c.commit(command,argument,describe,choice)
 end
 return handler,observe
end
local function source(self,opened,boss,reward)
 if not opened or boss or type(Nodes.treasureSource)~='function' or type(Nodes.chooseTreasure)~='function' then return nil end
 local token=Nodes.treasureSource(self.run,self.map)
 if type(token)~='table' or token.relicId~=reward.relicId or type(token.relicId)~='string'
  or token.roomGeneration~=self.run.roomGeneration or token.id~=self.run.nodeFlow.id then return nil end
 return token
end
function M.render(c)
 local self,node=c.self,c.node
 local chest,reward=node.chest,node.reward
 local panel=c.child('treasureView')
 local boss,opened=node.roomKind=='boss_treasure',chest.opened==true
 self.opened=opened
 local items=reward.items
 local linked=source(self,opened,boss,reward)
 if displayed[self]~=self.run.nodeFlow.reward then
  displayed[self]=self.run.nodeFlow.reward;self.treasureChoice=1
  if linked then for index,item in ipairs(items)do if item.origin=='base' then self.treasureChoice=index;break end end end
 end
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
  take:GetChild('label').text=linked and item.origin=='base' and '领取遗物' or item.kind=='sapphire' and '选择蓝钥匙' or '领取奖励'
  c.state(take,available,false,true)
  panel:GetChild('page').text=(kinds[chest.kind] or '宝箱')..' · '..self.treasureChoice..' / '..#items
  panel:GetChild('bossDescription').text=boss and '选择一件遗物，其余奖励将放弃。' or '各项奖励可以分别领取；遗物与其关联蓝钥匙只能选择一项。'
 end
 for _,step in ipairs({{name='previous',delta=-1},{name='next',delta=1}})do
  local index=self.treasureChoice+step.delta
  c.state(panel:GetChild(step.name),opened and index>=1 and index<=#items)
  c.action('treasureView/'..step.name,opened and index>=1 and index<=#items,function()
   self.treasureChoice=index;self.notice='';self:render();return true
  end)
 end
 local openToken={id=self.run.nodeFlow.id,generation=self.run.roomGeneration,opened=opened}
 local function openProjection()
  local flow=self.run.nodeFlow
  return flow and {id=flow.id,generation=self.run.roomGeneration,opened=flow.chest and flow.chest.opened}
 end
 local openFn,openObserve=bind(c,'treasureView/chest',panel:GetChild('chest'),openToken,openProjection,
  'openTreasure',nil,function()return '' end,nil,false)
 c.action('treasureView/chest',not opened,openFn,nil,nil,openObserve)
 local token=item and Nodes.treasureRewardSource(self.run,item.slot)
 local command,argument,choice,projection='claimTreasureReward',token,nil
 if boss then command,argument='claimBossTreasure',self.treasureChoice
 elseif linked and item and (item.origin=='base' or item.kind=='sapphire') then
  command,argument,choice='chooseTreasure',linked,item.kind=='sapphire' and 'sapphire' or 'relic';token=linked
 end
 if command=='chooseTreasure' then projection=function()
  return type(Nodes.treasureSource)=='function' and type(Nodes.chooseTreasure)=='function' and Nodes.treasureSource(self.run,self.map)
 end
 else projection=function()return item and Nodes.treasureRewardSource(self.run,item.slot)end end
 local takeFn,observe=bind(c,'treasureView/take',take,token,projection,command,argument,
  function()return '已领取「'..label..'」'end,choice,true,item)
 c.action('treasureView/take',opened and item~=nil and (item.kind~='relic' or item.available==true),takeFn,nil,nil,observe)
 local hint=opened and '领取所需奖励，或离开宝箱。' or ((kinds[chest.kind] or '宝箱')..'就在眼前；可以打开或直接离开。')
 if linked then hint='遗物与蓝钥匙只能选一项 · 选择蓝钥匙将放弃遗物「'..c.relicName(linked.relicId)..'」' end
 if c.list then
  require('abyss_node_ui_treasure_list').render(c,panel,items,opened,linked,bind)
  return hint,nil
 end
 return hint,linked
end
return M
