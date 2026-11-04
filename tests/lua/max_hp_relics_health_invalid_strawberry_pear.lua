local F=dofile('tests/lua/support/max_hp_relics.lua');local H=require('abyss_relic_hooks')
local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
test('capacity overflow and malformed permanent health reject the whole obtain before ownership publishes',function()
 for _,id in ipairs({'strawberry','pear'})do
  for _,values in ipairs({{2147483647,20},{80,81},{0,0},{80,-1},{80,.5}})do
   local r=F.R.new(F.D,42);r.maxHp,r.hp=values[1],values[2]
   F.snapshotFailure(r,function()return F.R.obtainRelic(r,id)end)
  end
 end
end)
assert(failed==0,tostring(failed)..' max HP health groups failed');print('MAX_HP_RELICS_HEALTH_INVALID_PASS '..count)
