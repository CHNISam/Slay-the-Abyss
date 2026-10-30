-- Mandatory source grids for Designer, Duplicator and Augmenter. The modules
-- supply the exact candidates; UI never substitutes the common purge filter.
local Theme=require('abyss_theme')
local Copy=require('abyss_combat')
local M={}
local ids={designer=true,drug_dealer=true}
local layout=Theme.layout.nativeNode.picker
local count=#layout.columns
local function index(list,uid)
 for i,value in ipairs(list)do if value==uid then return i end end
end
local function cardEqual(a,b)
 if a==b then return true end
 if type(a)~='table'or type(b)~='table'then return false end
 for k,v in pairs(a)do if not cardEqual(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
function M.install(ctx)
 function ctx.eventCardsActive(node)
  return node and node.type=='event'and ids[node.event.id]and node.event.stage=='choose_card'
 end
 function ctx.eventGridScreen(node,active)
  if not active then return end
  if ctx.eventCardsActive(node)then return 'pickerView','选择卡牌'end
 end
 function ctx.eventGridFooter(node)
  if ctx.eventCardsActive(node)then return ctx.eventCardsFooter(node)end
  return ctx.pickerFooter(node)
 end
 function ctx.syncEventCards(node,active)
  if not active or not ctx.eventCardsActive(node)then
   ctx.eventCards=nil
   if ctx.self.picker=='event_cards'then ctx.self.mode,ctx.self.picker='main',nil end
   return
  end
  local source=ctx.self.run.nodeFlow
  local state=ctx.eventCards
  if not state or state.run~=ctx.self.run or state.map~=ctx.self.map or state.flow~=source
   or state.event~=source.event or state.choice~=source.event.choice
   or not cardEqual(state.cards,node.event.selectionCards)then
   state={run=ctx.self.run,map=ctx.self.map,flow=source,event=source.event,
    choice=source.event.choice,cards=node.event.selectionCards,selected={}}
   ctx.eventCards=state;ctx.self.pickPage=1
  end
  ctx.self.mode,ctx.self.picker='picker','event_cards'
 end
 -- Capture full permanent instance values AND original identities. An old
 -- native callback may not select against a replaced/mutated deck or local
 -- ordered selection, even if no host refresh happened between touch phases.
 function ctx.eventCardsGuard(run,id)
  if not ids[id]then return nil end
  local deck,owners,values=run.deck,{},{}
  for i,card in ipairs(deck)do
   owners[i]=card;values[i]=Copy.copy(card)
  end
  local state=ctx.eventCards;local selected={}
  for i,uid in ipairs(state and state.selected or {})do selected[i]=uid end
  return function()
   if run.deck~=deck or #deck~=#owners or ctx.eventCards~=state then return false end
   for i,card in ipairs(deck)do if card~=owners[i]or not cardEqual(card,values[i])then return false end end
   return cardEqual(state and state.selected or {},selected)
  end
 end
 local function prepare(picker)
  ctx.show(picker:GetChild('forgeGrid'),false)
  for _,name in ipairs({'forgePrevious','forgeNext','before','after','target','arrow','label','hint'})do
   ctx.show(picker:GetChild(name),false)
  end
  for _,name in ipairs({'page','empty'})do ctx.show(picker:GetChild(name),true)end
  local position=layout.page;picker:GetChild('page'):SetAnchoredPosition(position[1],position[2])
 end
 local function choose(uid,required)
  local selected=ctx.eventCards.selected;local selectedIndex=index(selected,uid)
  if selectedIndex then table.remove(selected,selectedIndex)
  elseif #selected<required then selected[#selected+1]=uid
  else return false,'selection_full'end
  ctx.self.notice='';ctx.self:render();return true
 end
 function ctx.renderEventCards(_,node)
  local picker=ctx.child('pickerView');prepare(picker)
  local event,state=node.event,ctx.eventCards
  local rows=event.selectionCards;local pages=math.max(1,math.ceil(#rows/count))
  ctx.self.pickPage=math.max(1,math.min(ctx.self.pickPage or 1,pages));ctx.self.pageCount=pages
  for i=1,count do
   local card=rows[(ctx.self.pickPage-1)*count+i];local box=picker:GetChild('card'..i)
   ctx.show(box,card)
   if card then
    local uid=card.uid;local ordinal=index(state.selected,uid)
    ctx.fillCard(box,card.cardId,card.upgraded,{instance=card,selected=ordinal~=nil,
     stamp=ordinal and '第 '..ordinal..' 张' or nil})
    ctx.action('pickerView/card'..i,true,function()return choose(uid,event.selection.count)end)
   end
  end
  ctx.pageArrows(picker,'',ctx.self.pickPage,pages)
  for _,direction in ipairs({{key='previous',step=-1},{key='next',step=1}})do
   local step=direction.step;local enabled=step<0 and ctx.self.pickPage>1 or step>0 and ctx.self.pickPage<pages
   ctx.action('pickerView/'..direction.key,enabled,function()
    ctx.self.pickPage=ctx.self.pickPage+step;ctx.self:render();return true
   end)
  end
  picker:GetChild('page').text='第 '..ctx.self.pickPage..'/'..pages..' 页 · 已选 '..#state.selected..'/'..event.selection.count..' 张'
  picker:GetChild('empty').text=#rows<event.selection.count and '可选卡牌不足；原版强制选牌仍待处理，不能跳过或退款。'
   or '依次点选卡牌；再次点选可取消勾选。'
  return event.body..' · 请选择 '..event.selection.count..' 张，不能跳过'
 end
 function ctx.eventCardsFooter(node)
  local selected=ctx.eventCards.selected;local needed=node.event.selection.count
  local label=({upgrade='确认升级',remove='确认移除',full_remove='确认移除',transform='确认变换',duplicate='确认复制'})[node.event.choice]
  return nil,label,#selected==needed,function()
   local value=needed==1 and selected[1]or {selected[1],selected[2]}
   return ctx.commit('chooseEvent',node.event.choice,function()return ctx.self.run.nodeFlow.event.body end,value)
  end
 end
end
return M
