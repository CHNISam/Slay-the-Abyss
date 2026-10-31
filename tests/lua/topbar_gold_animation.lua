local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel=H.setup()
local goldLabel=panel:GetChild('piles')
local function shown() return tonumber(goldLabel.text) end
local function tick(count) for _=1,count do assert(host:update(1/60)) end end
local C=require("abyss_theme").color
local function ink(expected)
 for _,key in ipairs({"r","g","b","a"}) do assert(goldLabel.fontColor[key]==expected[key],"gold ink "..key) end
end
local gold=host.run.combat.player.gold
assert(shown()==gold,'new run must not inherit hidden zero-gold display');ink(C.topPanelGold)
host.run.combat.player.gold=gold+100
host:refresh()
assert(shown()==gold,'render must not advance the animation');ink(C.topPanelGreen)
assert(host:openExit());tick(60);assert(shown()==gold,'pause must freeze gold animation');assert(host:closeExit())
for _=1,20 do host:refresh() end
assert(shown()==gold,'extra renders must not accelerate animation')
tick(1);assert(shown()==gold+10,'first update preserves the 10-gold step')
tick(600);assert(shown()==gold+100,'idle updates must settle without another refresh');ink(C.topPanelGold)
assert(host.run.combat.player.gold==gold+100,'display animation must not mutate gold')
host.run.combat.player.gold=0
host:refresh();ink(C.topPanelRed);tick(600);assert(shown()==0,'falling gold must settle');ink(C.topPanelGold)
host.run.combat.player.gold=9
host:refresh();host:update(0);assert(shown()==0,'zero dt must not advance gold')
tick(1);assert(shown()==1,'small gap preserves 1-gold step')
host.run.combat.player.gold=21
host:refresh();tick(1);assert(shown()==4,'medium gap preserves 3-gold step')
host.run.combat.player.gold=104
host:refresh();assert(host:update(10));assert(shown()==104,'long frame must settle current target')
host.run.combat.player.gold=204
host:refresh();assert(host:update(0));assert(shown()==104,'zero dt cannot spend old frame debt')
tick(1);assert(shown()==114,'settled animation must discard unused frame debt')
host.run.phase="defeat";host.run.hp=0;host:refresh();tick(600)
assert(H.F.start(host))
host:refresh()
assert(shown()==host.run.gold,'new run must reset unfinished old animation')
print('TOPBAR_GOLD_ANIMATION_PASS initial refresh idle gain loss zero_dt steps restart')
