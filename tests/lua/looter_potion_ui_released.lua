local F=dofile('tests/lua/support/looter_potion_ui_fixture.lua')
local passed,failed=0,0
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
test('released reward actions reject changed card bundle, gold value or manual mode',function()
 F.changedRewardActions(true)
end)
print('LOOTER_POTION_UI_RELEASED '..passed..' passed '..failed..' failed');assert(failed==0)
