local H=dofile('tests/lua/support/potion_basic_five_fixture.lua')
local cases={
 {name='false then true',first=false,later=true,wantOk=false},
 {name='always false',first=false,later=false,wantOk=false},
 {name='true then false',first=true,later=false,wantOk=true},
}
for _,case in ipairs(cases) do
 local calls=0
 local mt={__eq=function()
  calls=calls+1
  if calls==1 then return case.first end
  return case.later
 end,__tostring=function(value)return value.label end}
 local a,b=setmetatable({label='left'},mt),setmetatable({label='right'},mt)
 local ok,message=pcall(H.eq,a,b)
 print(case.name,'comparisonCalls='..calls,'ok='..tostring(ok),'message='..tostring(message))
 assert(calls==1,case.name..': equality evaluated '..calls..' times')
 assert(ok==case.wantOk,case.name..': changed equality outcome')
 if not ok then
  assert(message=='tests/lua/support/potion_basic_five_fixture.lua:6: left ~= right','changed failure message: '..message)
 end
end
print('SINGLE_COMPARISON_EQ_CONTRACT_PASS 3')
