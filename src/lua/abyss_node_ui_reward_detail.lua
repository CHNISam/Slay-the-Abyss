-- Read-only relic/key details: hover on desktop, hold on mobile; never claims.
local Theme=require('abyss_theme')
local M={}
function M.new(owner,panel,options)
 local state={records={}}
 local function valid(record)
  return record and owner.visible and not owner.presentationBusy and owner.run==record.run
   and owner.map==record.map and owner.view==record.view and owner.actions[record.key]==record.entry
 end
 local function display(record)
  panel:GetChild('name').text=record.name;panel:GetChild('description').text=record.description
  panel:SetVisible(true)
 end
 function state:reset()self.records={};self.held=nil;panel:SetVisible(false)end
 function state:set(key,name,description)
  self.records[key]={key=key,name=name,description=description,run=owner.run,map=owner.map,view=owner.view,entry=owner.actions[key]}
 end
 function state:enter(key)
  if options.touchScreen and options.touchScreen() then return end
  local record=self.records[key];if valid(record)then display(record)end
 end
 function state:exit(key)
  if self.held and self.held.record.key==key then self.held=nil end
  panel:SetVisible(false)
 end
 function state:down(key,event)
  self.swallow=nil;self.held=nil;panel:SetVisible(false)
  local record=self.records[key]
  if valid(record) then self.held={record=record,touch=event and event.touchId,time=0}end
 end
 function state:up(event)
  if self.held and self.held.touch==(event and event.touchId)then self.held=nil end
 end
 function state:consume(key,event)
  local held=self.swallow
  if not held or held.record.key~=key then return false end
  if event and event.touchId~=nil and event.touchId~=held.touch then return false end
  self.swallow=nil;return true
 end
 function state:update(dt)
  local held=self.held;if not held then return end
  if not valid(held.record)then self.held=nil;return end
  held.time=held.time+math.max(0,dt)
  if held.time>=Theme.layout.statusInfo.delay then
   display(held.record);self.swallow=held;self.held=nil
  end
 end
 return state
end
return M
