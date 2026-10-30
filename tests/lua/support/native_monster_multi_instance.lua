-- Fixed original per-instance geometry/lifecycle over actual generated actor templates.
-- The native engine is the shared recording clone/destroy fixture, not a five-slot substitute.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Actor=require('abyss_actor')
local Art=require('abyss_monster_art')
local View=require('abyss_battle_enemy_view')
local Catalog=require('abyss_monster_art_data')
local host,root,ui,stage,surfaces
local function setup(fast)
 if ui then ui.active=false;ui:render()end
 host,root=F.fixture(nil,nil,nil,{CursorDown='down',CursorUp='up',CursorDrag='drag',CursorEndDrag='endDrag',CursorEnter='enter',CursorExit='exit'})
 assert(host:setFastMode(fast),'fast mode must be selected through the real menu setting')
 assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'))
 ui,stage=host.battleUI,root:GetChild('battlePanel')
 surfaces=assert(require('abyss_monster_surfaces').get(stage))
end
setup(ABYSS_MUTATION_CASE=='fast-contact-rgb-death')
local function near(a,b)return math.abs(a-b)<1e-8 end
local function copy(v,seen)
 if type(v)~='table'then return v end
 seen=seen or {};if seen[v]then return seen[v]end
 local out={};seen[v]=out;for k,x in pairs(v)do out[copy(k,seen)]=copy(x,seen)end;return out
end
local function equal(a,b,seen)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 seen=seen or {};if seen[a]then return seen[a]==b end;seen[a]=b
 for k,v in pairs(a)do if not equal(v,b[k],seen)then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function box(actor)return assert(surfaces:find(actor.id),'missing actual actor surface '..actor.id)end
local function art(actor)return box(actor):GetChild('monsterArt')end
local function primitive(actor,n)
 n=n or 1;return art(actor):GetChild('monsterSamples'):GetChild(string.format('group%03d',math.floor((n-1)/60))):GetChild(string.format('shape%04d',n-1))
end
local function six()return {'acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m','acid_slime_m'}end
local function battle(kinds,deck)
 local previous={};surfaces:each(function(control)previous[#previous+1]=control end)
 local state=F.Combat.new(F.Data,{deck=deck or {'strike','strike','defend'},enemies=kinds,seed=42,hp=1000,maxHp=1000})
 -- Synthetic group positions are explicit source-space fixture data, not encounter rules.
 if #kinds>5 then for i,actor in ipairs(state.enemies)do actor.sourcePosition={x=-640+i*160,y=i*3}end end
 host.run.combat,host.run.hp,host.run.maxHp=state,1000,1000
 host:refresh()
 for _,control in ipairs(previous)do assert(control.alive==false,'new battle retained previous template instance')end
 return state
end
local function assertRows(state)
 local rows=View.slots(state,ui.feedback);local seen={};local count=0
 for _,row in ipairs(rows)do
  local control,slot,entry=surfaces:find(row.id);assert(control and control.alive and control.visible)
  assert(entry.id==row.id and entry.index==row.index,'surface lost original actor index')
  assert(not seen[control]);seen[control]=true
  assert(art(row.actor).visible and not control:GetChild('portrait').visible,'every drawable instance must use its own new drawing')
  assert(ui.feedback.slotOwners[slot]==row.id,'feedback ownership lost actor identity')
 end
 surfaces:each(function(control)count=count+1;assert(seen[control],'unexpected retained surface')end)
 assert(count==#rows,'dynamic manager truncated drawable actors')
 return rows
end
local function test(name,fn)
 if not ABYSS_MUTATION_CASE or ABYSS_MUTATION_CASE==name then fn();print('MULTI_INSTANCE_PASS '..name)end
end

test('six-duplicate-geometry',function()
 local state=battle(six());local rows=assertRows(state);assert(#rows==6)
 local handles,poses={},{ }
 for _,row in ipairs(rows)do
  local actor=row.actor;local c=box(actor);local p=actor.sourcePosition
  local x=320+p.x/1.5;local bottom=(340+p.y)/1.5-360;local size=170/1.5
  assert(near(c.x,x)and near(c.y,bottom+size/2),'actual instance must use exact original position')
  for count=1,8 do local px,_,w,_,py=View.position(count,9-count,actor)
   assert(near(px,x)and near(py,bottom+size/2)and near(w,size),'count/slot changed fixed source geometry')end
  local hit=c:GetChild('hit');assert(near(hit.sizeDeltaX,170/1.5)and near(hit.sizeDeltaY,130/1.5),'source hitbox lost')
  handles[actor.id]=c;poses[actor.id]={art(actor).x,art(actor).y,art(actor).localScaleX,art(actor).localScaleY,copy(primitive(actor).imageColor)}
 end
 local victim=state.enemies[3];Art.pose(box(victim),7,-3,1.2,.8,{r=128,g=255,b=64,a=255},.4)
 assert(near(art(victim).localScaleX,1.2)and primitive(victim).imageColor.a<poses[victim.id][5].a,'explicit per-instance pose and tint must reach selected drawing')
 for _,actor in ipairs(state.enemies)do if actor~=victim then assert(equal(poses[actor.id],{art(actor).x,art(actor).y,art(actor).localScaleX,art(actor).localScaleY,copy(primitive(actor).imageColor)}),'pose/tint leaked to another same species instance')end end
 local before=copy(state);for _=1,4 do ui:render()end;assert(equal(before,state),'render altered nested combat or RNG')
 for _,actor in ipairs(state.enemies)do assert(box(actor)==handles[actor.id],'stable actor reallocated its full template')end
end)

test('six-mixed-exact-art',function()
 local state=battle({'jaw_worm','mad_gremlin','fat_gremlin','wizard_gremlin','spike_slime_l','red_louse'})
 assert(#assertRows(state)==6)
 for _,actor in ipairs(state.enemies)do
  local asset=assert(Catalog.assets[Catalog.bindings[actor.definitionId]])
  local tone=box(actor):GetChild('portrait').imageColor
  for n,expected in ipairs(asset.slots)do
   local c=primitive(actor,n)
   assert(c.visible and c.imageId==expected.image and equal(c.rotation,expected.rotation),'mixed instance drew wrong primitive')
   assert(near(c.x,expected.position[1])and near(c.y,expected.position[2])and near(c.sizeDeltaX,expected.size[1])and near(c.sizeDeltaY,expected.size[2]),'mixed instance reused wrong geometry')
   local rgba=expected.colour
   assert(c.imageColor.r==math.floor(rgba[1]*tone.r/255)and c.imageColor.g==math.floor(rgba[2]*tone.g/255)and c.imageColor.b==math.floor(rgba[3]*tone.b/255)and c.imageColor.a==math.floor(rgba[4]*(tone.a or 255)/255),'mixed instance colour or opacity differs from source')
  end
  for n=#asset.slots+1,600 do assert(not primitive(actor,n).visible,'unused primitive tail must be hidden')end
 end
end)

local function deathCase(fast,card,hp)
 if host.fastMode~=fast then setup(fast)end
 local state=battle(six(),{card});local victim=state.enemies[3];victim.hp=hp;host:refresh();assert(ui.fastMode==fast)
 local original={};for _,actor in ipairs(state.enemies)do local c=box(actor);original[actor.id]={box=c,x=c.x,y=c.y,size=c:GetChild('portrait').sizeDeltaY,hp=actor.hp}end
 ui.selected=state.hand[1].uid;box(victim):GetChild('hit').click({touchId=303})
 assert(victim.hp==0,'actual card command must commit lethal core damage')
 local dying,priorTint
 for _=1,160 do
  host:update(.05)
  if ui.feedback.dying[victim.id]then dying=ui.feedback.dying[victim.id];break end
  local current=ui.feedback.current
  if current and current.kind=='damage'and current.detail.target==victim.id then priorTint=copy(ui.feedback.tints[victim.id])end
 end
 assert(dying and dying.lifetime==(fast and 1 or 1.8),'source independent death clock must start at lethal contact life='..tostring(dying and dying.lifetime)..' fast='..tostring(fast))
 assert(ui.feedback.current.kind=='damage','lethal contact must begin fade during DamageAction, not deferred death cue')
 if card=='twin_strike'then
  assert(priorTint and (priorTint.r~=F.Theme.color.text.r or priorTint.g~=F.Theme.color.text.g),'first real hit did not supply contact RGB')
  assert(dying.tone.r==priorTint.r and dying.tone.g==priorTint.g and dying.tone.b==priorTint.b,'death did not preserve previous rendered contact RGB')
 end
 local previousAlpha=dying.alpha;local previousAge=dying.age
 host:update(.05)
 assert(ui.feedback.dying[victim.id]==dying and near(dying.age,previousAge+.05)and near(dying.alpha,previousAlpha*.85),'original independent alpha recurrence changed')
 local shape=primitive(victim);local source=Catalog.assets[Catalog.bindings[victim.definitionId]].slots[1].colour
 assert(shape.imageColor.a==math.floor(source[4]*(dying.tone.a or 255)/255*dying.alpha),'real actorPainter death pose must reach native middle drawing')
 assert(shape.imageColor.r==math.floor(source[1]*dying.tone.r/255)and shape.imageColor.g==math.floor(source[2]*dying.tone.g/255)and shape.imageColor.b==math.floor(source[3]*dying.tone.b/255),'native fade lost exact contact RGB')
 assert(art(victim).x==box(victim):GetChild('portrait').x and art(victim).y==box(victim):GetChild('portrait').y and art(victim).localScaleX==1 and art(victim).localScaleY==1,'source death invented sinking or collapse; existing contact knockback must match the painter')
 assert(#assertRows(state)==6,'five living plus pending corpse require six actual surfaces')
 local sawActionFinish=false
 for _=1,80 do
  if not ui.feedback.dying[victim.id]then break end
  if not ui.busy then sawActionFinish=true end
  for _,actor in ipairs(state.enemies)do if actor~=victim then
   local c=box(actor);local old=original[actor.id]
   assert(c==old.box and c.x==old.x and c.y==old.y and c:GetChild('portrait').sizeDeltaY==old.size,'death relocated/resized/replaced survivor')
   assert(actor.hp==old.hp and not ui.feedback.dying[actor.id]and primitive(actor).imageColor.a==255,'death leaked to survivor')
  end end
  if dying.age<dying.lifetime-.1 then assert(original[victim.id].box.alive,'corpse retired before independent timer')end
  host:update(.05)
 end
 assert(sawActionFinish,'nonterminal action must finish while original creature timer continues')
 assert(not ui.feedback.dying[victim.id]and ui.feedback.deaths[victim.id],'death timer did not finish')
 assert(original[victim.id].box.alive==false and not surfaces:find(victim.id),'terminal corpse full template not destroyed')
 assert(#assertRows(state)==5)
 for _,actor in ipairs(state.enemies)do if actor~=victim then local c=box(actor);assert(c==original[actor.id].box and c.x==original[actor.id].x and c.y==original[actor.id].y,'terminal removal changed survivor coordinates or handles')end end
 local actor=state.enemies[4];box(actor):GetChild('hit').click({touchId=304})
 assert(ui.target==4 and ui.info and ui.info.id==actor.id,'fresh target did not preserve original core index')
 stage:GetChild('statusInfo'):GetChild('hit').click({touchId=304})
 local nextState=battle(six());assert(nextState.enemies[3].id==victim.id)
 assert(not ui.feedback.dying[victim.id]and not ui.feedback.deaths[victim.id],'new battle inherited genuine death ledger')
 assert(#assertRows(nextState)==6)
end

test('normal-middle-death',function()deathCase(false,'strike',1)end)
test('fast-contact-rgb-death',function()deathCase(true,'twin_strike',7)end)

test('failed-dynamic-art-isolation',function()
 local state=battle(six());local victim=state.enemies[3];local c=primitive(victim)
 ui.feedback:cancel();local original=c.SetLocalRotation;local attempts=0
 c.SetLocalRotation=function()attempts=attempts+1;return false end
 host:refresh();assert(not art(victim).visible and box(victim):GetChild('portrait').visible)
 for _,actor in ipairs(state.enemies)do if actor~=victim then assert(art(actor).visible and not box(actor):GetChild('portrait').visible,'one failed image hid another instance')end end
 host:refresh();assert(attempts==1,'failed art retried every render')
 Art.pose(box(victim),3,4,2,2,F.Theme.color.text,1);assert(not art(victim).visible,'failed partial picture became paintable')
 ui.feedback:cancel();c.SetLocalRotation=original;host:refresh();assertRows(state)
 local old={};surfaces:each(function(control)old[#old+1]=control end)
 ui.active=false;ui:render();for _,control in ipairs(old)do assert(control.alive==false,'inactive battle leaked dynamic actor template')end
 ui.active=true;ui:render();assertRows(state)
end)

test('source-summon-insertion',function()
 local state=battle(six());local old={};local handles={}
 for i,actor in ipairs(state.enemies)do old[i]=actor;handles[actor.id]=box(actor)end
 -- Dead actors remain in MonsterGroup and participate in SpawnMonsterAction's count.
 F.Combat.damage(state,state.player,old[2],999,true)
 local created=F.Combat.summonEnemies(state,{{id='wizard_gremlin',x=160,y=5},{id='mad_gremlin',x=160,y=6}})
 assert(#created==2 and #state.enemies==8)
 -- Existing offsets are -480,-320,-160,0,160,320. Wizard constructor adds -35.
 -- The new equal-X mad gremlin goes before the previous actor at X=160.
 local expected={old[1],old[2],old[3],old[4],created[1],created[2],old[5],old[6]}
 for i,actor in ipairs(expected)do assert(state.enemies[i]==actor,'source summon insertion ignored dead entries, constructor delta, or equal-X ordering')end
 host:refresh();assert(#assertRows(state)==7,'seven living source actors must all own actual template instances')
 for _,actor in ipairs(old)do if Actor.isPresent(actor)then assert(box(actor)==handles[actor.id],'summon insertion replaced an existing actor template')end end
 for _,actor in ipairs(created)do local g=View.geometry(actor);assert(near(box(actor).x,g.x)and near(box(actor).y,g.y))end
 local before=copy(state);for _=1,4 do ui:render()end
 assert(equal(before,state),'summon rendering changed nested core state, ordering, or RNG')
end)

test('real-summons-no-render-rng',function()
 local state=battle({'mad_gremlin','sneaky_gremlin','gremlin_leader'});local leader=state.enemies[3]
 for _=1,30 do
  for _,enemy in ipairs(state.enemies)do if enemy~=leader and Actor.isActive(enemy)then F.Combat.damage(state,state.player,enemy,999,true)end end
  assert(F.Combat.endTurn(state));if #state.enemies>=7 then break end
 end
 assert(#state.enemies>=7,'real summon fixture must preserve historical core entries')
 host:refresh();local rows=assertRows(state);local live=0
 for _,actor in ipairs(state.enemies)do if Actor.isPresent(actor)then live=live+1 end end
 assert(#rows==live)
 for _,row in ipairs(rows)do
  local g=View.geometry(row.actor);local c=box(row.actor)
  assert(near(c.x,g.x)and near(c.y,g.y),'summon did not use its own fixed constructor coordinates')
 end
 local before=copy(state);for _=1,4 do ui:render()end
 assert(equal(before,state),'render changed core enemy order, nested state or RNG')
end)
print('NATIVE_MONSTER_MULTI_INSTANCE_PASS dynamic source contracts')
