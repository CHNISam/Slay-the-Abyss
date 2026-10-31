local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursorX,cursorY
local host,root=F.fixture(nil,nil,nil,nil,nil,nil,{position=function()return cursorX,cursorY end})
assert(F.start(host))
assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
local ids={};for i=1,6 do ids[i]='acid_slime_m'end
local state=F.Combat.new(F.Data,{enemies=ids,deck={'strike'},seed=42})
for i,actor in ipairs(state.enemies)do actor.sourcePosition={x=-600+i*180,y=i*3}end
host.run.combat=state;host:refresh()
local stage=root:GetChild('battlePanel')
local surfaces=assert(require('abyss_monster_surfaces').get(stage))
local roots={};local count=0
surfaces:each(function(box,slot,entry)
 count=count+1;assert(entry.actor==state.enemies[entry.index])
 assert(box==surfaces:control(slot) and box.visible)
 assert(box:GetChild('hp').text==entry.actor.hp..'/'..entry.actor.maxHp)
 local art=box:GetChild('monsterArt');assert(art.visible and not box:GetChild('portrait').visible,'every instance must use new drawing')
 assert(art.x==0 and art.y==0,'nested art must not apply actor world position twice')
 assert(not roots[art]);roots[art]=true
 local shape=art:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')
 assert(shape.imageId and shape.rotation,'actual template native primitive was not written')
 assert(math.abs(box.x-((1440+entry.actor.sourcePosition.x)/1.5-640))<1e-8)
 local bottom=(require('abyss_battle_enemy_view').floorY+entry.actor.sourcePosition.y)/1.5-360
 local health=box:GetChild('hpFill');local intent=box:GetChild('intentHit')
 assert(math.abs(health.size[1]-170/1.5)<1e-8 and math.abs(health.size[2]-20/1.5)<1e-8,'source HP bar dimensions')
 assert(math.abs(box.y+health.y-(bottom-18/1.5))<1e-8,'HP bar follows original hitbox bottom')
 assert(math.abs(box.y+intent.y-(bottom+(130+32)/1.5))<1e-8,'intent follows original hitbox top, not square art')
 assert(math.abs(intent.size[1]-64/1.5)<1e-8,'original intent hitbox')
end)
assert(count==6,'six actual generated full actor templates must render without truncation')
for _,enemy in ipairs(state.enemies)do
 local control=surfaces:find(enemy.id)
 assert(not control:GetChild('intentBadge').visible and not control:GetChild('intentExtra').visible,'world intent must not use invented horizontal tooltip composites')
 assert(math.abs(control:GetChild('intentIcon').size[1]-math.min(128/1.5,require('abyss_theme').layout.intent.size*1.15))<1e-8,'full-bleed intent glyph size')
end

local hoverActor=state.enemies[2];local hoverBox=surfaces:find(hoverActor.id)
local hoverGeometry=require('abyss_battle_enemy_view').geometry(hoverActor)
cursorX,cursorY=640+hoverGeometry.hitX,360+hoverGeometry.hitY
host:update(.1)
assert(hoverBox:GetChild('name').visible,'original body hover should reveal name')
local nameAlpha=hoverBox:GetChild('name').fontColor.a
host.battleUI:render()
assert(hoverBox:GetChild('name').visible and hoverBox:GetChild('name').fontColor.a==nameAlpha,'render must preserve name fade')
cursorX,cursorY=nil,nil

local actor=state.enemies[3];local box=surfaces:find(actor.id)
host.battleUI.selected=state.hand[1].uid
actor.hp=1
box:GetChild('hit').click({touchId=33})
assert(actor.hp==0,'dynamic original-index targeting failed')
local sawIndependent=false
for _=1,500 do
 host:update(.01)
 if not host.battleUI.busy and host.battleUI.feedback.dying[actor.id]then
  local shape=box:GetChild('monsterArt'):GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')
  local before=shape.imageColor;local age=host.battleUI.feedback.dying[actor.id].age
  host.battleUI:render()
  local after=shape.imageColor
  assert(before.r==after.r and before.g==after.g and before.b==after.b and before.a==after.a,'render must preserve frozen death RGBA without a feedback tick')
  assert(age==host.battleUI.feedback.dying[actor.id].age,'render advanced death clock')
  sawIndependent=true;assert(surfaces:find(actor.id)==box and box.alive,'dying source instance retired at action completion')
 end
 if box.alive==false then break end
end
assert(sawIndependent,'source death clock must continue independently of completed actions')
assert(box.alive==false and not surfaces:find(actor.id),'terminal source death must reclaim native surface immediately')
local old={};surfaces:each(function(control)old[#old+1]=control end)
host:disable()
for _,control in ipairs(old)do assert(control.alive==false,'inactive battle leaked dynamic full unit')end
print('DYNAMIC_MONSTER_GAME_UI_PASS six complete source-bound actors/input/clear')
-- Exercise actual GameUI production rollback, not manual manager retirement.
for _,failure in ipairs({'allocate','bind'})do
 local api=F.monsterActors();local instantiate=api.instantiate;local created={};local attempts=0
 api.instantiate=function(index,parent)
  attempts=attempts+1
  if attempts==3 and failure=='allocate'then error('injected allocation rejection')end
  local control=instantiate(index,parent);created[#created+1]=control
  if attempts==3 and failure=='bind'then
   local hit=control:GetChild('hit');local register=hit.AddCursorEventListener
   hit.AddCursorEventListener=function(self,...)
    register(self,...);error('injected native listener rejection')
   end
  end
  return control
 end
 local canvas=F.control({children=F.Layout});local nativeRoot=F.Viewport.apply(canvas,1280,720)
 local ui=F.GameUI.new(nativeRoot,F.Data,F.Presentation,'click',{seed=1,monsterActors=api,
  imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
 nativeRoot.ui=ui;assert(F.start(ui));assert(require('abyss_run').startCombat(ui.run,'cultist_solo'))
 ui.run.combat=F.Combat.new(F.Data,{enemies=ids,deck={'strike'},seed=42})
 local ok,reason=pcall(ui.refresh,ui)
 assert(not ok and tostring(reason):find('injected'),'native failure must stay explicit')
 for _,control in ipairs(created)do assert(not control.alive,'failed production render leaked an owned actor')end
 local manager=require('abyss_monster_surfaces').get(nativeRoot:GetChild('battlePanel'))
 local remaining=0;manager:each(function()remaining=remaining+1 end);assert(remaining==0)
 assert(not pcall(ui.refresh,ui),'failure latch must prevent silent allocation retry')
 ui:disable()
 for _,control in ipairs(created)do assert(not control.alive,'disable left failed production actor alive')end
end
print('DYNAMIC_MONSTER_GAME_UI_ROLLBACK_PASS allocation/bind/disable')
