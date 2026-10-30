package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Theme=require('abyss_theme')
local Run=require('abyss_run')
local failed=0
local function expect(value,message) if not value then failed=failed+1;print('FAIL '..message)end end
local function countCalls(control,names)
    local counts={total=0}
    for _,name in ipairs(names)do
        local original=control[name]
        control[name]=function(self,...)
            counts.total=counts.total+1
            return original(self,...)
        end
    end
    return counts
end
local ui,root=F.fixture(nil,function()return true end)
local menu=root:GetChild('menuPanel')
for _=1,120 do ui:update(1/60)end
local stable={countCalls(menu:GetChild('title'),{'SetAnchoredPosition'}),
    countCalls(menu:GetChild('tagline'),{'SetAnchoredPosition'}),
    countCalls(menu:GetChild('emblem'),{'SetLocalScale'}),
    countCalls(menu:GetChild('settle'),{'SetAnchoredPosition'}),
    countCalls(menu:GetChild('deathShade'),{'SetVisible'})}
local result=menu:GetChild('result')
stable[#stable+1]=countCalls(result:GetChild('subtitle'),{'SetAnchoredPosition'})
for _,name in ipairs({'floor','victories','time','deck'})do
    stable[#stable+1]=countCalls(result:GetChild('stat_'..name),{'SetAnchoredPosition','SetLocalScale'})
end
local glow=countCalls(menu:GetChild('emblem'):GetChild('glow'),{'SetLocalScale'})
local mote=countCalls(menu:GetChild('vista'):GetChild('mote1'),{'SetAnchoredPosition'})
for _=1,60 do ui:update(1/60)end
local total=0;for _,counter in ipairs(stable)do total=total+counter.total end
print('UI_STABLE_MENU_WRITES frames=60 calls='..total..' glow='..glow.total..' mote='..mote.total)
expect(total==0,'settled menu must stop writing fixed native transforms and hidden veil')
expect(glow.total==60 and mote.total==60,'approved breathing and vista motion must continue')
-- A fresh result must replay its entrance rather than inherit the title cache.
assert(F.start(ui));ui.run.phase='defeat';ui:refresh()
expect(not ui.motion.entranceDone,'result entrance must start fresh')
for _=1,120 do ui:update(1/60)end
expect(result:GetChild('stat_floor').x==Theme.layout.nativeMenu.stats.origin[1],'entrance must reach exact final card position')
assert(ui:settle())
for _=1,60 do ui:update(1/60)end
expect(menu:GetChild('settle').x==0,'settlement slide must paint its final centre position')
-- Stage shake is owned by feedback: idle must not repeatedly set the same zero.
local host,canvas=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local feedback=host.battleUI.feedback
local panel=canvas:GetChild('battlePanel')
local stage=panel:GetChild('stage') or panel
local calls=countCalls(stage,{'SetAnchoredPosition'})
for _=1,60 do host:update(1/60)end
print('UI_STABLE_STAGE_WRITES frames=60 calls='..calls.total)
expect(calls.total==0,'idle feedback must not rewrite zero stage shake')
-- A changed nonzero value and its return to zero must both be painted.
feedback.stageShake=3;stage.x=3;host:update(1/60)
expect(stage.x==0 and calls.total==1,'shake recovery must paint zero once')
feedback:reset();expect(stage.x==0,'cancellation must restore the stage')
assert(failed==0,tostring(failed)..' stable write regressions')
print('LUA_UI_STABLE_WRITES_PASS')
