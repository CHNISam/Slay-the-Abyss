package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local out=assert(io.open('../current-evidence/'..assert(os.getenv('TRACE_NAME'))..'-graph.trace','w'))
local calls=0
local function encode(value)
 local seen,n={},0
 local function visit(v)
  local kind=type(v)
  if kind=='table' then
   if seen[v] then out:write('R',seen[v],';');return end
   n=n+1;seen[v]=n;out:write('T',n,'{')
   local keys={};for k in pairs(v) do keys[#keys+1]=k end
   table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)<type(b) end;return a<b end)
   for _,k in ipairs(keys) do visit(k);visit(v[k]) end
   out:write('}')
  elseif kind=='string' then out:write('s',#v,':',v)
  elseif kind=='number' then out:write('n',string.format('%.17g',v),';')
  elseif kind=='boolean' then out:write(v and 'true;' or 'false;')
  elseif kind=='nil' then out:write('nil;')
  else error('unexpected trace type '..kind) end
 end
 visit(value);out:write('\n')
end
for _,name in ipairs({'new','obtainPotion','startCombat','startRoomCombat','potionView','usePotion','play','endTurn'}) do
 local real=Run[name]
 Run[name]=function(...)
  calls=calls+1;out:write('before ',name,'\n');encode(table.pack(...))
  local result=table.pack(real(...))
  out:write('after ',name,'\n');encode({args=table.pack(...),result=result})
  return table.unpack(result,1,result.n)
 end
end
dofile(assert(os.getenv('FIXTURE')))
out:close();print('GRAPH_TRACE_CALLS',calls)
