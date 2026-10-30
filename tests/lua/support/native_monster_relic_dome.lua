-- Actual generated monster-enabled build tree + real GameUI/Combat/feedback, offline native mocks.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Run=require('abyss_run')
-- The shared mock omits imported initial positions. Apply this actual generated
-- tree's positions so ancestor-coordinate proof includes the nonzero host origin.
local canvas=F.control({children=F.Layout})
local function initial(control,spec)
 if spec.position then control:SetAnchoredPosition(spec.position[1],spec.position[2])end
 for _,child in ipairs(spec.children or {})do initial(control:GetChild(child.name),child)end
end
for _,spec in ipairs(F.Layout)do initial(canvas:GetChild(spec.name),spec)end
local root=F.Viewport.apply(canvas,1280,720)
local panel=root:GetChild('battlePanel')
local Surfaces=require('abyss_monster_surfaces')
local Powers=require('abyss_monster_power_surfaces')
local platform={seed=1,prologue=false,campaign=true,imageSource='static',imageTypes={basic=17,stretch=23},
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
F.withMonsterActors(platform)
local instantiate=platform.monsterActors.instantiate
platform.monsterActors.instantiate=function(index,parent)
 local box=instantiate(index,parent)
 if index==1 then Native.decorate(assert(box:GetChild('monsterArt')))end
 return box
end
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',platform)
root.ui=host;assert(F.start(host));assert(Run.obtainRelic(host.run,'runic_dome'))
-- Stage this source encounter at its own admitted floor; no production rule is changed.
for _,encounter in ipairs(host.run.data.enemies.encounters)do
 if encounter.id=='medium_slimes'then host.run.floor=encounter.minFloor end
end
assert(Run.startCombat(host.run,'medium_slimes'));host:refresh()
local manager=assert(Surfaces.get(panel))
local grass
for _,actor in ipairs(host.run.combat.enemies)do if actor.definitionId=='acid_slime_m'then grass=actor end end
local grassBox=assert(manager:find(assert(grass).id))
local art=assert(grassBox:GetChild('monsterArt'))
assert(art.visible,'native grass must remain visible while Runic Dome hides intents')
local primitive=art:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')
assert(primitive.imageId==100003 and primitive.rotation[2]~=0,'real r02 geometry must be written')
for index=1,#host.run.combat.enemies do
 assert(F.Combat.intent(host.run.combat,index),'Dome must retain core action intent')
 local box=assert(manager:find(host.run.combat.enemies[index].id))
 for _,name in ipairs({'intentIcon','intentBadge','intentExtra','intent','intentLabel','intentHit'})do
  assert(not box:GetChild(name).visible,'new grass composition leaked Dome '..name)
 end
 assert(box:GetChild('intent').text=='')
end
assert(require('abyss_boss_relics').hidesIntents(host.run))
host:update(.6)
for _,actor in ipairs(host.run.combat.enemies)do
 local box=assert(manager:find(actor.id))
 for _,layer in ipairs({'intentVfxBehind','intentVfxAfter'})do
  local pool=Powers.get(box:GetChild(layer));local live=0
  if pool then pool:each(function()live=live+1 end)end
  assert(live==0,'acquired Dome must suppress native intent particles')
 end
end
print('NATIVE_MONSTER_RELIC_DOME_PASS real grass plus acquired Dome, hidden UI and retained core intents')
