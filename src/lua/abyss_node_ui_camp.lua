-- CampfireSmithEffect -> grid selection -> upgraded-card preview -> confirmation.
local Theme=require('abyss_theme')
local Combat=require('abyss_combat')
local L=Theme.layout.nativeNode.forge
local M={}
function M.labels(selected,node,run)
 if selected then return '重新选牌','确认升级'end
 if node.upgradesLeft<run.data.rules.camp.upgradeCount then return nil,'确认升级'end
 return '返回营地','确认升级'
end
local function find(rows,uid)for _,row in ipairs(rows or {})do if row.uid==uid then return row end end end
function M.new(owner,ui)
 local state={}
 local function preview(picker,selected,result)
  local before,after=picker:GetChild('before'),picker:GetChild('after')
  local upgraded=Combat.copy(selected)
  upgraded.upgrades=(selected.upgrades or (selected.upgraded and 1 or 0))+1;upgraded.upgraded=true
  ui.fillCard(before,selected.cardId,selected.upgraded,{instance=selected,inspectOnly=true})
  ui.fillCard(after,selected.cardId,true,{instance=upgraded,inspectOnly=true})
  before:SetAnchoredPosition(L.previewBefore[1],L.previewBefore[2]);after:SetAnchoredPosition(L.previewAfter[1],L.previewAfter[2])
  before:SetLocalScale(L.previewScale,L.previewScale,1);after:SetLocalScale(L.previewScale,L.previewScale,1)
  picker:GetChild('arrow'):SetAnchoredPosition(L.arrow[1],L.arrow[2])
  picker:GetChild('label').text='升级前'
  picker:GetChild('hint').text=result and '升级完成' or '升级后'
 end
 local function syncRows(node,result)
  if result then return end
  for i,row in ipairs(owner.upgradeRows)do
   local owned=find(owner.run.deck,row.uid)
   if owned then owner.upgradeRows[i]=Combat.copy(owned)end
  end
  if owner.selected and not find(node.upgradeCards,owner.selected)then owner.selected=nil end
 end
 local function renderGrid(grid,enabled,node)
  local count=#L.columns*#L.rows
  local rows=owner.upgradeRows
  owner.pageCount=math.max(1,math.ceil(#rows/count));owner.pickPage=math.min(owner.pickPage or 1,owner.pageCount)
  for i=1,count do
   local box=grid:GetChild('card'..i)
   local instance=rows[(owner.pickPage-1)*count+i]
   ui.show(box,instance~=nil);box:SetLocalScale(1,1,1)
   if instance then
    local available=find(node.upgradeCards,instance.uid)~=nil
    ui.fillCard(box,instance.cardId,instance.upgraded,{instance=instance,dim=not available,stamp=not available and '已升级' or nil})
    local uid,run,flow=instance.uid,owner.run,owner.run.nodeFlow
    ui.action('pickerView/forgeGrid/card'..i,enabled and available,function()
     if owner.run~=run or owner.run.nodeFlow~=flow or owner.picker~='upgrade' or not find(run.deck,uid)then return false,'stale_action'end
     owner.selected=uid;owner.notice='';owner:render();return true
    end)
   end
  end
 end
 local function renderPages(picker,selected)
  for _,step in ipairs({{name='previous',delta=-1},{name='next',delta=1}})do
   local page=owner.pickPage+step.delta
   local enabled=not selected and page>=1 and page<=owner.pageCount
   local name=step.delta<0 and 'forgePrevious' or 'forgeNext'
   ui.show(picker:GetChild(step.name),false)
   ui.show(picker:GetChild(name),enabled);ui.state(picker:GetChild(name),enabled)
   ui.action('pickerView/'..name,enabled,function()owner.pickPage=page;owner:render();return true end)
  end
  picker:GetChild('page'):SetAnchoredPosition(L.page[1],L.page[2])
  picker:GetChild('page').text=not selected and ('可升级 '..#owner.upgradeRows..' 张 · 第 '..owner.pickPage..' / '..owner.pageCount..' 页') or ''
 end
 function state.render(_self,node,result)
  syncRows(node,result)
  local picker=ui.child('pickerView')
  local grid=picker:GetChild('forgeGrid')
  local selected=result and result.card or find(owner.upgradeRows,owner.selected)
  for i=1,6 do ui.show(picker:GetChild('card'..i),false)end
  for _,key in ipairs({'before','after','arrow'})do ui.show(picker:GetChild(key),selected~=nil)end
  ui.show(picker:GetChild('target'),false);ui.show(grid,not selected)
  renderGrid(grid,not selected,node);renderPages(picker,selected)
  for _,name in ipairs({'label','hint'})do
   local box=picker:GetChild(name)
   box:SetAnchoredPosition(L[name][1],L[name][2]);box:SetSizeDelta(L[name][3],L[name][4])
   box.text=''
  end
  picker:GetChild('empty').text=''
  if selected then preview(picker,selected,result)end
  return result and '锻造完成 · 卡牌已升级' or selected and '确认后升级这张牌 · 重新选牌可返回牌组' or '选择一张卡牌锻造'
 end
 function state.hover(_self,box,entered)
  if not owner.visible or owner.picker~='upgrade' or owner.selected then return end
  local scale=entered and L.hoverScale or 1
  box:SetLocalScale(scale,scale,1);box:GetChild('glow'):SetVisible(entered==true)
 end
 return state
end
return M
