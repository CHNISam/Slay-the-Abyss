local A=require('abyss_actor')
local function serialize(v,seen)
 if type(v)=='function'then return 'function'end
 if type(v)~='table'then return type(v)..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do if k~='catalog'and k~='rules'and k~='sourcePools'and k~='statusDefinitions'then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=serialize(k,seen)..'='..serialize(v[k],seen)end
 return '{'..table.concat(rows,';')..'}'
end
for _,name in ipairs({'damage','retaliate','resolveDamageReactions'})do
 local original=A[name]
 A[name]=function(...)
  local args=table.pack(...);local result=table.pack(original(...))
  print('DAMAGE_BOUNDARY '..name..' '..serialize({args=args,result=result}))
  return table.unpack(result,1,result.n)
 end
end
