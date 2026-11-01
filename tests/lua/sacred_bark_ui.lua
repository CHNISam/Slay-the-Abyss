local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run');local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then count=count+1;print('PASS Bark UI '..name)else failed=failed+1;print('FAIL Bark UI '..name..': '..tostring(why))end end
local function fixture(id)
 local h,root=F.fixture();local run=Run.new(F.Data,42)
 assert(Run.obtainRelic(run,'SacredBark'));assert(Run.obtainPotion(run,id));assert(Run.startCombat(run,'cultist_solo'))
 h.run,h.battleUI.run,h.nodeUI.run=run,run,run;h:resize(1280,720);h:refresh();return h,root
end
test('inventory details replace static base-dose description with actual doubled health amount',function()
 local h,root=fixture('blood_potion');assert(h:openPotions());assert(F.click(root,'potionPanel','slot1'))
 assert(root:GetChild('potionPanel'):GetChild('detail').text:find('40%',1,true),'inventory retained static 20% Blood dose')
 assert(h.run.potions[1]=='blood_potion')
end)
test('battle full potion description and keyword row both show doubled poison without applying it',function()
 local h,root=fixture('poison_potion');local u=h.battleUI;local panel=root:GetChild('battlePanel')
 assert(u:openHelp(u:potionHelpSpec(1),panel:GetChild('potionHelp'):GetChild('potionHelp1'),false))
 local info=panel:GetChild('statusInfo');assert(info.visible)
 assert(info:GetChild('text1').text:find('12',1,true),'summary must use 12 poison')
 assert(info:GetChild('text2').text:find('12',1,true),'keyword row retained 6 poison')
 assert(h.run.potions[1]=='poison_potion'and (h.run.combat.enemies[1].statuses.poison or 0)==0)
end)
assert(failed==0,tostring(failed)..' Sacred Bark UI regressions failed')
print('SACRED_BARK_UI_PASS '..count)
