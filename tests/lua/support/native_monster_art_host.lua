-- Actual generated monster-enabled build tree + real GameUI/Combat/feedback, offline native mocks.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Run=require('abyss_run')
local EnemyView=require('abyss_battle_enemy_view')
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
local art,arts
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
local function drawings(state)
 local result={}
 for i,actor in ipairs(state.enemies)do result[i]=boxFor(actor):GetChild('monsterArt')end
 return result
end
root.ui=host;assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'))
local function battle(enemies)
 host.run.combat=F.Combat.new(F.Data,{deck={'strike','strike','defend'},enemies=enemies,seed=11})
 host:refresh();return host.run.combat
end
local function shape()return art:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')end
local function near(a,b)return math.abs(a-b)<1e-8 end
local state=battle({'cultist','acid_slime_m','acid_slime_m'})
local ui=host.battleUI
arts=drawings(state);art=arts[2]
assert(panel:GetChild('actorLayer').visible,'dynamic actor ancestor must remain active')
assert(art.visible,'explicit monster-enabled build must show real new drawing, not unreachable opt-in')
assert(boxFor(state.enemies[1]):GetChild('portrait').visible,'unconverted actor retains gallery fallback')
assert(not boxFor(state.enemies[2]):GetChild('portrait').visible,'any matching slot gallery must be replaced')
assert(arts[3].visible and not boxFor(state.enemies[3]):GetChild('portrait').visible,'duplicate copy must use its own drawing pool')
assert(not boxFor(state.enemies[2]):GetChild('plate').visible and not boxFor(state.enemies[2]):GetChild('border').visible,'existing unit backgrounds must remain hidden above native art')
assert(shape().imageId==100003 and shape().rotation[2]~=0,'exact native primitive and XYZ used')
-- Removing a source instance must not reflow/rebind the surviving instance.
-- Exercise exactly ONE BattleUI render rather than a multi-render host refresh.
local oldActor,nextActor=state.enemies[2],state.enemies[3]
local oldBox,nextBox=boxFor(oldActor),boxFor(nextActor)
local nextArt=arts[3];local nextX,nextY=nextBox.x,nextBox.y
local oldHp=oldActor.hp;oldActor.hp=0
local render=ui.render;local renderPasses=0
ui.render=function(self,...)renderPasses=renderPasses+1;return render(self,...)end
ui:render();ui.render=render
assert(renderPasses==1 and not surfaces:find(oldActor.id) and not oldBox.alive,'single render retires absent actor')
assert(boxFor(nextActor)==nextBox and nextBox.x==nextX and nextBox.y==nextY,'survivor keeps identity and source coordinates')
assert(nextArt.visible and not nextBox:GetChild('portrait').visible,'survivor drawing remains visible in FIRST render pass')
oldActor.hp=oldHp;ui:render();arts=drawings(state);art=arts[2]
assert(boxFor(oldActor)~=oldBox and art.visible,'returned actor receives a fresh drawing surface')
local information={}
for _,name in ipairs({'hit','hp','intent','statusRow'})do
 local c=boxFor(state.enemies[2]):GetChild(name);information[name]={c.x,c.y,c.sizeDeltaX,c.sizeDeltaY}
end
for _=1,12 do host:update(1/60)end
local box,portrait=boxFor(state.enemies[2]),boxFor(state.enemies[2]):GetChild('portrait')
assert(near(art.x,portrait.x)and near(art.y,portrait.y),'native drawing follows actual idle pose')
assert(near(art.localScaleY,portrait.localScaleY),'native drawing follows idle scale')
for name,want in pairs(information)do
 local c=box:GetChild(name);assert(c.x==want[1]and c.y==want[2]and c.sizeDeltaX==want[3]and c.sizeDeltaY==want[4],'information geometry changed '..name)
end
-- Use the real lethal command/contact path, including original death-clock fields.
local id=state.enemies[2].id
state.enemies[2].hp=1;host:refresh()
local strike
for slot,card in ipairs(state.hand)do if card.cardId=='strike' then strike=slot;break end end
assert(strike);panel:GetChild('card'..strike):GetChild('hit').click();box:GetChild('hit').click()
assert(state.enemies[2].hp==0,'real command commits lethal damage')
for _=1,100 do host:update(.01);if ui.feedback.dying[id]then break end end
local dying=assert(ui.feedback.dying[id],'lethal visual contact starts original death clock')
assert(dying.lifetime==1.8 and dying.alpha and dying.tone,'original timer/tint state is complete')
host:update(.05)
assert(near(art.localScaleY,portrait.localScaleY)and near(art.y,portrait.y),'death transform must remain attached')
assert(shape().imageColor.a<255,'death alpha must reach original native slot colour')
for _=1,150 do if not ui.busy then break end;host:update(.01)end
assert(not ui.busy and ui.feedback.dying[id] and art.visible,'action completion must retain live original death clock')
ui.feedback:cancel();assert(not art.visible,'explicit reset must clear the pool')
state.enemies[2].hp=oldHp;state.enemies[2].isDying=false;host:refresh();assert(art.visible,'same normal battle can rebind after reset')
-- A failed write owns a cached fallback until an explicit feedback reset.
-- Reset must invalidate that failure even when the same slot/actor ID returns.
ui.feedback:cancel()
local primitive=shape();local rotate=primitive.SetLocalRotation;local failedWrites=0
primitive.SetLocalRotation=function()failedWrites=failedWrites+1;return false end
host:refresh();assert(not art.visible and boxFor(state.enemies[2]):GetChild('portrait').visible,'failed primitive must show only gallery')
require('abyss_monster_art').pose(boxFor(state.enemies[2]),0,0,1,1,{r=255,g=255,b=255,a=255},1)
assert(not art.visible and not primitive.visible,'pose must never expose failed partial shapes')
host:refresh();assert(failedWrites==1,'failed metadata must remain cached per frame')
ui.feedback:cancel();primitive.SetLocalRotation=rotate
host:refresh();assert(art.visible and not boxFor(state.enemies[2]):GetChild('portrait').visible,'feedback reset must retry a failed drawing for same box and actor ID')

ui:setActive(false);assert(not art.visible,'unmount must clear even with live matching actor')
ui:setActive(true);arts=drawings(state);art=arts[2];assert(art.visible)
state=battle({'cultist','fungi_beast'});assert(not art.visible and not art.alive,'replacement battle must retire old drawing and surface')
state=battle({'cultist','jaw_worm','acid_slime_m','cultist','cultist'});arts=drawings(state);art=arts[3]
assert(art.visible and not boxFor(state.enemies[3]):GetChild('portrait').visible,'five-enemy any-slot binding')
local _,_,size=EnemyView.position(5,3,state.enemies[3])
assert(near(art:GetChild('monsterSamples').localScaleX,size/106),'five-enemy geometry must contain drawing in current portrait')
host:resize(1920,1080);host:refresh();assert(art.visible)
ui.feedback:cancel();platform.nativeMonsterArtEnabled=false;host:refresh()
assert(not art.visible and boxFor(state.enemies[3]):GetChild('portrait').visible,'registered escape hatch must fall back to gallery')
assert(not boxFor(state.enemies[3]):GetChild('plate').visible and not boxFor(state.enemies[3]):GetChild('border').visible,'fallback retains existing UnitView background policy')
platform.nativeMonsterArtEnabled=true;host:refresh();assert(art.visible)
state=battle({'acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m'});arts=drawings(state)
for i=1,#arts do assert(arts[i].visible and not boxFor(state.enemies[i]):GetChild('portrait').visible,'all six duplicate drawings must be visible')end
local counts={}
for i=1,#arts do counts[i]=arts[i]:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000').rotationWrites end
host:refresh()
for i=1,#arts do assert(arts[i]:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000').rotationWrites==counts[i],'stable rendering must not rewrite primitive geometry')end
-- Rebind existing surfaces to shorter assets to prove stale primitive-tail cleanup.
local tail=arts[5]:GetChild('monsterSamples'):GetChild('group009'):GetChild('shape0596')
assert(tail.visible,'long drawing must populate the tail before shorter rebind')
local kinds={'jaw_worm','mad_gremlin','fat_gremlin','wizard_gremlin','spike_slime_l','acid_slime_m'}
local mixed=F.Combat.new(F.Data,{enemies=kinds,deck={'strike'},seed=42})
for i,actor in ipairs(state.enemies)do
 local replacement=mixed.enemies[i];replacement.id=actor.id;replacement.sourcePosition=actor.sourcePosition
 state.enemies[i]=replacement -- Same visual identity, complete matching source definition/intent/Power state.
end
host:refresh()
for i=1,#arts do assert(arts[i].visible and not boxFor(state.enemies[i]):GetChild('portrait').visible,'six mixed new drawings visible')end
assert(tail==arts[5]:GetChild('monsterSamples'):GetChild('group009'):GetChild('shape0596'),'shorter drawing must reuse same primitive surface')
assert(not tail.visible,'shorter next drawing must hide stale previous tail')
ui.feedback:cancel()
for i=1,#arts do assert(not arts[i].visible,'cancel clears every pool')end
state=battle({'acid_slime_m'});arts=drawings(state);art=arts[1];state.enemies[1].hp=1;host:refresh()
local strike
for slot,card in ipairs(state.hand)do if card.cardId=='strike' then strike=slot;break end end
assert(strike);panel:GetChild('card'..strike):GetChild('hit').click();boxFor(state.enemies[1]):GetChild('hit').click()
assert(state.enemies[1].hp==0,'actual card command must commit the lethal hit')
for _=1,200 do host:update(.05)end
assert(host.run.phase=='reward'and not art.visible,'real lethal feedback and reward transition must retire new art')
print('NATIVE_MONSTER_HOST_PASS actual monster-enabled generated GameUI -> any-slot / six simultaneous duplicates/mixed / idle / death / hide / restart / five enemies / resize / off switch')
