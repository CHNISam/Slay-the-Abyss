local F=dofile('tests/lua/support/game_ui_fixture.lua')
local host,root=F.fixture()
assert(F.start(host));assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
local battle=F.Combat.new(F.Data,{enemies={'wizard_gremlin','cultist'},deck={'strike'},seed=42})
local actor=battle.enemies[1];actor.aiCharge=actor.ai.chargeLimit-1
host.run.combat=battle;host:refresh();host:update(.51)
local manager=require('abyss_monster_surfaces').get(root:GetChild('battlePanel'))
local box=assert(manager:find(actor.id));local icon=box:GetChild('intentIcon')
assert(not icon.visible,'initial UNKNOWN no base')
host.battleUI:endTurn()
local feedback=host.battleUI.feedback
local observed=false
for _=1,1200 do
 local e=feedback.current
 if e and e.kind=='intent' and e.detail.enemy==battle.enemies[2].id then
  assert(host.battleUI.displayBattle.enemies[1].intents[host.battleUI.displayBattle.enemies[1].intentIndex].id==actor.ai.attackIntent,'wizard queued charge roll must already select attack')
  host.battleUI:render();assert(not icon.visible,'render should retain historical UNKNOWN before next showIntent')
  host:update(.001)
  assert(not icon.visible,'tick exposed next attack before source createIntent/showIntent boundary')
  observed=true;break
 end
 host:update(.01)
end
assert(observed,'missing second monster intent playback')
local shown=false
for _=1,1200 do
 local e=feedback.current
 if e and e.kind=='player_turn' then
  assert(icon.visible,'source showIntent must reveal newly selected attack')
  local before=icon.imageColor.a
  host:update(.01)
  assert(icon.imageColor.a>before,'showIntent alpha must resume after repeated-move boundary')
  shown=true;break
 end
 host:update(.01)
end
assert(shown,'missing player_turn source boundary')
for _=1,200 do if not host.battleUI.busy then break end;host:update(.01)end
assert(not host.battleUI.busy,'first playback must finish before replacement fixture')
-- Repeated exact move still receives real showIntent at the next player turn.
local repeatBattle=F.Combat.new(F.Data,{enemies={'cultist'},deck={'strike'},seed=43})
local repeated=repeatBattle.enemies[1]
for index,intent in ipairs(repeated.intents)do if intent.id==repeated.ai.attackIntent then repeated.intentIndex=index end end
repeated.aiPhase='attacking'
host.run.combat=repeatBattle;host:refresh();host:update(0);host:update(.8)
local repeatBox=assert(manager:find(repeated.id));local repeatIcon=repeatBox:GetChild('intentIcon')
assert(repeatIcon.visible and repeatIcon.imageColor.a>0,'repeat fixture needs visible original attack')
local moveBefore=repeated.intents[repeated.intentIndex].id
host.battleUI:endTurn();local repeatedBoundary=false
for _=1,1200 do
 local e=feedback.current
 if e and e.kind=='player_turn' then
  assert(repeated.intents[repeated.intentIndex].id==moveBefore,'fixture must repeat exactly the same move')
  assert(repeatIcon.visible and repeatIcon.imageColor.a==0,'same move must reset alpha at real player_turn')
  host:update(.1)
  assert(math.abs(repeatIcon.imageColor.a-25.5)<1e-7,'same move alpha must rise from zero after actual showIntent')
  repeatedBoundary=true;break
 end
 host:update(.01)
end
assert(repeatedBoundary,'missing repeated-move player_turn')
host:disable();print('INDEPENDENT_REAL_ROLL_BOUNDARY_PASS')
