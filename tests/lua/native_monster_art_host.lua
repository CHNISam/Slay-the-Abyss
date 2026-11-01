-- Enabled prototype is exercised by the explicit build in native-monster-art.test.mjs.
if require('abyss_monster_art_data').enabled~=true then
 assert(next(require('abyss_monster_art_data'))==nil,'disabled build must emit an empty stub')
 print('NATIVE_MONSTER_DISABLED_BASELINE_PASS')
 return
end
-- Actual generated normal-build tree + real GameUI/Combat/feedback, offline native mocks.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Run=require('abyss_run')
local EnemyView=require('abyss_battle_enemy_view')
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
local art=panel:GetChild('topBar'):GetChild('monsterArt')
Native.decorate(art)
local platform={seed=1,prologue=false,campaign=true,imageSource='static',imageTypes={basic=17,stretch=23},
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',platform)
root.ui=host;assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'))
local function battle(enemies)
 host.run.combat=F.Combat.new(F.Data,{deck={'strike','strike','defend'},enemies=enemies,seed=11})
 host:refresh();return host.run.combat
end
local function shape()return art:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')end
local function near(a,b)return math.abs(a-b)<1e-8 end
local state=battle({'cultist','acid_slime_m','acid_slime_m'})
local ui=host.battleUI
assert(panel:GetChild('topBar').visible,'existing unmasked ancestor must remain active')
assert(art.visible,'normal build must show real new drawing, not unreachable opt-in')
assert(panel:GetChild('enemy1'):GetChild('portrait').visible)
assert(not panel:GetChild('enemy2'):GetChild('portrait').visible,'any matching slot gallery must be replaced')
assert(panel:GetChild('enemy3'):GetChild('portrait').visible,'extra copy explicitly remains gallery')
assert(not panel:GetChild('enemy2'):GetChild('plate').visible and not panel:GetChild('enemy2'):GetChild('border').visible,'existing unit backgrounds must remain hidden above native art')
assert(shape().imageId==100003 and shape().rotation[2]~=0,'exact native primitive and XYZ used')
-- A real row compaction changes slot2 from acid_2 to acid_3. Exercise exactly
-- ONE BattleUI render, not GameUI.refresh (which can render more than once).
local oldId=state.enemies[2].id;local nextId=state.enemies[3].id
assert(oldId~=nextId and ui.feedback.slotOwners[2]==oldId)
local oldHp=state.enemies[2].hp;state.enemies[2].hp=0
local render=ui.render;local renderPasses=0
ui.render=function(self,...)renderPasses=renderPasses+1;return render(self,...)end
ui:render();ui.render=render
assert(renderPasses==1 and ui.feedback.slotOwners[2]==nextId,'actual single render must bind genuinely changed actor owner')
assert(art.visible and not panel:GetChild('enemy2'):GetChild('portrait').visible,'new slot owner must show new drawing in its FIRST render pass')
state.enemies[2].hp=oldHp;ui:render()
local information={}
for _,name in ipairs({'hit','hp','intent','statusRow'})do
 local c=panel:GetChild('enemy2'):GetChild(name);information[name]={c.x,c.y,c.sizeDeltaX,c.sizeDeltaY}
end
for _=1,12 do host:update(1/60)end
local box,portrait=panel:GetChild('enemy2'),panel:GetChild('enemy2'):GetChild('portrait')
assert(near(art.x+(panel:GetChild('topBar').x or 0),box.x+portrait.x)and near(art.y+(panel:GetChild('topBar').y or 0),box.y+portrait.y),'native drawing follows actual idle pose')
assert(near(art.localScaleY,portrait.localScaleY),'native drawing follows idle scale')
for name,want in pairs(information)do
 local c=box:GetChild(name);assert(c.x==want[1]and c.y==want[2]and c.sizeDeltaX==want[3]and c.sizeDeltaY==want[4],'information geometry changed '..name)
end
-- Use actual feedback hit/death state and update, not a second animation loop.
local id=state.enemies[2].id
ui.feedback.dying[id]={age=0}
host:update(.05)
assert(near(art.localScaleY,portrait.localScaleY)and near(art.y+(panel:GetChild('topBar').y or 0),box.y+portrait.y),'death transform must remain attached')
assert(shape().imageColor.a<255,'death alpha must reach original native slot colour')
ui.feedback:cancel();assert(not art.visible,'explicit reset must clear the pool')
host:refresh();assert(art.visible,'same normal battle can rebind after reset')
-- A failed write owns a cached fallback until an explicit feedback reset.
-- Reset must invalidate that failure even when the same slot/actor ID returns.
ui.feedback:cancel()
local primitive=shape();local rotate=primitive.SetLocalRotation;local failedWrites=0
primitive.SetLocalRotation=function()failedWrites=failedWrites+1;return false end
host:refresh();assert(not art.visible and panel:GetChild('enemy2'):GetChild('portrait').visible,'failed primitive must show only gallery')
require('abyss_monster_art').pose(panel:GetChild('enemy2'),0,0,1,1,{r=255,g=255,b=255,a=255},1)
assert(not art.visible and not primitive.visible,'pose must never expose failed partial shapes')
host:refresh();assert(failedWrites==1,'failed metadata must remain cached per frame')
ui.feedback:cancel();primitive.SetLocalRotation=rotate
host:refresh();assert(art.visible and not panel:GetChild('enemy2'):GetChild('portrait').visible,'feedback reset must retry a failed drawing for same box and actor ID')

ui:setActive(false);assert(not art.visible,'unmount must clear even with live matching actor')
ui:setActive(true);assert(art.visible)
state=battle({'cultist','jaw_worm'});assert(not art.visible,'replacement battle without ID must not show grass slime')
state=battle({'cultist','jaw_worm','acid_slime_m','cultist','cultist'})
assert(art.visible and not panel:GetChild('enemy3'):GetChild('portrait').visible,'five-enemy any-slot binding')
local _,_,size=EnemyView.position(5,3,state.enemies[3])
assert(near(art:GetChild('monsterSamples').localScaleX,size/106),'five-enemy geometry must contain drawing in current portrait')
host:resize(1920,1080);host:refresh();assert(art.visible)
ui.feedback:cancel();platform.nativeMonsterArtEnabled=false;host:refresh()
assert(not art.visible and panel:GetChild('enemy3'):GetChild('portrait').visible,'registered escape hatch must fall back to gallery')
assert(not panel:GetChild('enemy3'):GetChild('plate').visible and not panel:GetChild('enemy3'):GetChild('border').visible,'fallback retains existing UnitView background policy')
platform.nativeMonsterArtEnabled=true;host:refresh();assert(art.visible)
state=battle({'acid_slime_m'});state.enemies[1].hp=1;host:refresh()
local strike
for slot,card in ipairs(state.hand)do if card.cardId=='strike' then strike=slot;break end end
assert(strike);panel:GetChild('card'..strike):GetChild('hit').click();panel:GetChild('enemy1'):GetChild('hit').click()
assert(state.enemies[1].hp==0,'actual card command must commit the lethal hit')
for _=1,200 do host:update(.05)end
assert(host.run.phase=='reward'and not art.visible,'real lethal feedback and reward transition must retire new art')
print('NATIVE_MONSTER_HOST_PASS actual normal generated GameUI -> any-slot / duplicate fallback / idle / death / hide / restart / five enemies / resize / off switch')
