local F=dofile('tests/lua/support/game_ui_fixture.lua')
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
root.children.officialBackground=nil
root:GetChild('characterPanel'):GetChild('traveler').children.officialAvatar=nil
root:GetChild('characterPanel'):GetChild('details').children.officialSelectionFigure=nil
root:GetChild('battlePanel'):GetChild('hero').children.officialFigure=nil
local forbidden={abyss_menu_background=true,abyss_menu_background_asset=true,
 abyss_traveler_portraits=true,abyss_traveler_portrait_assets=true,
 abyss_ready_card_binding=true,abyss_ready_card_assets=true,abyss_monster_art_data=true}
for name in pairs(forbidden)do assert(package.loaded[name]==nil,'fixture eagerly loaded '..name)end
local originalRequire=require
require=function(name)assert(not forbidden[name],'disabled art loaded '..name);return originalRequire(name)end
package.loaded.abyss_art_features={schemaVersion=2,flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=false}}
Enum={ImageSource={StaticReference='static'},ImageType={Stretch='stretch'},CursorEventType={CursorClick='click'},
 Device={Controller='controller',MobileController='mobileController',Mobile='mobile'}}
Color=setmetatable({FromRGBA=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end},
 {__call=function(_,r,g,b,a)return {r=r,g=g,b=b,a=a}end})
local creates,updates=0,false
-- Ordinary monster controls still have candidate bindings when artwork is OFF.
local actorApi=F.monsterActors()
package.loaded.abyss_monster_actor_binding={enabled=true,templateIndex=actorApi.templateIndex,
 containerTemplateIndex=actorApi.containerTemplateIndex,powerTemplateIndex=actorApi.powerTemplateIndex}
game={InstantiateClientUIControl=function()creates=creates+1;error('disabled custom art created')end,
 DestroyClientUIControl=function()error('nothing custom should be owned')end,
 GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end,
 GetDevice=function()return 'desktop'end,GetCursorUIPos=function()return 0,0 end}
script={object=canvas,GetParam=function(_,name)assert(name=='nativeBgmEnabled');return false end,
 EnableUpdate=function(_,v)updates=v end}
dofile('src/lua/abyss_ui.lua');OnStart();assert(updates,'all-off native entry did not start')
local Skin=require('abyss_card_skin')
assert(Skin.premium(),'premium card chrome must survive cards=false without loading illustrations')
assert(Runtime.status().livePools==0,'default-off startup stranded a prior world pool')
for _,control in ipairs(Old.created)do assert(not control.alive,'old custom control remained live')end
assert(oldFace:GetChild('art').visible,'prior world official fallback not restored')
local menu=root:GetChild('menuPanel')
assert(menu.visible and menu:GetChild('backdrop').visible and menu:GetChild('start').visible)
assert(not menu:GetChild('heroArt').visible and not menu:GetChild('vista').visible,'obsolete icon scenery covered the official image')
assert(menu:GetChild('lowpolyVeil').visible and menu:GetChild('titleBand').visible,'title must retain its readability veil and band')
local function findSpec(controls,name)
 for _,c in ipairs(controls)do
  if c.name==name then return c end
  local found=c.children and findSpec(c.children,name);if found then return found end
 end
end
local menuSpec=assert(findSpec(F.Layout,'menuPanel'))
assert(findSpec(menuSpec.children,'backdrop').image==F.Theme.image.rect,'title must retain its solid fallback')
assert(findSpec(menuSpec.children,'lowpolyVeil').opacity==0.28 and findSpec(menuSpec.children,'titleBand').opacity==0.55,'title readability opacity changed')
local battleSpec=assert(findSpec(F.Layout,'officialBattleBackdrop'))
for _,name in ipairs({'act1_1','act1_2','act1_3','act2_1','act2_2','act2_3','boss1','boss2'})do
 assert(findSpec(battleSpec.children,name).image==F.Theme.image.officialBackdrops[name],'missing native official battle image '..name)
end
assert(not root:GetChild('officialBattleBackdrop').visible,'battle scenery must stay hidden on the title')
assert(not root:GetChild('victoryEasterEgg').visible,'all-off entry exposed the optional egg')
assert(not menu:GetChild('result'):GetChild('viewEasterEgg').visible,'all-off entry exposed the optional egg button')
OnUpdate(.01);assert(F.click(root,'menuPanel','start'))
assert(root:GetChild('characterPanel').visible,'official selection remains interactive')
local select=root:GetChild('characterPanel')
assert(select:GetChild('details'):GetChild('deckOpen'):GetChild('hit').click(),'starter deck remains accessible with illustrations disabled')
local deck=select:GetChild('deckView')
assert(deck.visible and deck:GetChild('deckCard10').visible and not deck:GetChild('deckCard11').visible)
local preview=require('abyss_character_select').preview(F.Data,F.Presentation,'ironclad')
local byName,seen={},{}
for _,card in ipairs(preview.deck)do byName[card.name]=card end
local function sameColour(actual,expected,message)
 assert(actual and actual.r==expected.r and actual.g==expected.g and actual.b==expected.b,message)
end
for i=1,10 do
 local face=deck:GetChild('deckCard'..i):GetChild('face')
 assert(face:GetChild('name').text~='' and face:GetChild('cost').text~='' and face:GetChild('label').text~='','starter card semantics missing')
 local card=assert(byName[face:GetChild('name').text],'unexpected starter card identity')
 seen[card.id]=(seen[card.id] or 0)+1
 local definition=card.definition
 local rarity=assert(F.Theme.cardSkin.rarities[definition.rarity])
 sameColour(face:GetChild('border').imageColor,rarity[1],'starter frame lost its own rarity')
 sameColour(face:GetChild('roundFrame'):GetChild('vertical').imageColor,rarity[1],'visible rounded frame lost rarity')
 sameColour(face:GetChild('nameRule').imageColor,rarity[4],'starter name rule lost rarity')
 sameColour(face:GetChild('skin'):GetChild('band1').imageColor,rarity[2],'starter banner lost rarity')
 local accent=F.Theme.cardSkin.roles.traveler.accent
 sameColour(face:GetChild('costDisc').imageColor,accent,'traveler cost decoration lost')
 assert(face:GetChild('roleMark'):GetChild('traveler').visible,'traveler emblem lost')
 assert(face:GetChild('art').visible and face:GetChild('art').imageId==Display.art(definition),'official starter art fallback lost')
 local well=face:GetChild('skin'):GetChild(definition.type):GetChild('well')
 local part=({attack='upper',skill='vertical',power='base'})[definition.type]
 local tone=well:GetChild(part).imageColor
 assert(tone.r<100 and tone.g<100 and tone.b<100,'official icon needs its dark aperture')
 -- Premium still owns the selected highlight, but never erases rarity in the title band.
 Skin.apply(face,definition,{color=Color},{cost=definition.cost,baseCost=definition.cost,selected=true})
 sameColour(face:GetChild('roundFrame'):GetChild('vertical').imageColor,F.Theme.cardSkin.premium.selected,'premium selection highlight lost')
 sameColour(face:GetChild('nameRule').imageColor,rarity[4],'selection erased rarity')
 Skin.apply(face,definition,{color=Color},{cost=definition.cost,baseCost=definition.cost})
 sameColour(face:GetChild('roundFrame'):GetChild('vertical').imageColor,rarity[1],'deselection did not restore rarity')
end
for _,card in ipairs(preview.deck)do assert(seen[card.id]==card.count,'starter deck multiplicity changed')end
assert(deck:GetChild('close'):GetChild('hit').click() and not deck.visible,'read-only starter deck must close back to selection')
OnUpdate(.01)
local hero=root:GetChild('battlePanel'):GetChild('hero'):GetChild('portrait')
assert(hero.visible,'official hero fallback remains visible')
assert(creates==0)
for name in pairs(forbidden)do assert(package.loaded[name]==nil,'disabled data loaded '..name)end
OnDestroy();assert(not updates);OnUpdate(.01);assert(creates==0)
print('ART_FEATURE_FLAGS_ENTRY_PASS')
