-- Native controls mirror drawable MonsterGroup instances; no combat/animation state lives here.
local Art=require('abyss_monster_art')
local managers=setmetatable({},{__mode='k'})
local M={}
function M.get(stage)return managers[stage]end
function M.new(stage,platform,onCreate,onRetire)
 local layer=assert(stage:GetChild('actorLayer'),'missing actor layer')
 local api=assert(platform.monsterActors,'monster actor template binding unavailable')
 assert(api.enabled and api.templateIndex>0 and api.containerTemplateIndex>0,'monster actor template is not bound')
 assert(type(api.instantiate)=='function' and type(api.destroy)=='function','monster actor creation API unavailable')
 local self={records={},slots={},pages={},retained={},generation=0}
 local function call(control,name,...)
  assert(not self.engineDestroyed,'monster engine destroyed')
  assert(control[name](control,...)~=false,'monster surface '..name..' rejected')
  assert(not self.engineDestroyed,'monster engine destroyed')
 end
 local function destroy(control)
  if self.engineDestroyed then return end
  if control.alive==false then return end
  local hidden,why=pcall(call,control,'SetVisible',false)
  local ok,result=pcall(api.destroy,control)
  if not ok or result==false then self.retained[#self.retained+1]=control end
  assert(hidden and ok and result~=false,'monster surface cleanup rejected: '..tostring(why or result))
 end
 local function retire(record)
  local box=record.box;record.box=nil
  if not box then return end
  local ok,why=pcall(function()
   if onRetire then onRetire(record.slot,box,self.engineDestroyed==true)end
   if self.engineDestroyed then Art.forgetBox(box)else Art.clearBox(box)end
  end)
  local cleaned,reason=pcall(destroy,box)
  assert(ok and cleaned,'monster surface retirement rejected: '..tostring(why or reason))
 end
 function self.onEngineDestroy(_owner)
  if self.engineDestroyed then return end
  self.engineDestroyed=true;self.generation=self.generation+1
  local records=self.records
  self.records,self.slots,self.pages,self.retained={},{},{},{}
  self.battle,self.depth,self.pendingClear=nil,nil,nil;managers[stage]=nil
  local failure
  for _,record in pairs(records)do
   local box=record.box;record.box=nil
   if box then
    Art.forgetBox(box)
    if onRetire then local ok,why=pcall(onRetire,record.slot,box,true);if not ok then failure=why end end
   end
  end
  assert(not failure,failure)
 end
 function self.clear(_owner)
  if self.engineDestroyed then return end
  self.generation=self.generation+1
  if self.allocating then self.pendingClear=true;return end
  self.pendingClear=nil
  self.clearing=(self.clearing or 0)+1
  local records,pages,retained=self.records,self.pages,self.retained
  self.records,self.slots,self.pages,self.retained={},{},{},{}
  self.battle=nil;self.depth=nil
  local failure
  for _,record in pairs(records)do local ok,why=pcall(retire,record);if not ok then failure=why end end
  -- Destroy deepest page first; controls already reclaimed above.
  local paths={};for path in pairs(pages)do paths[#paths+1]=path end
  table.sort(paths,function(a,b)return #a>#b end)
  for _,path in ipairs(paths)do local ok,why=pcall(destroy,pages[path]);if not ok then failure=why end end
  for _,control in ipairs(retained)do local ok,why=pcall(destroy,control);if not ok then failure=why end end
  self.clearing=self.clearing-1
  self.failed=failure and tostring(failure)or nil
  assert(not failure,failure)
 end
 local function allocate(index,parent,own)
  assert(not self.engineDestroyed,'monster engine destroyed')
  self.allocating=true
  local ok,control=pcall(api.instantiate,index,parent)
  self.allocating=false
  assert(not self.engineDestroyed,'monster allocation cancelled by engine teardown')
  if ok and control then own(control)end
  if self.pendingClear then self:clear();error('monster allocation cancelled')end
  assert(ok,control)
  return assert(control,'monster allocation failed')
 end
 local function pagePath(index,depth)
  local path=''
  for level=depth-1,1,-1 do path=path..'/'..(math.floor((index-1)/60^level)%60)end
  return path
 end
 local function page(index,depth,generation)
  local parent,path=layer,''
  for level=depth-1,1,-1 do
   local digit=math.floor((index-1)/60^level)%60
   path=path..'/'..digit
   local control=self.pages[path]
   if not control then
    control=allocate(api.containerTemplateIndex,parent,function(created)self.pages[path]=created end)
    if generation~=self.generation then destroy(control);error('monster page allocation cancelled')end
    self.pages[path]=control
    call(control,'SetAnchorMin',.5,.5);call(control,'SetAnchorMax',.5,.5);call(control,'SetPivot',.5,.5)
    call(control,'SetAnchoredPosition',0,0);call(control,'SetLocalScale',1,1,1);call(control,'SetVisible',true)
   end
   call(control,'SetAsLastSibling');parent=control
  end
  return parent,path
 end
 local function selectRows(rows,battle)
  if self.battle~=battle then self:clear();self.battle=battle end
  local depth=1;while #rows>60^depth do depth=depth+1 end
  if self.depth and self.depth~=depth then self:clear();self.battle=battle end
  self.depth=depth
  local generation=self.generation
  local wanted={};for _,entry in ipairs(rows)do assert(not wanted[entry.id],'duplicate monster actor identity');wanted[entry.id]=true end
  for id,record in pairs(self.records)do
   if not wanted[id]then self.records[id],self.slots[record.slot]=nil,nil;retire(record)end
  end
  -- Vacate ALL outgoing page owners before adding any incoming actor. Otherwise
  -- a source reorder can transiently create child61 in a currently full page.
  for index,entry in ipairs(rows)do
   local record=self.records[entry.id]
   if record and record.box and record.path~=pagePath(index,depth)then retire(record)end
  end
  for index,entry in ipairs(rows)do
   local parent,path=page(index,depth,generation)
   local record=self.records[entry.id]
   if not record then
    local slot=1;while self.slots[slot]do slot=slot+1 end
    record={id=entry.id,slot=slot};self.records[entry.id],self.slots[slot]=record,record
   end
   if record.path~=path and record.box then retire(record)end
   record.entry,record.path=entry,path
   if not record.box then
    local box=allocate(api.templateIndex,parent,function(created)record.box=created end)
    record.box=box -- Own the returned handle before any re-entrant setter.
    if generation~=self.generation then retire(record);error('monster actor allocation cancelled')end
    call(box,'SetVisible',false)
    if onCreate then onCreate(record.slot,box)end
    assert(generation==self.generation,'monster actor binding cancelled')
   end
   call(record.box,'SetAsLastSibling')
   entry.controlSlot=record.slot
  end
 end
 function self.select(_owner,rows,battle)
  assert(not self.engineDestroyed,'monster engine destroyed')
  assert(not self.failed,self.failed)
  assert(not self.selecting and (self.clearing or 0)==0,'reentrant monster actor selection')
  self.selecting=true
  local ok,why=pcall(selectRows,rows,battle)
  self.selecting=false
  if not ok then
   local cleaned,reason=pcall(self.clear,self)
   self.failed=tostring(why)..(cleaned and '' or '; rollback: '..tostring(reason))
   error(self.failed)
  end
 end
 function self.release(_owner,id)
  local record=self.records[id]
  if record then self.records[id],self.slots[record.slot]=nil,nil;retire(record)end
 end
 function self.control(_owner,slot)local record=self.slots[slot];return record and record.box end
 function self.entry(_owner,slot)local record=self.slots[slot];return record and record.entry end
 function self.slotFor(_owner,box)for slot,record in pairs(self.slots)do if record.box==box then return slot end end end
 function self.find(_owner,id)local record=self.records[id];if record then return record.box,record.slot,record.entry end end
 function self.each(_owner,fn)for slot,record in pairs(self.slots)do if record.box then fn(record.box,slot,record.entry)end end end
 managers[stage]=self
 return self
end
return M
