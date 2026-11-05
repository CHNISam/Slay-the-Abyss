-- Private visual adapter. Core modules are unchanged da6ec560 sources.
-- Only fixture construction and presentation live here; all commands use Run.
local Run=require('abyss_run')
local Combat=require('abyss_combat')
local Data=require('abyss_data')
local Events=require('abyss_events')
local Theme=require('abyss_theme')
-- Match approved private hand geometry for the production gesture classifier.
Theme.layout.card.size={150,210}
Theme.layout.hand.spacingMin,Theme.layout.hand.spacingMax=124,124
Theme.layout.hand.y,Theme.layout.hand.arcDegrees=-290,4
Theme.motion.hoverLift,Theme.motion.hoverScale=32,1.12
local Input=require('abyss_card_input')
local Gestures=require('abyss_battle_card_gestures')
local M={input=Input,intent=Gestures.Intent,Run=Run,Combat=Combat,Events=Events,Theme=Theme}
local order={strike=1,defend=2,bash=3}
local function duration(e)
 if e.kind=='play' then return Theme.motion.base end
 if e.kind=='damage' then return .2 end
 if e.kind=='block' or e.kind=='status' or e.kind=='heal' then return Theme.motion.base end
 if e.kind=='intent' then return Theme.motion.enemyActionGap end
 if e.kind=='player_turn' or e.kind=='enemy_turn' then return Theme.motion.banner end
 return 0
end
function M.new()
 local run=Run.new(Data,'42');assert(Run.startCombat(run,'cultist_solo'))
 run.combat=Combat.new(run.data,{deck={'strike','defend','strike','bash','defend'},enemies={'fungi_beast','fungi_beast'},seed=11,hp=68,maxHp=80,gold=99})
 -- This is an explicit five-card test fixture, not a real campaign opening draw.
 local pool=run.combat.hand;local hand={}
 for _,id in ipairs({'strike','defend','strike','bash','defend'})do
  for i,c in ipairs(pool)do if c.cardId==id then hand[#hand+1]=table.remove(pool,i);break end end
 end
 run.combat.hand=hand
 local a={run=run,busy=false,queue={},effects={},commandCount=0,display=Events.frame(run.combat),epoch=0}
 function a:find(id)for i,c in ipairs(self.run.combat.hand)do if c.cardId==id then return i,c end end end
 function a:capture(slot,touch)
  local b=self.run.combat;local c=b.hand[slot];if not c then return end
  local n=#b.hand;local x=(slot-(n+1)/2)*124;local y=-290-math.abs(slot-(n+1)/2)*6
  local g={uid=c.uid,slot=slot,run=self.run,battle=b,turn=b.turn,phase=self.run.phase,origin={x,y},sx=x,sy=y,x=x,y=y,grabDx=0,grabDy=0,epoch=self.epoch}
  Input.begin(g,720,touch,1280);g.handCancelY=-258
  return g
 end
 function a:ready(g)
  local b=self.run.combat
  return g and not g.consumed and not self.busy and g.run==self.run and g.battle==b and g.turn==b.turn and g.phase==self.run.phase
   and self.run.phase=='combat' and b.phase=='player' and b.hand[g.slot] and b.hand[g.slot].uid==g.uid
 end
 function a:cancel(g)if g then g.cancelled=true;g.consumed=true end end
 function a:submit(g,target,commandId)
  if not self:ready(g) then return false,'stale_or_busy' end
  local b=self.run.combat;local before=Events.frame(b);local first=#b.events+1
  local t=os.clock();local ok,reason=Run.play(self.run,g.uid,target,commandId)
  self.lastCommandMs=(os.clock()-t)*1000
  if not ok then return false,reason end
  g.consumed=true;self.commandCount=self.commandCount+1;self.epoch=self.epoch+1
  self.queue={};for i=first,#b.events do self.queue[#self.queue+1]=b.events[i] end
  self.display=before;self.busy=#self.queue>0;self.index=0;self.age=0;self.origin=g.origin;self.playedUid=g.uid
  self:advance();return true
 end
 function a:advance()
  self.index=self.index+1;self.current=self.queue[self.index];self.age=0
  if not self.current then self.busy=false;self.display=Events.frame(self.run.combat);return end
  if self.current.frame then self.display=self.current.frame end
  if self.current.kind=='damage' or self.current.kind=='block' then
   local d=self.current.detail;self.effects[#self.effects+1]={kind=self.current.kind,target=d.target,amount=d.amount or d.value,age=0}
  end
 end
 function a:update(dt)
  assert(dt>=0 and dt<=.1,'bounded presentation dt')
  for i=#self.effects,1,-1 do local e=self.effects[i];e.age=e.age+dt;if e.age>=Theme.motion.damagePop then table.remove(self.effects,i)end end
  if not self.busy then return end
  self.age=self.age+dt
  if self.age>=duration(self.current)then
   self:advance()
   while self.busy and duration(self.current)==0 do self:advance()end
  end
 end
 return a
end
return M
