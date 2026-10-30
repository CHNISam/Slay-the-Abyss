-- Strict engine adapter for runtime templates. Indices are opaque MCP-returned
-- values, deliberately unlike any static image gallery ID.
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Contract=dofile('tests/lua/support/native_ui_contract.lua')
local M={created={},destroyed={}}
function M.install(F,Runtime)
 local dead=setmetatable({},{__mode='k'})
 local function markDead(control)
  dead[control]=true;for _,child in pairs(control.children)do markDead(child)end
 end
 local function instantiate(index,parent)
  assert(index==41 or index==73,'runtime confused templateIndex and gallery image ID')
  local control=Native.decorate(F.control({name='runtime',kind=index==41 and 'image' or 'container',size={1,1}},parent))
  parent.children[#parent.children+1]=control;M.created[#M.created+1]=control
  local prior=getmetatable(control)
  setmetatable(control,{__index=function(t,k)
   if k=='alive' and dead[t]then return false end
   return prior.__index(t,k)
  end,__newindex=prior.__newindex})
  for _,entry in ipairs({{'SetAnchorMin','anchorMin'},{'SetAnchorMax','anchorMax'},{'SetPivot','pivot'}})do
   local method,field=entry[1],entry[2]
   control[method]=function(self,x,y)assert(self.alive);Contract.sizeDelta(x,y);self[field]={x,y}end
  end
  control.SetLocalRotation=function(self,x,y,z)assert(self.alive);Contract.transform3(x,y,z);self.rotation={x,y,z}end
  return control
 end
 Runtime.configure({instantiate=instantiate,destroy=function(c)markDead(c);M.destroyed[#M.destroyed+1]=c end,
  imageTemplateIndex=41,containerTemplateIndex=73})
 return M
end
return M
