local count=0
local function check(a,b)
 local before,after=old(a,b),new(a,b)
 assert(before==after,'comparison result/path must remain exact: '..tostring(before)..' / '..tostring(after))
 count=count+1
end
local atoms={false,true,0,1,-1,0/0,'','x'}
for _,a in ipairs(atoms)do for _,b in ipairs(atoms)do check(a,b);check({leaf=a},{leaf=b});check({deep={leaf=a}},{deep={leaf=b}})end end
for _,value in ipairs(atoms)do check(value,nil);check(nil,value);check({leaf=value},{});check({},{leaf=value});check({leaf=value},{leaf={}});check({leaf={}},{leaf=value})end
check(nil,nil);check({},{});check({nested={}},{nested={}})
local function copy(value)
 if type(value)~='table'then return value end
 local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
end
local state={phase='player',turn=2,energy=3,player={hp=42,statuses={weak=1,vulnerable=2}},
 enemies={{hp=35,statuses={strength=2}},{hp=19,escaped=false}},hand={{uid=1,cardId='defend'}},events={{kind='damage',detail={amount=18}}}}
check(state,copy(state))
local paths={}
local function collect(value,path)
 for key,item in pairs(value)do local nextPath=copy(path);nextPath[#nextPath+1]=key;paths[#paths+1]=nextPath;if type(item)=='table'then collect(item,nextPath)end end
end
collect(state,{})
for _,path in ipairs(paths)do
 for _,replacement in ipairs({{},{value='CHANGED'},{value=false},{value=0},{value={}}})do
  local changed=copy(state);local owner=changed;for i=1,#path-1 do owner=owner[path[i]]end;owner[path[#path]]=replacement.value
  check(changed,state);check(state,changed)
 end
end
local shared={nested={nan=0/0}};check({a=shared,b=shared},{a=shared,b=shared})
assert(count>400,'all scalar, missing, type and nested mutation cases execute')
print('INTENT_COMPARISON_EQUIVALENCE_PASS '..count)
