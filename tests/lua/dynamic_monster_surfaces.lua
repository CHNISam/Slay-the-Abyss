local Surfaces=require('abyss_monster_surfaces')
local function fixture()
 local api={enabled=true,templateIndex=1,containerTemplateIndex=2,creates=0,destroys=0}
 local function control(parent)
  local c={children={},parent=parent,visible=true}
  if parent then parent.children[#parent.children+1]=c;assert(#parent.children<=60,'native parent exceeded60 children')end
  function c:SetVisible(value)self.visible=value end
  function c:SetAnchorMin()end;function c:SetAnchorMax()end;function c:SetPivot()end
  function c:SetAnchoredPosition()end;function c:SetLocalScale()end
  function c:SetAsLastSibling()
   if self.parent then local list=self.parent.children;for i,child in ipairs(list)do if child==self then table.remove(list,i);break end end;list[#list+1]=self end
  end
  return c
 end
 local layer=control();local stage={GetChild=function(_,name)assert(name=='actorLayer');return layer end}
 function api.instantiate(index,parent)
  assert(index==1 or index==2);api.creates=api.creates+1
  if api.reject then return nil end
  local c=control(parent);c.template=index
  if api.reenter and (not api.reenterAt or api.creates==api.reenterAt)then local f=api.reenter;api.reenter=nil;f()end
  return c
 end
 function api.destroy(c)
  assert(not c.destroyed,'double destroy');assert(#c.children==0,'destroyed parent before owned children');c.destroyed=true;api.destroys=api.destroys+1
  if c.parent then for i,child in ipairs(c.parent.children)do if child==c then table.remove(c.parent.children,i);break end end end
 end
 return Surfaces.new(stage,{monsterActors=api}),api,layer
end
local function rows(n)local r={};for i=1,n do r[i]={id='same_'..i,index=i,actor={id='same_'..i,definitionId='acid_slime_m'}}end;return r end
local m,api,layer=fixture();local battle={};local list=rows(6)
m:select(list,battle);assert(api.creates==6 and #layer.children==6,'six drawable instances need six surfaces')
local boxes={};for i=1,6 do boxes[i]=m:find(list[i].id);assert(boxes[i])end
local reversed={};for i=6,1,-1 do reversed[#reversed+1]=list[i]end
m:select(reversed,battle);assert(api.creates==6,'stable actor identity must not rebuild controls')
for i=1,6 do assert(layer.children[i]==boxes[7-i],'source list render order lost')end
m:select({list[2],list[4]},battle);assert(api.destroys==4 and m:find(list[2].id)==boxes[2])
m:clear();assert(api.destroys==6 and #layer.children==0)
m:select(rows(6),{});assert(api.creates==12 and m:find('same_1')~=boxes[1],'new battle cannot reuse old ownership')
m:clear()
-- Lightweight allocation tree isolates native parent limits; full708-control template is tested separately.
local many=rows(121);m:select(many,battle);assert(#layer.children==3)
for _,page in ipairs(layer.children)do assert(#page.children<=60)end
for _,entry in ipairs(many)do assert(m:find(entry.id),'page count cannot truncate drawable actors')end
local inverse={};for i=#many,1,-1 do inverse[#inverse+1]=many[i]end
m:select(inverse,battle)
for _,entry in ipairs(inverse)do assert(m:find(entry.id),'cross-page reversal lost actor')end
local inserted={{id='new-front',index=999,actor={id='new-front'}}}
for _,entry in ipairs(inverse)do inserted[#inserted+1]=entry end
m:select(inserted,battle)
for _,page in ipairs(layer.children)do assert(#page.children<=60,'source front-insert overflowed full page')end
for _,entry in ipairs(inserted)do assert(m:find(entry.id),'source front-insert lost actor')end
m:clear();assert(#layer.children==0)
local full=rows(120);m:select(full,battle)
table.insert(full,1,{id='front120',index=999,actor={id='front120'}})
m:select(full,battle)
for _,entry in ipairs(full)do assert(m:find(entry.id),'120-full-page front insert lost actor')end
m:clear();assert(#layer.children==0)
api.reject=true;local before=api.creates;assert(not pcall(m.select,m,rows(1),battle));assert(api.creates==before+1)
assert(not pcall(m.select,m,rows(1),battle)and api.creates==before+1,'failed native allocation must wait explicit reset')
m:clear();api.reject=false;api.reenter=function()m:clear()end
assert(not pcall(m.select,m,rows(1),battle));assert(#layer.children==0,'reentrant clear leaked returned native control')
m:clear();m:select(rows(1),battle);m:clear();assert(#layer.children==0)
api.reenterAt=api.creates+2;api.reenter=function()m:clear()end
assert(not pcall(m.select,m,rows(121),battle),'reentrant child creation must cancel')
assert(#layer.children==0,'inflight child must retire before its page')
m:clear()
print('DYNAMIC_MONSTER_SURFACES_PASS six/reorder/reuse/pages/failure/reentrancy')
