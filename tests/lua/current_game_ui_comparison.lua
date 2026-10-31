local H=dofile('tests/lua/support/current_game_ui_parity_fixture.lua')
-- Exact comparator body from 96411b6c; an independent semantic reference.
local function reference(a,b,seen)
 if type(a)~=type(b)then return ' type mismatch' end
 if type(a)~='table'then
  if a~=b then return ': '..tostring(a)..' ~= '..tostring(b)end
  return
 end
 if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do
  local mismatch=reference(v,b[k],seen)
  if mismatch then return '.'..tostring(k)..mismatch end
 end
 for k in pairs(b)do if a[k]==nil then return '.'..tostring(k)..' missing' end end
end
local count=0
local function compare(a,b,want)
 local expected=reference(a,b,{})
 local ok,actual=pcall(H.same,a,b,'root')
 assert(ok==(expected==nil),'old/new success disagreement')
 if expected then
  assert(type(actual)=='string' and actual:sub(-#('root'..expected))=='root'..expected,'old/new diagnostic disagreement: '..tostring(actual))
 end
 if want~=nil then assert(ok==want,'negative control was not rejected')end
 count=count+1
end
compare(1,1,true);compare(1,2,false);compare(1,'1',false);compare(nil,nil,true);compare(false,nil,false)
compare({nested={deep={value=1}}},{nested={deep={value=2}}},false)
local a,b={},{}
for i=1,2000 do a[i]=i;b[i]=i end
compare(a,b,true);b[2000]=-1;compare(a,b,false)
compare({nested={value=1}},{nested={}},false)
compare({nested={}},{nested={value=1}},false)
compare({nested={value=1}},{nested={value='1'}},false)
compare({nested=false},{nested={}},false)
compare({flag=false},{flag=false},true)
compare({flag=false},{},false)
compare({[false]='value',[10]=true},{[false]='value',[10]=true},true)
local ca,cb={value=3},{value=3};ca.self=ca;cb.self=cb
compare(ca,cb,true);cb.value=4;compare(ca,cb,false)
-- Alias topology is intentionally value-based in the original comparator;
-- detached graph ownership is independently enforced by H.detached.
local shared={n=1}
local left={first=shared,second=shared};local right={first={n=1},second={n=1}}
compare(left,right,true);right.second.n=2;compare(left,right,false)
right.second.n=1;compare(left,right,true)
right.first.n=2;compare(left,right,false)
local x,y={deep={v=1}},{deep={v=1}}
compare(x,y,true);y.deep.v=2;compare(x,y,false);y.deep.v=1;compare(x,y,true)
assert(not pcall(H.detached,x,x),'independent graph ownership assertion must remain')
assert(pcall(H.detached,x,y),'separate graphs remain legal')
print('CURRENT_UI_COMPARATOR_PARITY_PASS cases='..count)
