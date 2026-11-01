local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Asset=require('abyss_traveler_portrait_assets')
assert(Asset.battle133.runtimeV2 and Asset.battle133.cache)
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local panel=root:GetChild('battlePanel');local hero=panel:GetChild('hero')
local figure=hero:GetChild('officialFigure');local created,images={},{}
local function activation(self,value)F.setEngineActive(self,value)end
figure.SetActive=activation
Enum={ImageSource={StaticReference='static'},ImageType={Stretch=2}}
Color={FromRGBA=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
game={InstantiateClientUIControl=function(index,parent)
 assert(index==41 or index==73)
 local c=F.control({name='formal'..(#created+1),kind=index==41 and 'image' or 'container'},parent)
 c.SetActive=activation;created[#created+1]=c
 if index==41 then c:SetImage('static',100001);images[#images+1]=c end
 return c
end,DestroyClientUIControl=function()error('successful cached portrait must not be destroyed between battles')end}
local portraits=require('abyss_traveler_portraits').new(root,nil,{battlePortrait=true})
local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,portraits=portraits})
root.ui=ui
assert(F.start(ui));assert(Run.startCombat(ui.run,'cultist_solo'))
ui.run.combat=F.Combat.new(F.Data,{deck={'bludgeon'},enemies={'acid_slime_s'},seed=11})
ui:refresh()
for i=1,500 do ui:update(.02);if portraits:status().battle.phase=='ready'then break end end
assert(portraits:status().battle.phase=='ready' and #images==4315)
assert(panel.visible and hero.visible and figure.visible and figure.activeInHierarchy)
local complete=#created;local pixel=images[1];local colour=pixel.imageColor
local function retained(context)
 assert(portraits:status().battle.phase=='ready',context..': formal portrait state lost')
 assert(#created==complete and pixel.alive,context..': formal portrait rebuilt or destroyed')
 assert(pixel.imageId==100001 and pixel.imageColor==colour,context..': formal image identity or colours overwritten')
end
ui.battleUI:playSlot(1);assert(ui.battleUI.selected~=nil)
ui.battleUI:playSelected(1);assert(ui.battleUI.busy)
local deathSeen=false
for i=1,500 do
 for id in pairs(ui.battleUI.feedback.dying)do if id~='player'then deathSeen=true end end
 if not ui.battleUI.busy then break end
 ui:update(.02);retained('death playback')
end
assert(deathSeen and not ui.battleUI.busy and ui.run.phase=='reward')
retained('reward')
-- The approved reward page is a panel, and production deliberately hides the
-- entire hero. Its child remains cached; parent visibility is not asset loss.
assert(ui.mode=='battle' and panel.visible and not hero.visible and figure.visible)
F.click(root,'battlePanel','continue');assert(ui.mode=='map')
retained('map');assert(not panel.visible and not figure.visible)
assert(Run.startCombat(ui.run,'cultist_solo'));ui:refresh();ui:update(.02)
retained('next battle')
assert(panel.visible and hero.visible and figure.visible and figure.activeInHierarchy,'formal portrait not visible in next battle')
print('OFFICIAL_PORTRAIT_GAME_LIFECYCLE_PASS')
