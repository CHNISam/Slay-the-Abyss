-- Only real loader/test source-root prefixes are coordinates. Business text
-- containing another .lua:line sequence remains part of the observable error.
return function(value)
 if type(value)~='string' then return value end
 local roots={'%./src/lua/','src/lua/','%./build/lua/','build/lua/','%./tests/lua/','tests/lua/'}
 while true do
  local stripped=false
  for _,root in ipairs(roots)do
   local updated,count=value:gsub('^'..root..'[%w_/%-]+%.lua:%d+: ','',1)
   if count==1 then value=updated;stripped=true;break end
  end
  if not stripped then return value end
 end
end
