local Surfaces=require('abyss_monster_power_surfaces')
local function fixture(options)
 options=options or {}
 local api={enabled=true,powerTemplateIndex=1,containerTemplateIndex=2,creates=0,destroys=0,operations=0}
 local all={};local manager;local bindings={}
 local function tick(name,c)
  api.operations=api.operations+1
  assert(#c.children<=60 and (not c.parent or #c.parent.children<=60),'native child61 during '..name)
  if api.hook then api.hook(name,c)end
 end
 local function control(parent,kind)
  local c={parent=parent,children={},kind=kind};all[#all+1]=c
  if parent then parent.children[#parent.children+1]=c end
  function c:SetAsLastSibling()
   assert(not self.dead,'setter on dead chip')
   if self.parent then local a=self.parent.children;for i,v in ipairs(a)do if v==self then table.remove(a,i);break end end;a[#a+1]=self end
   tick('SetAsLastSibling',self)
  end
  for _,name in ipairs({'SetVisible','SetAnchorMin','SetAnchorMax','SetPivot','SetAnchoredPosition','SetLocalScale'})do
   c[name]=function(self)assert(not self.dead,'setter on dead chip');tick(name,self)end
  end
  return c
 end
 local host=control(nil,'host');local unrelated=control(host,'unrelated')
 function api.instantiate(index,parent)
  api.creates=api.creates+1
  if api.failAt==api.creates then return nil end
  local c=control(parent,index);tick('instantiate',c);return c
 end
 function api.destroy(c)
  assert(not c.dead,'double destruction');assert(#c.children==0,'parent destroyed before children')
  if api.rejectDestroy then return false end
  c.dead=true;api.destroys=api.destroys+1
  local a=c.parent.children;for i,v in ipairs(a)do if v==c then table.remove(a,i);break end end
  tick('destroy',c)
 end
 manager=Surfaces.new(host,{monsterActors=api},function(slot,box)
  assert(manager:entry(slot),'entry not published before binding');assert(manager:control(slot)==box)
  bindings[box]=true
  if options.create then options.create(manager,slot,box)end
 end,function(slot,box)
  assert(manager:control(slot)~=box,'entry still published during retirement')
  assert(not box.dead,'retirement after destroy')
  bindings[box]=nil
  if options.retire then options.retire(manager,slot,box)end
 end)
 local function clean()
  assert(#host.children==1 and host.children[1]==unrelated and not unrelated.dead,'cleanup touched foreign control or leaked own tree')
  assert(next(bindings)==nil,'bound registration leaked')
  for _,c in ipairs(all)do if c.kind==1 or c.kind==2 then assert(c.dead,'owned allocation leaked')end end
 end
 return manager,api,host,clean
end
local function rows(n)local a={};for i=1,n do a[i]={id='p'..i,status={amount=i}}end;return a end
local function ordered(m,host,list)
 local actual={};local byBox={}
 m:each(function(box,slot,entry)actual[#actual+1]=entry;byBox[box]=entry;assert(m:slotFor(box)==slot)end)
 for i,row in ipairs(list)do assert(actual[i]==row and row.controlSlot==nil,'input/order metadata mutated')end
 local native={};local function walk(c)if c.kind==1 then native[#native+1]=byBox[c]end;for _,child in ipairs(c.children)do walk(child)end end
 walk(host);assert(#native==#list)
 for i,row in ipairs(list)do assert(native[i]==row,'native render order differs from source')end
end
local m,api,host,clean=fixture();local identity={};local list=rows(121)
m:select(list,identity);ordered(m,host,list)
local stable=m:find('p1');local _,slot=m:find('p1')
m:select(list,identity);assert(m:find('p1')==stable)
local inverse={};for i=#list,1,-1 do inverse[#inverse+1]=list[i]end
m:select(inverse,identity);ordered(m,host,inverse)
local _,newSlot=m:find('p1');assert(slot==newSlot,'page relocation changed stable slot')
table.insert(inverse,1,{id='new',status={}});m:select(inverse,identity);ordered(m,host,inverse)
m:clear();clean()
-- Recursive pages, not merely two-level paging or an arbitrary power cap.
m:select(rows(3601),identity);m:clear();clean()
for fail=1,5 do
 m,api,host,clean=fixture();api.failAt=fail
 assert(not pcall(m.select,m,rows(61),identity));clean()
 local count=api.creates;assert(not pcall(m.select,m,{},identity)and api.creates==count,'empty select bypassed failure latch')
 m:clear();api.failAt=nil;m:select(rows(1),identity);m:clear();clean()
end
for fail=1,3 do
 local created=0
 m,api,host,clean=fixture({create=function()created=created+1;if created==fail then error('partial binder failure')end end})
 assert(not pcall(m.select,m,rows(3),identity));clean()
end
m,api,host,clean=fixture({create=function(manager)manager:clear()end})
assert(not pcall(m.select,m,rows(3),identity));clean()
-- Cancel from every native allocation/setter of the first chip and root.
for at=1,11 do
 m,api,host,clean=fixture();local n=0
 api.hook=function(name)if name~='destroy' then n=n+1;if n==at then api.hook=nil;m:clear()end end end
 assert(not pcall(m.select,m,rows(2),identity),'cancellation was ignored at '..at);clean()
end
-- Reentrant select cannot allocate into an in-progress retirement.
m,api,host,clean=fixture({retire=function(manager)assert(not pcall(manager.select,manager,rows(1),{}))end})
m:select(rows(2),identity);m:clear();clean()
local retireOnce=false
m,api,host,clean=fixture({retire=function(manager)if not retireOnce then retireOnce=true;manager:clear()end end})
m:select(rows(2),identity);assert(not pcall(m.select,m,{},identity));clean()
-- A failed destroy stays owned and is retried only by explicit cleanup.
m,api,host,clean=fixture();m:select(rows(1),identity);api.rejectDestroy=true
assert(not pcall(m.clear,m));api.rejectDestroy=false;m:clear();clean()
-- Failed explicit cleanup must latch for both absent and nonnil owner tokens.
for ownerCase=1,2 do
 local owner;if ownerCase==2 then owner={}end
 m,api,host,clean=fixture();m:select(rows(1),owner);api.rejectDestroy=true
 assert(not pcall(m.clear,m) and m.failed,'failed explicit clear unlocked allocations')
 local before=api.creates
 for _,nextRows in ipairs({{},rows(1)})do
  assert(not pcall(m.select,m,nextRows,owner),'same identity bypassed failed-clear latch')
  assert(not pcall(m.select,m,nextRows,{}),'new identity bypassed failed-clear latch')
 end
 assert(api.creates==before,'failed cleanup allowed new native allocations')
 assert(not pcall(m.clear,m) and m.failed,'failed cleanup retry lost latch')
 api.rejectDestroy=false
 assert(not pcall(m.select,m,rows(1),owner),'recovered native destroy bypassed explicit reset')
 assert(api.creates==before)
 m:clear();assert(not m.failed);clean()
 m:select(rows(1),owner);assert(api.creates==before+2);m:clear();clean()
end
print('DYNAMIC_MONSTER_POWER_SURFACES_PASS sourceorder/121reverse/3601/ownership/failures/reentrancy')
