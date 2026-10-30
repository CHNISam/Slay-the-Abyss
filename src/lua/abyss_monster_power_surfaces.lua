-- Ordered native power chips only. Source ordering, positions and battle state belong to callers.
local M={}
local managers=setmetatable({},{__mode="k"})
function M.get(row)return managers[row]end
function M.new(statusRow,platform,onCreate,onRetire)
 local api=assert(platform.monsterActors,'monster power template binding unavailable')
 assert(api.enabled and api.powerTemplateIndex>0 and api.containerTemplateIndex>0,'monster power template is not bound')
 assert(type(api.instantiate)=='function' and type(api.destroy)=='function','monster power creation API unavailable')
 local self={records={},slots={},pages={},owned={},order={},generation=0}
 local function check(generation)assert(not self.engineDestroyed and generation==self.generation,'monster power operation cancelled')end
 local function call(c,name,...)
  assert(not self.engineDestroyed,'monster power engine destroyed')
  assert(c[name](c,...)~=false,'monster power '..name..' rejected')
  assert(not self.engineDestroyed,'monster power engine destroyed')
 end
 local function destroy(handle)
  if self.engineDestroyed then return end
  if handle.control.alive==false then handle.destroyed=true;return end
  if handle.destroying or handle.destroyed then return end
  handle.destroying=true
  local hidden,why=pcall(call,handle.control,'SetVisible',false)
  local ok,result=pcall(api.destroy,handle.control)
  handle.destroying=false;handle.destroyed=ok and result~=false
  assert(hidden and handle.destroyed,'monster power cleanup rejected: '..tostring(why or result))
 end
 local function retire(record)
  local handle=record.handle;record.handle=nil
  if not handle then return end
  local ok,why=pcall(function()if onRetire then onRetire(record.slot,handle.control,self.engineDestroyed==true)end end)
  local cleaned,reason=pcall(destroy,handle)
  assert(ok and cleaned,'monster power retirement rejected: '..tostring(why or reason))
 end
 function self.onEngineDestroy(_owner)
  if self.engineDestroyed then return end
  self.engineDestroyed=true;self.generation=self.generation+1
  local records=self.records
  self.records,self.slots,self.pages,self.order,self.owned={},{},{},{},{}
  self.identity,self.depth,self.pendingClear=nil,nil,nil;managers[statusRow]=nil
  local failure
  for _,record in pairs(records)do
   local handle=record.handle;record.handle=nil
   if handle and onRetire then local ok,why=pcall(onRetire,record.slot,handle.control,true);if not ok then failure=why end end
  end
  assert(not failure,failure)
 end
 function self.clear(_owner)
  if self.engineDestroyed then return end
  self.generation=self.generation+1
  -- A native instantiate may re-enter before returning its new child handle.
  -- Defer destruction of its parent until that handle can be owned.
  if self.allocating then self.pendingClear=true;return end
  self.pendingClear=nil
  self.clearing=(self.clearing or 0)+1
  local records,owned=self.records,self.owned
  self.records,self.slots,self.pages,self.order,self.owned={},{},{},{},{}
  self.identity,self.depth=nil,nil
  local failure
  for _,record in pairs(records)do local ok,why=pcall(retire,record);if not ok then failure=why end end
  for i=#owned,1,-1 do
   local handle=owned[i];local ok,why=pcall(destroy,handle)
   if not ok then failure=why end
  end
  -- Preserve parent-before-child allocation order for a later failed-destroy retry.
  for _,handle in ipairs(owned)do if not self.engineDestroyed and not handle.destroyed then self.owned[#self.owned+1]=handle end end
  self.clearing=self.clearing-1
  -- Only successful explicit cleanup unlocks allocation; identity may be nil.
  self.failed=failure and tostring(failure) or nil
  assert(not failure,failure)
 end
 local function allocate(index,parent,generation)
  assert(not self.engineDestroyed,'monster power engine destroyed')
  self.allocating=true
  local ok,control=pcall(api.instantiate,index,parent)
  self.allocating=false
  assert(not self.engineDestroyed,'monster power allocation cancelled by engine teardown')
  local handle
  if ok and control then handle={control=control};self.owned[#self.owned+1]=handle end
  if self.pendingClear then self:clear()end
  assert(ok,control);assert(handle,'monster power allocation failed')
  if generation~=self.generation then destroy(handle);error('monster power allocation cancelled')end
  return handle
 end
 local function set(control,generation,name,...)
  call(control,name,...);check(generation)
 end
 local function pagePath(index,depth)
  local path='root'
  for level=depth-1,1,-1 do path=path..'/'..(math.floor((index-1)/60^level)%60)end
  return path
 end
 local function page(index,depth,generation)
  local parent,path=statusRow,'root'
  for level=depth,1,-1 do
   if level<depth then path=path..'/'..(math.floor((index-1)/60^level)%60)end
   local handle=self.pages[path]
   if not handle then
    handle=allocate(api.containerTemplateIndex,parent,generation);self.pages[path]=handle
    local c=handle.control
    set(c,generation,'SetAnchorMin',.5,.5);set(c,generation,'SetAnchorMax',.5,.5);set(c,generation,'SetPivot',.5,.5)
    set(c,generation,'SetAnchoredPosition',0,0);set(c,generation,'SetLocalScale',1,1,1);set(c,generation,'SetVisible',true)
   end
   set(handle.control,generation,'SetAsLastSibling');parent=handle.control
  end
  return parent,path
 end
 local function selectRows(rows,identity)
  if self.identity~=identity then self:clear();self.identity=identity end
  local depth=1;while #rows>60^depth do depth=depth+1 end
  if self.depth and self.depth~=depth then self:clear();self.identity=identity end
  self.depth=depth
  local generation=self.generation
  local wanted={}
  for _,entry in ipairs(rows)do assert(entry.id~=nil and not wanted[entry.id],'duplicate or missing monster power identity');wanted[entry.id]=true end
  for id,record in pairs(self.records)do
   if not wanted[id]then self.records[id],self.slots[record.slot]=nil,nil;retire(record);check(generation)end
  end
  -- Vacate all outgoing page owners before allocating: no transient child 61.
  for index,entry in ipairs(rows)do
   local record=self.records[entry.id]
   if record and record.path~=pagePath(index,depth)then
    self.records[record.id],self.slots[record.slot]=nil,nil
    retire(record);check(generation)
    self.records[record.id],self.slots[record.slot]=record,record
   end
  end
  local order={}
  for index,entry in ipairs(rows)do
   local parent,path=page(index,depth,generation)
   local record=self.records[entry.id]
   if not record then
    local slot=1;while self.slots[slot]do slot=slot+1 end
    record={id=entry.id,slot=slot};self.records[entry.id],self.slots[slot]=record,record
   end
   record.entry,record.path=entry,path
   if not record.handle then
    record.handle=allocate(api.powerTemplateIndex,parent,generation)
    set(record.handle.control,generation,'SetVisible',false)
    if onCreate then onCreate(record.slot,record.handle.control)end
    check(generation)
   end
   set(record.handle.control,generation,'SetAsLastSibling');order[#order+1]=record
  end
  self.order=order
  local owned={};for _,handle in ipairs(self.owned)do if not handle.destroyed then owned[#owned+1]=handle end end;self.owned=owned
 end
 function self.select(_owner,rows,identity)
  assert(not self.engineDestroyed,'monster power engine destroyed')
  assert(not self.failed,self.failed);assert(not self.selecting and (self.clearing or 0)==0,'reentrant monster power selection')
  self.selecting=true
  local ok,why=pcall(selectRows,rows,identity);self.selecting=false
  if not ok then
   local cleaned,reason=pcall(self.clear,self)
   self.failed=tostring(why)..(cleaned and '' or '; rollback: '..tostring(reason));error(self.failed)
  end
 end
 function self.control(_owner,slot)local r=self.slots[slot];return r and r.handle and r.handle.control end
 function self.entry(_owner,slot)local r=self.slots[slot];return r and r.entry end
 function self.find(_owner,id)local r=self.records[id];if r then return self:control(r.slot),r.slot,r.entry end end
 function self.slotFor(_owner,box)for slot,r in pairs(self.slots)do if r.handle and r.handle.control==box then return slot end end end
 function self.each(_owner,fn)
  local generation=self.generation
  for _,r in ipairs(self.order)do if r.handle then fn(r.handle.control,r.slot,r.entry);if generation~=self.generation then return end end end
 end
 managers[statusRow]=self
 return self
end
return M
