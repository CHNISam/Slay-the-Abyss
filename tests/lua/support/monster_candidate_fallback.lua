-- Actual generated monster-enabled build tree + real GameUI/Combat/feedback, offline native mocks.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Run=require('abyss_run')
-- The shared mock omits imported initial positions. Apply this actual generated
-- tree's positions so nested-art and portrait coordinate comparisons are real.
local canvas=F.control({children=F.Layout})
local function initial(control,spec)
 if spec.position then control:SetAnchoredPosition(spec.position[1],spec.position[2])end
 for _,child in ipairs(spec.children or {})do initial(control:GetChild(child.name),child)end
end
for _,spec in ipairs(F.Layout)do initial(canvas:GetChild(spec.name),spec)end
local root=F.Viewport.apply(canvas,1280,720)
local panel=root:GetChild('battlePanel')
local platform={seed=1,prologue=false,campaign=true,imageSource='static',imageTypes={basic=17,stretch=23},
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',platform)
local instantiate=platform.monsterActors.instantiate
platform.monsterActors.instantiate=function(index,parent)
 local box=instantiate(index,parent)
 if index==platform.monsterActors.templateIndex then initial(box,require('abyss_ui_templates').AbyssMonsterActor);Native.decorate(box:GetChild('monsterArt'))end
 return box
end
local surfaces=assert(require('abyss_monster_surfaces').get(panel))
local function boxFor(actor)return assert(surfaces:find(actor.id),'actor surface missing')end
root.ui=host;assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'))
local data=require('abyss_monster_art_data')
local assets,bindings=0,0
for id in pairs(data.assets)do assets=assets+1;assert(id=='acid_slime_m')end
for id,value in pairs(data.bindings)do bindings=bindings+1;assert(id=='acid_slime_m' and value=='acid_slime_m')end
assert(assets==1 and bindings==1,'production whitelist must remain exactly one asset and binding')
host.run.combat=F.Combat.new(F.Data,{deck={'strike'},enemies={'jaw_worm','acid_slime_m'},seed=11})
host:refresh()
local state=host.run.combat
local unselected,selected=boxFor(state.enemies[1]),boxFor(state.enemies[2])
assert(unselected:GetChild('portrait').visible and not unselected:GetChild('monsterArt').visible,'unselected full-catalog monster must retain gallery')
assert(not selected:GetChild('portrait').visible and selected:GetChild('monsterArt').visible,'approved prototype must draw')
local prior=state.enemies[2]
local replacement=F.Combat.new(F.Data,{deck={'strike'},enemies={'jaw_worm'},seed=11}).enemies[1]
replacement.id=prior.id;replacement.sourcePosition=prior.sourcePosition;state.enemies[2]=replacement
host:refresh()
assert(boxFor(replacement)==selected,'same identity keeps its native surface')
assert(selected:GetChild('portrait').visible and not selected:GetChild('monsterArt').visible,'same-id rebind to unselected definition clears old artwork')
local pool=selected:GetChild('monsterArt'):GetChild('monsterSamples')
assert(not pool:GetChild('group000'):GetChild('shape0000').visible,'old prototype primitive must not leak through fallback')
print('MONSTER_CANDIDATE_FALLBACK_PASS 1asset/1binding / unselected gallery / same-id clear')
