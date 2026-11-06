local nativeMethods={}
for _,name in ipairs({'SetVisible','SetSizeDelta','SetLocalScale','SetAnchoredPosition','SetImage','SetAnchorMin','SetAnchorMax','SetPivot','SetLocalRotation','SetAsLastSibling','AddCursorEventListener','AddKeyEventListener','AddNavigationEventListener','SetControllerNavigation','RefreshItems'})do nativeMethods[name]=true end
-- Mirror the existing Host trace interception so repeated direct writes count.
return function(control,counts)
 local original=getmetatable(control);local fields,wrappers={},{}
 for k,v in pairs(control)do fields[k]=v end
 for k in pairs(fields)do rawset(control,k,nil)end
 setmetatable(control,{
  __pairs=function()return next,fields,nil end,
  __index=function(_,key)
   assert(key~='interactable' or fields.kind~='cursorArea','Native CursorArea has no interactable field')
   local value=fields[key]
   if value==nil then value=original.__index(control,key)end
   if type(value)~='function' or not nativeMethods[key] then return value end
   if not wrappers[key]then wrappers[key]=function(...)
    counts.nativeCalls=counts.nativeCalls+1;return value(...)
   end end
   return wrappers[key]
  end,
  __newindex=function(_,key,value)
   assert(key~='interactable' or fields.kind~='cursorArea','Native CursorArea has no interactable field')
   assert(key~='alive' and key~='activeInHierarchy','read-only native property')
   counts.propertyWrites=counts.propertyWrites+1;fields[key]=value;wrappers[key]=nil
  end})
end
