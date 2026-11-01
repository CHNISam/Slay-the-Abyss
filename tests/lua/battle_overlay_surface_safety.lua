local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Surfaces=require('abyss_monster_surfaces')
local host,ui,panel,event,tap=H.setup({'strike','defend'},{'cultist'})
local manager=assert(Surfaces.get(panel));local state=host.run.combat
local box=assert(manager:find(state.enemies[1].id));local hp=state.enemies[1].hp
local strike
for i,card in ipairs(state.hand)do if card.cardId=='strike'then strike=i end end
assert(strike);tap('card'..strike,1);event('enemy1','down',2)
assert(host:openDeck());assert(box.alive and not box.visible)
local clock=ui.feedback.idleClock
for _=1,5 do host:update(.1)end
assert(ui.feedback.idleClock==clock,'suspended actor must not animate')
event('enemy1','up',2);event('enemy1','click',2)
assert(state.enemies[1].hp==hp,'hidden old input must not play')
host:closeDeck();event('enemy1','up',2);event('enemy1','click',2)
assert(state.enemies[1].hp==hp,'old release after resume must not play')
tap('card'..strike,3);tap('enemy1',4)
assert(state.enemies[1].hp<hp,'fresh input must still play after resume')
host:disable()
-- Native rejection must not leak retained handles; explicit refresh can recover.
for _,mode in ipairs({'false','throw'})do
 local game,battleUI,battlePanel=H.setup({'strike'},{'cultist'})
 local surfaces=assert(Surfaces.get(battlePanel));local id=game.run.combat.enemies[1].id
 local actor=assert(surfaces:find(id));local visible=actor.SetVisible;local failed=false
 actor.SetVisible=function(self,value)
  if value==false and not failed then failed=true;if mode=='throw'then error('injected suspend failure')end;return false end
  return visible(self,value)
 end
 local ok=pcall(game.openDeck,game)
 assert(not ok and failed,'injected suspend failure must be surfaced')
 assert(not actor.alive and not surfaces:find(id),'failed suspension must clean up retained actor')
 game:closeDeck();local resumed=assert(surfaces:find(id));assert(resumed.alive and resumed~=actor)
 assert(game:openDeck());game:closeDeck();assert(surfaces:find(id)==resumed,'recovery must remain reusable')
 game:disable();assert(not resumed.alive)
end
local game,_,battlePanel=H.setup({'strike'},{'cultist','jaw_worm'})
local surfaces=assert(Surfaces.get(battlePanel));local state=game.run.combat
local dead=assert(surfaces:find(state.enemies[1].id));local survivor=assert(surfaces:find(state.enemies[2].id))
assert(game:openDeck());state.enemies[1].hp=0;game:refresh()
assert(not dead.alive and surfaces:find(state.enemies[2].id)==survivor,'hidden death must retire only the departed actor')
game.run.phase='defeat';state.player.hp=0;game:refresh()
assert(not survivor.alive,'terminal state must release suspended actors')
game:disable()
print('BATTLE_OVERLAY_SURFACE_SAFETY_PASS input/pause/false/throw/recovery/death/terminal')
