package.loaded.abyss_art_features={schemaVersion=2,flags={cards=false,menuBackground=true,selectionAvatar=false,battlePortrait=false,monsters=false}}
local N=dofile('tests/lua/support/official_background_native_fixture.lua')
local Background=require('abyss_menu_background')
local factory=require('abyss_traveler_portraits').createController
local h=N.new()
local logs={}
N.Asset.imagePrefabId=0
local bg=Background.new(h.root,function(s)logs[#logs+1]=s end,factory,Color,{standalone=true})
bg:sync('menu',false,false);assert(bg:status().phase=='failed' and not h.host.visible)
assert(not h.root:GetChild('menuPanel'):GetChild('heroArt').visible,'failure must retain approved hidden legacy art')
for _=1,10 do bg:tick();bg:sync('menu',false,false)end
assert(#logs==1 and logs[1]:find('unbound',1,true),'binding failure must diagnose once without retry')
assert(h.attempts==0);bg:release();bg:onEngineDestroy()

h=N.new();h.failCreate=true;h:startEntry()
OnUpdate(.01);assert(h.attempts==0 and h.updates,'ordinary entry must stay interactive without artwork')
h:openVictory();OnUpdate(.01)
assert(h.attempts==1 and h.updates and not h.host.visible)
assert(h.root:GetChild('victoryEasterEgg'):GetChild('status').text=='彩蛋暂时无法显示，请返回结算。')
for _=1,10 do OnUpdate(.01)end
assert(h.attempts==1,'failed optional creation must not retry every frame')
assert(h.ui.easterEgg:close() and h.root:GetChild('menuPanel').visible,'failed artwork must allow return to results')
assert(h.root:GetChild('menuPanel'):GetChild('result'):GetChild('viewEasterEgg'):GetChild('hit').click())
-- Optional background failure stays cached across close/reopen.
OnUpdate(.01);assert(h.attempts==1,'failed cached owner must not retry on reopen')
assert(not h.host.visible and h.live==0,'failed retry must not expose or strand artwork')
for _=1,10 do OnUpdate(.01)end
assert(h.attempts==1,'failed reopened owner must not retry every frame')
assert(h.ui.easterEgg:close())
for _=1,10 do OnUpdate(.01)end
assert(h.attempts==1,'closed failed owner must not retry in the background')
h:engineDestroy();OnDestroy();assert(not h.updates and h.destroyed==0)

-- The engine destroys a partially built subtree before invoking the script callback.
h=N.new();h:startEntry();h:openVictory();OnUpdate(.01)
assert(h.live>0 and h.live<=256 and not h.host.visible)
local attempts=h.attempts
local lateUpdate=OnUpdate
h:engineDestroy()
local function forbid(c)
 for _,name in ipairs({'SetVisible','SetActive','SetSizeDelta','SetAnchoredPosition','SetLocalScale','SetLocalRotation','SetAsLastSibling','GetChild','GetChildren'})do
  c[name]=function()error('native operation after engine destruction: '..name)end
 end
 for _,child in pairs(c.children)do forbid(child)end
end
forbid(h.canvas)
game.DestroyClientUIControl=function()error('explicit destroy after engine destruction')end
OnDestroy();lateUpdate(.01);assert(h.attempts==attempts and not h.updates and h.destroyed==0)

-- An unexpected entry error must release live artwork before dropping the view.
h=N.new();h:startEntry();h:openVictory();OnUpdate(.01)
local live=h.live;attempts=h.attempts;assert(live>0)
game.GetUICanvasSize=function()error('canvas diagnostic')end
OnUpdate(.01);assert(h.live==0 and h.destroyed==live and not h.updates and not h.host.visible,
 'global entry failure stranded the live victory artwork')
OnUpdate(.01);assert(h.attempts==attempts and h.destroyed==live)
OnDestroy();assert(h.destroyed==live)

-- A failed release must keep the disabled view reachable for engine teardown.
h=N.new();h:startEntry();h:openVictory();OnUpdate(.01)
live=h.live;assert(live>0);h.failDestroy=true
local canvasReads=0
game.GetUICanvasSize=function()canvasReads=canvasReads+1;error('canvas diagnostic with failed cleanup')end
OnUpdate(.01)
assert(not h.updates and h.ui.disabled and h.live==live and h.destroyed==0 and h.ui.easterEgg:status().created,
 'failed release discarded the retained optional-art owner')
local reads=canvasReads
OnUpdate(.01);assert(canvasReads==reads,'disabled failure path must not reenter native canvas reads')
h:engineDestroy();forbid(h.canvas)
game.DestroyClientUIControl=function()error('native destroy after failed-cleanup engine teardown')end
OnDestroy();assert(not h.ui.easterEgg:status().created and not h.updates and h.destroyed==0,
 'entry lost its disabled view before retained owner received engine teardown')
OnUpdate(.01);assert(canvasReads==reads)
print('OFFICIAL_BACKGROUND_ERRORS_PASS')
