-- Mandatory relic choices reuse the approved event panel and its three rows.
local Pending=require('abyss_relic_pending')
local Theme=require('abyss_theme')
local Display=require('abyss_card_display')
local M={}
local function text(ctx,row)
 if row.card then
  local c=row.card;local d=assert(ctx.card(c.cardId),'missing relic choice card')
  local p=assert(ctx.self.presentation[c.cardId],'missing relic choice presentation')
  return ctx.cardName(c.cardId,c.upgraded,c.upgrades),Display.permanentText(p,d,c)
 elseif row.relic then
  return ctx.relicName(row.relic),ctx.relicText(row.relic)
 elseif row.potion then
  local definition
  for _,p in ipairs(ctx.self.run.data.potions.potions)do if p.id==row.potion then definition=p;break end end
  return definition and definition.name or row.potion,ctx.potionText(row.potion)
 end
 return row.title,row.description
end
function M.install(ctx)
 function ctx.renderRelicPending()
  local self=ctx.self;local view=Pending.view(self.run)
  self.pendingGeneration=(self.pendingGeneration or 0)+1
  if not view then self.pendingOwner=nil;return false end
  if self.pendingOwner~=view.owner then self.pendingPage=1;self.notice=''end
  self.pendingOwner=view.owner
  self.renderRun,self.renderMap,self.nodeId=self.run,self.map,nil
  self.view={phase=self.run.phase,node={type='relic_pending',complete=false},pendingRelic=view};self.actions={}
  ctx.shopSelection:clear();ctx.roomMotion:cancel();ctx.merchant:setVisible(false)
  ctx.renderTopBar(nil);ctx.child('title').text='遗物效果'
  for _,name in ipairs({'shopView','campView','pickerView','eventView','treasureView'})do ctx.show(ctx.child(name),name=='eventView')end
  local event=ctx.child('eventView')
  local figure=event:GetChild('neowFigure');if figure then ctx.show(figure,false)end
  local art=event:GetChild('art');if art then ctx.show(art,false)end
  event:GetChild('name').text=view.title
  local count=math.min(3,#Theme.layout.nativeNode.event.options.rows)
  self.pageCount=math.max(1,math.ceil(#view.rows/count))
  self.pendingPage=math.min(self.pendingPage or 1,self.pageCount)
  event:GetChild('caption').text='遗物选择 · '..self.pendingPage..'/'..self.pageCount
  event:GetChild('body').text=view.body
  ctx.child('notice').text=self.notice~=''and self.notice or '请选择一项，完成后返回原界面。'
  local generation,run,owner=self.pendingGeneration,self.run,view.owner
  local function observe()
   return self.visible and not self.busy and not self.presentationBusy
    and self.run==run and self.renderRun==run and self.pendingGeneration==generation
    and Pending.owner(run)==owner
  end
  local function bind(key,enabled,handler)
   ctx.action(key,enabled,function()
    if not observe()then return false,'stale_relic_choice'end
    return handler()
   end,nil,nil,observe)
  end
  for i=1,#Theme.layout.nativeNode.event.options.rows do
   local row=i<=count and view.rows[(self.pendingPage-1)*count+i];local box=event:GetChild('option'..i)
   ctx.show(box,row~=nil);ctx.state(box,row~=nil)
   if row then
    local title,description=text(ctx,row)
    assert(type(title)=='string'and title~=''and type(description)=='string'and description~='', 'missing relic choice description')
    box:GetChild('title').text=title;box:GetChild('description').text=description
    bind('eventView/option'..i,true,function()
     self.busy=true;local called,ok,why=pcall(Pending.resolve,run,row.token);self.busy=false
     if not called then error(ok)end
     self.notice=ok and ''or ({potion_slots_full='药水槽已满，请先丢弃药水或放弃本瓶。'})[why]or '操作未完成，请重新选择。'
     self:render();if ctx.onChange then ctx.onChange(ok,why,self)end
     return ok,why
    end)
   end
  end
  local function page(delta)
   self.pendingPage=self.pendingPage+delta;self.notice='';self:render();return true
  end
  for _,entry in ipairs({{'back','上一页',self.pendingPage>1,-1},{'confirm','下一页',self.pendingPage<self.pageCount,1}})do
   local key,label,enabled,delta=entry[1],entry[2],entry[3],entry[4];local box=ctx.child(key)
   ctx.show(box,self.pageCount>1);box:GetChild('label').text=label;ctx.state(box,enabled)
   bind(key,enabled,function()return page(delta)end)
  end
  return true
 end
end
return M
