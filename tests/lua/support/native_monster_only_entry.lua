local F=dofile('tests/lua/support/game_ui_fixture.lua')
local captured,options
local GameUI=require('abyss_game_ui')
local realNew=GameUI.new
GameUI.new=function(...)
 local args={...};options=args[5];captured=realNew(...);return captured
end
-- Seed a prior world's real dynamic pool. The next default-off startup must
-- release it through the existing runtime, not merely stop scheduling updates.
local Old=dofile('tests/lua/support/bounded_native_art_fixture.lua')
local Runtime=require('abyss_card_art_runtime')
local Display=require('abyss_card_display')
Old.configure(Runtime)
local oldFace,oldMeta=Old.face(),Old.metadata('strike',1)
Display.writeNativeArt(oldFace,{id='strike'},oldMeta,Old.platform,oldFace:GetChild('art'),1)
Runtime.update();assert(Runtime.status().livePools==1 and #Old.created>0)
local canvas=F.control({children=F.Layout})
local root=F.Viewport.apply(canvas,1280,720)
local panel=root:GetChild('battlePanel')
local Surfaces=require('abyss_monster_surfaces')
local Native=dofile('tests/lua/support/native_art_controls.lua')
root.children.officialBackground=nil
root:GetChild('characterPanel'):GetChild('traveler').children.officialAvatar=nil
root:GetChild('battlePanel'):GetChild('hero').children.officialFigure=nil
local forbidden={abyss_menu_background=true,abyss_menu_background_asset=true,
 abyss_traveler_portraits=true,abyss_traveler_portrait_assets=true,
 abyss_ready_card_binding=true,abyss_ready_card_assets=true}
for name in pairs(forbidden)do assert(package.loaded[name]==nil,'fixture eagerly loaded '..name)end
local originalRequire=require
require=function(name)assert(not forbidden[name],'disabled art loaded '..name);return originalRequire(name)end
package.loaded.abyss_art_features={schemaVersion=2,flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=true}}
Enum={ImageSource={StaticReference='static'},ImageType={Stretch='stretch'},CursorEventType={CursorClick='click'},
 Device={Controller='controller',MobileController='mobileController',Mobile='mobile'}}
Color=setmetatable({FromRGBA=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end},
 {__call=function(_,r,g,b,a)return {r=r,g=g,b=b,a=a}end})
local creates,updates=0,false
local actorApi=F.monsterActors()
package.loaded.abyss_monster_actor_binding={enabled=true,templateIndex=actorApi.templateIndex,
 containerTemplateIndex=actorApi.containerTemplateIndex,powerTemplateIndex=actorApi.powerTemplateIndex}
local owned={}
local function count(box)local n=1;for _,child in pairs(box.children or {})do n=n+count(child)end;return n end
game={InstantiateClientUIControl=function(index,parent)
 assert(index==1 or index==2 or index==3,'disabled category template created')
 local box=actorApi.instantiate(index,parent);creates=creates+1;owned[#owned+1]=box
 if index==1 then assert(count(box)==647,'actual complete drawing-enabled actor template');Native.decorate(assert(box:GetChild('monsterArt')))end
 return box
 end,
 DestroyClientUIControl=function(box)return actorApi.destroy(box)end,
 GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end,
 GetDevice=function()return 'desktop'end,GetCursorUIPos=function()return 0,0 end}
script={object=canvas,GetParam=function(_,name)assert(name=='nativeBgmEnabled');return false end,
 EnableUpdate=function(_,v)updates=v end}
dofile('src/lua/abyss_ui.lua');OnStart();assert(updates,'monster-only native entry did not start')
assert(Runtime.status().livePools==0,'default-off startup stranded a prior world pool')
for _,control in ipairs(Old.created)do assert(not control.alive,'old custom control remained live')end
assert(oldFace:GetChild('art').visible,'prior world official fallback not restored')
local menu=root:GetChild('menuPanel')
assert(menu.visible and menu:GetChild('start').visible)
assert(not menu:GetChild('heroArt').visible,'merged menu layout keeps its legacy hero overlay hidden')
OnUpdate(.01);assert(F.click(root,'menuPanel','start'))
assert(root:GetChild('characterPanel').visible,'official selection remains interactive')
OnUpdate(.01)
local hero=root:GetChild('battlePanel'):GetChild('hero'):GetChild('portrait')
assert(hero.visible,'official hero fallback remains visible')
assert(creates==0)
for name in pairs(forbidden)do assert(package.loaded[name]==nil,'disabled data loaded '..name)end
assert(not options.cardArt and not options.background and not options.portraits)
assert(captured:confirmCharacter())
assert(F.click(root,'nodePanel','eventView/option1'))
assert(F.click(root,'nodePanel','eventView/option2'))
assert(F.click(root,'nodePanel','eventView/option1'))
assert(captured.run.phase=='map' and captured.run.neowStatus=='complete')
local Nodes=require('abyss_nodes')
assert(Nodes.enter(captured.run,captured.map,Nodes.available(captured.run,captured.map)[1].id))
assert(captured.run.phase=='combat')
captured.run.combat=F.Combat.new(F.Data,{deck={'strike','defend'},enemies={'cultist','acid_slime_m'},seed=11})
captured:refresh()
local grass=captured.run.combat.enemies[2]
local actor=assert(Surfaces.get(panel):find(grass.id),'source instance must own a complete dynamic actor')
local art=assert(actor:GetChild('monsterArt'))
assert(art.visible,'monster ON / other four OFF must still draw independent grass monster')
local shape=art:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')
assert(shape.imageId==100003 and shape.rotation[2]~=0,'actual r02 primitive writes required')
assert(not actor:GetChild('portrait').visible)
assert(Runtime.status().livePools==0 and creates>0,'monster surfaces must not activate card dynamic runtime')
for name in pairs(forbidden)do assert(package.loaded[name]==nil,'grass reenabled disabled category '..name)end
local createdBeforeDestroy=creates
local oldOwner=captured
local oldClick=actor:GetChild('hit').click
-- The engine destroys the world BEFORE OnDestroy. Native writes/Destroy on
-- this dead tree must not be attempted; normal disable is tested separately.
actorApi.destroy(canvas)
for _,box in ipairs(owned)do assert(not box.alive,'test engine did not retire owned actor subtree')end
local forbiddenCalls=0
local function deadTree(box)
 for _,name in ipairs({'SetVisible','SetSizeDelta','SetAnchoredPosition','SetLocalScale','SetLocalRotation','SetAsLastSibling','GetChild','GetChildren'})do
  box[name]=function()forbiddenCalls=forbiddenCalls+1;error('native operation after engine destruction: '..name)end
 end
 for _,child in pairs(box.children or {})do deadTree(child)end
end
deadTree(canvas)
game.DestroyClientUIControl=function()forbiddenCalls=forbiddenCalls+1;error('Destroy after engine destruction')end
OnDestroy();assert(not updates);OnUpdate(.01)
assert(creates==createdBeforeDestroy,'disabled entry recreated native output')
assert(Surfaces.get(panel)==nil,'engine teardown retained actor registry')
assert(next(oldOwner.battleUI.monsterSurfaces and oldOwner.battleUI.monsterSurfaces.records or {})==nil)
if oldClick then oldClick({touchId=999})end
assert(forbiddenCalls==0,'engine teardown or stale callback accessed dead native controls')
-- A new engine world starts independently; old callbacks cannot revive it.
local freshCanvas=F.control({children=F.Layout});script.object=freshCanvas
dofile('src/lua/abyss_ui.lua') -- a fresh engine script instance, not retrying the destroyed one
OnStart();assert(updates and captured~=oldOwner,'fresh world failed to restart')
if oldClick then oldClick({touchId=1000})end
assert(forbiddenCalls==0 and creates==createdBeforeDestroy,'old world callback created or wrote output after restart')
actorApi.destroy(freshCanvas);OnDestroy();assert(not updates)
print('NATIVE_MONSTER_ONLY_ENTRY_PASS')
