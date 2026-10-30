package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Feedback=require('abyss_feedback')
local Combat,Events=require('abyss_combat'),require('abyss_events')
local Data,Theme,Presentation=require('abyss_data'),require('abyss_theme'),require('abyss_presentation')
local F=dofile("tests/lua/support/game_ui_fixture.lua")
local Surfaces=require("abyss_monster_surfaces")
local EnemyView=require("abyss_battle_enemy_view")
local control=F.control
-- Exercise real generated actor templates, not the retired fixed enemy slots.
local function nativeFeedback(stage,platform,complete)
 platform=F.withMonsterActors(platform)
 local surfaces=Surfaces.new(stage,platform)
 local feedback
 feedback=Feedback.new(stage,platform,function(frame)
  local rows=EnemyView.slots(frame,feedback)
  surfaces:select(rows,feedback.battle)
  surfaces:each(function(box,slot,entry)
   local x,_,_,_,y=EnemyView.position(#rows,slot,entry.actor)
   box:SetAnchoredPosition(x,y);box:SetVisible(true)
  end)
 end,complete)
 return feedback
end
local function find(entries,name)
 for _,e in ipairs(entries)do if e.name==name then return e end;local found=find(e.children or{},name);if found then return found end end
end
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(id,destination)
 local stage=control(assert(find(require('abyss_ui_layout'),'battlePanel')))
 local completions=0
 local feedback=nativeFeedback(stage,{imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end},function(failure)assert(not failure,tostring(failure));completions=completions+1 end)
 local battle=Combat.new(Data,{deck={id},enemies={'cultist'},seed=11})
 local before,first=Events.frame(battle),#battle.events+1
 local uid=battle.hand[1].uid
 assert(Combat.play(battle,uid,1))
 local committed=Combat.copy(battle)
 feedback:begin(before,battle,first,Presentation,{0,-200})
 local observed,endpoint=false,false
 for _=1,500 do
  feedback:update(.01)
  for slot,entry in pairs(feedback.cardFlow and feedback.cardFlow.active or{})do if entry.uid==uid then
   assert(entry.to==destination,'played UID sent to the wrong destination')
   assert(stage:GetChild('feedback'):GetChild('cardTrail'..slot).visible)
   observed=true
   if entry.arrived then
    local expected=destination=='discard'and Theme.layout.discardPile.position or destination=='exhaust'and{Theme.layout.topBar.exhaustIcon[1],Theme.layout.topBar.y}or Theme.layout.player.position
    assert(entry.finish[1]==expected[1]and entry.finish[2]==expected[2]);endpoint=true
   end
  end end
 end
 assert(observed and endpoint,'played card must visibly reach its committed destination')
 assert(completions==1 and not feedback.busy and not feedback.cardFlow:busy())
 same(battle,committed)
 feedback:cancel();assert(not feedback.cardFlow:busy())
 print('ok card_flow_feedback - '..id..' reaches '..destination..' without changing committed rules/events/RNG')
end
test('strike','discard')
test('impervious','exhaust')
test('inflame','power')

-- A normal owner turn discards every old hand UID before the shuffle brings them back.
local stage=control(assert(find(require('abyss_ui_layout'),'battlePanel')))
local feedback=nativeFeedback(stage,{imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end},function(failure)assert(not failure,tostring(failure))end)
local battle=Combat.new(Data,{deck={'strike','defend','strike','defend','strike'},enemies={'cultist'},seed=11})
local before,first=Events.frame(battle),#battle.events+1
assert(Combat.endTurn(battle))
local committed=Combat.copy(battle)
feedback:begin(before,battle,first,Presentation)
local discarded,shuffled={},{}
for _=1,1000 do
 feedback:update(.01)
 for _,entry in pairs(feedback.cardFlow.active)do
  if entry.from=='hand'and entry.to=='discard'then discarded[entry.uid]=true end
  if entry.from=='discard'and entry.to=='draw'then shuffled[entry.uid]=true end
 end
end
for _,card in ipairs(before.hand)do assert(discarded[card.uid]and shuffled[card.uid],'turn cleanup and reshuffle must retain each UID')end
same(battle,committed)
assert(not feedback.cardFlow:busy())
print('ok card_flow_feedback - normal end-turn discard and reshuffle preserve every UID and committed event/RNG state')
