package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Feedback=require('abyss_feedback')
local Combat=require('abyss_combat')
local Events=require('abyss_events')
local Data=require('abyss_data')
local Actors=require('abyss_actor')
local Powers=require('abyss_combat_effect_powers')
local Stances=require('abyss_stances')
local Presentation=require('abyss_presentation')
local Surfaces=require('abyss_monster_surfaces')
local EnemyView=require('abyss_battle_enemy_view')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function find(rows,name)
 for _,r in ipairs(rows)do if r.name==name then return r end;local v=find(r.children or {},name);if v then return v end end
end
local function harness(fast)
 local h={sounds={},seen={},done={},tick=0}
 local stage=F.control(assert(find(require('abyss_ui_layout'),'battlePanel')))
 local platform={monsterActors=F.monsterActors(),imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
 sound=function(cue)h.sounds[#h.sounds+1]=cue end}
 h.surfaces=Surfaces.new(stage,platform)
 h.battle=Combat.new(Data,{deck={'strike'},enemies={'acid_slime_m','acid_slime_m'},seed=42})
 local function present(frame)
  local rows=EnemyView.slots(frame,h.feedback);h.surfaces:select(rows,h.battle)
  for _,row in ipairs(rows)do h.feedback.bindEnemySlot(row.controlSlot,row.id);h.surfaces:find(row.id):SetVisible(true)end
  local e=h.feedback.current
  if e then
   h.seen[#h.seen+1]={entry=e,tick=h.tick,frame=frame,sounds=#h.sounds}
   assert(frame.enemies[1].id==h.battle.enemies[1].id and #frame.enemies==2)
   if e.sourceIntentPowers then
    assert(e.sourceIntentPowers.scope=='all-monsters')
    assert(frame.player.noDraw==e.frame.player.noDraw and frame.enemies[2].statuses.weak==e.frame.enemies[2].statuses.weak)
   end
  end
 end
 h.feedback=Feedback.new(stage,platform,present,function(err)assert(not err,err);h.done[#h.done+1]=h.tick end)
 h.feedback:setFastMode(fast);present(h.battle)
 return h
end
local function produce(h,ordinary)
 local s=h.battle
 Actors.addStatus(s.enemies[2],'weak',3);s.events={};h.before=Events.frame(s)
 assert(Actors.applyNoDraw(s,s.player))
 if ordinary then Actors.block(s,s.player,2,true)end
 assert(Powers.removeStatus({state=s,effect={targetId=s.enemies[2].id,status='weak',value=1,op='reduceStatus'},helpers={event=Events.emit}}))
 assert(Stances.change(s,'Neutral')==false)
 if ordinary then Actors.block(s,s.player,3,true)end
 assert(Stances.change(s,'Neutral')==false)
 h.events=s.events
 assert(#h.events==(ordinary and 6 or 4))
 assert(h.events[1].frame.player.noDraw and h.events[1].frame.enemies[2].statuses.weak==3)
 assert(h.events[ordinary and 3 or 2].frame.enemies[2].statuses.weak==2)
end
local function run(fast,keep,ordinary)
 local h=harness(fast);produce(h,ordinary)
 if not keep then local q={};for _,e in ipairs(h.events)do if e.kind~='source_intent_powers'then q[#q+1]=e end end;h.battle.events=q end
 h.feedback:begin(h.before,h.battle,1,Presentation,{0,-200})
 local trace={}
 local function sample()
  local e=h.feedback.current
  assert(not e or e.kind~='source_intent_powers','synchronous callback escaped as a playback frame')
  trace[#trace+1]=table.concat({h.tick,tostring(h.feedback.busy),e and e.kind or '-',h.feedback.busy and h.feedback.elapsed or 0,#h.sounds},'|')
 end
 sample()
 while h.feedback.busy do h.tick=h.tick+1;assert(h.tick<200);h.feedback:update(.01);sample()end
 assert(#h.done==1)
 if keep then
  assert(#h.seen==#h.events,'each callback frame must reach the presentation consumer')
  for i,seen in ipairs(h.seen)do assert(seen.entry==h.events[i],'source frame order/identity changed')end
  if ordinary then
   assert(h.seen[1].tick==0 and h.seen[2].tick==0,'leading callback took a frame')
   assert(h.seen[3].tick==h.seen[4].tick and h.seen[4].tick==h.seen[5].tick,'middle callbacks took a frame')
   assert(h.seen[3].sounds==h.seen[4].sounds and h.seen[4].sounds==h.seen[5].sounds,'callback emitted audio')
   assert(h.seen[6].tick==h.done[1],'trailing callback delayed completion')
   assert(h.sounds[1]=='block_gain' and h.sounds[2]=='block_gain' and #h.sounds==2)
  else assert(h.tick==0 and h.done[1]==0 and #h.sounds==0,'callback-only batch waited or emitted sound')end
 end
 h.surfaces:clear()
 return table.concat(trace,'\n'),table.concat(h.sounds,','),h.done[1]
end
for _,fast in ipairs({false,true})do
 for _,ordinary in ipairs({false,true})do
  local a,sa,ta=run(fast,true,ordinary);local b,sb,tb=run(fast,false,ordinary)
  assert(a==b,'source callbacks changed ordinary action playback trace')
  assert(sa==sb and ta==tb,'source callbacks changed sound/completion timing')
 end
end
print('SOURCE_INTENT_POWER_FEEDBACK_PASS 4')
