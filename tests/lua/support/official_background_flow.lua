package.loaded.abyss_art_features={schemaVersion=2,flags={cards=false,menuBackground=true,selectionAvatar=false,battlePortrait=false,monsters=false}}
local N=dofile('tests/lua/support/official_background_native_fixture.lua')
local h=N.new()
h:startEntry()
OnUpdate(.01);assert(h.attempts==0,'title must not instantiate optional artwork')
local menu=h.root:GetChild('menuPanel')
assert(menu.visible and menu:GetChild('start').visible and not menu:GetChild('heroArt').visible)
h:openVictory();assert(h.attempts==0,'opening schedules rather than synchronously building artwork')
local run=h.ui.run
OnUpdate(.01);assert(h.live>0 and h.live<=256 and not h.host.visible,'first batch must remain bounded and hidden')
local retained=h.live
assert(h.ui.easterEgg:close());assert(not h.host.visible and h.live==retained and h.ui.run==run)
for _=1,3 do OnUpdate(.01)end
assert(h.live==retained,'closed artwork must pause creation and retain its cache')
assert(menu:GetChild('result'):GetChild('viewEasterEgg'):GetChild('hit').click())
local total=#N.Asset.data.rows+math.ceil(#N.Asset.data.rows/60)+math.ceil(#N.Asset.data.rows/3600)
-- Production retains its normal bounded batch and reveal schedule.
for _=1,total+100 do
 OnUpdate(.01)
 if h.root:GetChild('victoryEasterEgg'):GetChild('status').text==''then break end
end
assert(h.root:GetChild('victoryEasterEgg'):GetChild('status').text=='' and h.host.visible)
assert(h.live==total and #h.created==total,'all current primitives, groups and pages must be built once')
assert(not h.ui:start() and not h.ui:openMenu(),'overlay must retain command ownership')
assert(h.ui.easterEgg:close() and h.live==total and not h.host.visible)
assert(menu:GetChild('result'):GetChild('viewEasterEgg'):GetChild('hit').click())
OnUpdate(.01);assert(#h.created==total,'ready cache must not rebuild on reopening')
h.ui:disable();assert(not h.host.visible and h.live==0 and h.destroyed==total,'permanent disable must release all cached artwork')
h.ui:disable();assert(h.destroyed==total,'repeated disable must not destroy controls twice')
local attempts=h.attempts
OnUpdate(.01);assert(h.attempts==attempts,'disabled UI recreated artwork')
-- Teardown after permanent release must not destroy the former cache twice.
h:engineDestroy();OnDestroy();assert(not h.updates)
OnUpdate(.01);assert(h.attempts==attempts and h.destroyed==total,'engine teardown must retire callbacks without double destroy')
print('OFFICIAL_BACKGROUND_FLOW_PASS')
