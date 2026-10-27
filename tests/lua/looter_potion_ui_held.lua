local selected=... or 1
local F=dofile('tests/lua/support/looter_potion_ui_fixture.lua')
local passed,failed=0,0
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
test('held reward actions reject changed card bundle, gold value or manual mode',function()
 assert(F.changedRewardActions(false,selected)==5,'five original held changes per slice')
end)
print('LOOTER_POTION_UI_HELD '..passed..' passed '..failed..' failed');assert(failed==0)
