local H=dofile('tests/lua/support/current_game_ui_parity_fixture.lua')
-- Reference preserves the original comparator, including its directional cycle map.
local function original(a,b,seen)
 if type(a)~=type(b)then return ' type mismatch' end
 if type(a)~='table'then
  if a~=b then return ': '..tostring(a)..' ~= '..tostring(b)end
  return
 end
 if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do
  local mismatch=original(v,b[k],seen)
  if mismatch then return '.'..tostring(k)..mismatch end
 end
 for k in pairs(b)do if a[k]==nil then return '.'..tostring(k)..' missing' end end
end
local checked=0
local function check(a,b)
 local expected=original(a,b,{})
 local ok,message=pcall(H.same,a,b,'comparator')
 assert(ok==(expected==nil),'acceptance differs from original')
 if expected then assert(message:sub(-#('comparator'..expected))=='comparator'..expected,message)end
 checked=checked+1
end
local f=function()end
local g=function()end
local thread=coroutine.create(function()end)
local values={false,true,0,1,'','1',f,g,thread,{}, {nested={value=3}}}
check(nil,nil)
for _,a in ipairs(values)do
 check(a,nil);check(nil,a)
 for _,b in ipairs(values)do check(a,b);check({nested={value=a}},{nested={value=b}})end
end
check({nested={value=0/0}},{nested={value=0/0}})
local sameTable={value=0/0};check({nested=sameTable},{nested=sameTable})
check({nested={value=false}},{nested={}})
check({nested={}},{nested={value=false}})
check({[2]='two'},{[2]='two'})
local equalMeta={__eq=function()return true end}
check(setmetatable({value=1},equalMeta),setmetatable({value=2},equalMeta))
check({nested=setmetatable({value=1},equalMeta)},{nested=setmetatable({value=2},equalMeta)})
local a,b={},{};a.self=a;b.self=b;check(a,b)
a.value=1;b.value=2;check(a,b)
local shared={value=1}
check({a=shared,b=shared},{a={value=1},b={value=1}})
check({a={value=1},b={value=1}},{a=shared,b=shared})
local left={nested={value=1},catalog={entry='original'}}
local right={nested={value=1},catalog={entry='original'}}
check(left,right);right.nested.value=2;check(left,right)
right.nested.value=1;check(left,right);right.catalog.entry='mutated';check(left,right)
-- Cost regression: scalar leaves must not re-enter the recursive comparator.
local difference
for i=1,10 do local name,value=debug.getupvalue(H.same,i);if name=='difference'then difference=value;break end end
assert(difference,'recursive comparator upvalue not found')
local calls=0
local flatA,flatB={},{}
for i=1,100 do flatA[i]=i;flatB[i]=i end
local function hook(event)
 if event=='call' and debug.getinfo(2,'f').func==difference then calls=calls+1 end
end
debug.sethook(hook,'c')
H.same(flatA,flatB)
debug.sethook()
assert(calls==1,'scalar leaves recursively compared: '..calls)
print('CURRENT_GAME_UI_COMPARATOR_PASS cases='..checked..' recursiveCalls='..calls)
