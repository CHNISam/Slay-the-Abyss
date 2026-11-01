local F=dofile('tests/lua/support/game_ui_fixture.lua')
local host,root=F.fixture()
assert(F.start(host));assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
local state=F.Combat.new(F.Data,{enemies={'collector','byrd'},deck={'strike'},seed=42})
local function move(actor,id)
 for index,intent in ipairs(actor.intents)do if intent.id==id then actor.intentIndex=index;return end end
 error('missing source fixture move '..id)
end
move(state.enemies[1],'spawn');move(state.enemies[2],'stunned')
state.enemies[1].sourcePosition={x=-400,y=0};state.enemies[2].sourcePosition={x=0,y=0}
host.run.combat=state;host:refresh()
local Surfaces=require('abyss_monster_surfaces')
local Powers=require('abyss_monster_power_surfaces')
local manager=assert(Surfaces.get(root:GetChild('battlePanel')))
local boxes={(manager:find(state.enemies[1].id)),(manager:find(state.enemies[2].id))}
for _,box in ipairs(boxes)do assert(not box:GetChild('intentIcon').visible,'UNKNOWN/STUN have no world base sprite')end
local function outputs(box)
 local result={}
 for _,layer in ipairs({'intentVfxBehind','intentVfxAfter'})do
  local pool=Powers.get(box:GetChild(layer))
  if pool then pool:each(function(control)result[#result+1]={box=control,icon=control:GetChild('icon')}end)end
 end
 return result
end
host:update(.49)
assert(#outputs(boxes[1])==0 and #outputs(boxes[2])==0,'createIntent .5 timer must not emit early')
host:update(.02)
assert(#outputs(boxes[1])==1 and #outputs(boxes[2])==1,'both original effect classes must produce native output')
local unknown,star=outputs(boxes[1])[1],outputs(boxes[2])[1]
assert(unknown.icon.imageId==require('abyss_theme').icon.intent.unknown)
assert(star.icon.imageId==require('abyss_theme').image.star)
local x,y,alpha=unknown.box.x,unknown.box.y,unknown.icon.imageColor.a
host.battleUI:render()
assert(unknown.box.x==x and unknown.box.y==y and unknown.icon.imageColor.a==alpha,'render cannot advance particle state')
local oldUnknown=unknown.box
assert(host:openDeck())
assert(not oldUnknown.alive,'covering UI must release native outputs')
host:update(.2) -- Original deck screen does not update the combat room.
assert(not oldUnknown.alive,'hidden screen must not recreate native particles')
host:closeDeck()
boxes={(manager:find(state.enemies[1].id)),(manager:find(state.enemies[2].id))}
local resumed=outputs(boxes[1])[1]
assert(resumed and resumed.box.x==x and resumed.box.y==y and resumed.icon.imageColor.a==alpha,'deck return must preserve particle state, not reset showIntent')
host:update(.4)
assert(resumed.box.alive,'source particle must retain its independent lifetime')
local all={}
for _,box in ipairs(boxes)do for _,output in ipairs(outputs(box))do all[#all+1]=output.box end end
assert(host:openDeck())
local nextBattle=F.Combat.new(F.Data,{enemies={'collector'},deck={'strike'},seed=44})
move(nextBattle.enemies[1],'spawn')
host.run.combat=nextBattle;host:refresh() -- New identity first observed while its UI is hidden.
host:closeDeck();host:update(.51)
local nextBox=assert(manager:find(nextBattle.enemies[1].id))
assert(#outputs(nextBox)==1,'inactive first observation must not consume the initial showIntent boundary')
local output=outputs(nextBox)[1];local current=output.box
local rotation=output.icon.SetLocalRotation
local colour=output.icon.imageColor
output.icon.SetLocalRotation=function(self,...)
 rotation(self,...);host:disable() -- Native setter re-enters retirement before paint can finish.
end
local ok,reason=pcall(host.update,host,.01)
assert(not ok and tostring(reason):find('intent particle publication cancelled'),'retired particle writes must stop immediately')
assert(output.icon.imageColor==colour,'retired particle received a later colour publication')
assert(not current.alive,'reentrant disable leaked current battle intent effect')
for _,control in ipairs(all)do assert(not control.alive,'battle replacement leaked prior native intent effect')end
print('MONSTER_INTENT_PARTICLE_GAME_UI_PASS')
