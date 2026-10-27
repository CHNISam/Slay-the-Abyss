-- Test-only native field/transform contract. Does not alter the shared fixture.
-- Mirrors the documented image methods used by the pinned standalone exporter;
-- Strict CursorArea fields preserve function/table __index contracts.
local Contract=dofile('tests/lua/support/native_ui_contract.lua')
local M={}
function M.decorate(control)
 if control._nativeArtContract then return control end
 control._nativeArtContract=true
 local old=getmetatable(control) or {}
 if control.kind=='cursorArea' then rawset(control,'interactable',nil) end
 local function allowed(key)
  assert(key~='activeInHierarchy','Native control has no activeInHierarchy field')
  assert(key~='interactable' or control.kind~='cursorArea','Native CursorArea has no interactable field; use raycastTarget')
 end
 setmetatable(control,{__index=function(t,k)
  allowed(k);local index=old.__index
  return type(index)=='function' and index(t,k) or type(index)=='table' and index[k] or nil
 end,__newindex=function(t,k,v)
  allowed(k);if old.__newindex then old.__newindex(t,k,v)else rawset(t,k,v)end
 end})
 if control.kind=='image' then
  for _,entry in ipairs({{'SetAnchorMin','anchorMin'},{'SetAnchorMax','anchorMax'},{'SetPivot','pivot'}})do
   local method,field=entry[1],entry[2]
   control[method]=function(self,x,y)Contract.sizeDelta(x,y);self[field]={x,y}end
  end
  control.SetLocalRotation=function(self,x,y,z)
   Contract.transform3(x,y,z);self.rotation={x,y,z};self.rotationWrites=(self.rotationWrites or 0)+1
  end
 end
 if control.kind=='grid' then
  local refresh=control.RefreshItems
  control.RefreshItems=function(self,n,callback)
   return refresh(self,n,function(item,index)M.decorate(item);return callback(item,index)end)
  end
 end
 for _,child in pairs(control.children or {})do M.decorate(child)end
 return control
end
return M
