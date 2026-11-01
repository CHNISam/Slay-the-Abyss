-- Current GameUI equivalents of historical cases 35--38. No frozen fixture edits.
local H=dofile('tests/lua/support/current_game_ui_parity_fixture.lua')
local F,Run=H.F,H.Run
local function strike(host,panel,surfaces)
 for i,card in ipairs(host.run.combat.hand)do if card.cardId=='strike' then H.play(host,panel,surfaces,i,1);return end end
 error('missing strike')
end
local function directStrike(host)
 local direct=F.Combat.copy(host.run)
 for _,card in ipairs(direct.combat.hand)do if card.cardId=='strike'then assert(Run.play(direct,card.uid,1));return direct end end
 error('missing direct strike')
end
local function notified(host)
 local refresh=host.refresh;local n=0
 host.refresh=function(self,...)n=n+1;return refresh(self,...)end
 return function()return n end
end
local function idle(host,expected,map)
 for _=1,10 do H.tick(host,expected,.1)end
 H.same(host.run,expected,'idle full run');H.same(host.map,map,'idle full map')
 assert(not host.battleUI.busy and not host.battleUI.feedback.busy)
end
-- Native effect failure is injected once, after a successful core command.
do
 local host,panel,surfaces=H.setup(11,true);local changes=notified(host)
 local direct=directStrike(host);local map=F.Combat.copy(host.map)
 local battle=host.run.combat;local events=battle.events
 strike(host,panel,surfaces);assert(host.battleUI.busy);H.same(host.run,direct,'failure committed')
 local box=assert(surfaces:find(battle.enemies[1].id));local impact=box:GetChild('impact')
 local setter=impact.SetVisible;local failures=0
 impact.SetVisible=function(self,...)
  if failures==0 then failures=1;error('CURRENT_UI_ONESHOT_EFFECT_FAILURE')end
  return setter(self,...)
 end
 H.drain(host,direct);assert(failures==1 and changes()==1,'failure recovery notifies host exactly once')
 H.clear(direct.combat.events);H.same(host.run,direct,'recovered full run')
 assert(events==battle.events and #events==0 and panel:GetChild('endTurn').interactable)
 assert(box:GetChild('hp').text==battle.enemies[1].hp..'/'..battle.enemies[1].maxHp,'final HP restored')
 idle(host,direct,map);assert(changes()==1 and panel.x==0,'idle repeats no host notification')
 assert(Run.endTurn(direct));H.click(panel,'endTurn');H.same(host.run,direct,'next command')
 H.drain(host,direct);H.clear(direct.combat.events);H.same(host.run,direct,'next playback');assert(changes()==2)
 host:disable();print('CURRENT_UI_BOUNDARY effect recovery')
end
-- Busy old-run playback must be cancelled, without completing its host command.
do
 local host,panel,surfaces=H.setup(11,true);local changes=notified(host)
 strike(host,panel,surfaces);assert(host.battleUI.busy)
 local old=host.run;local oldBox=assert(surfaces:find(old.combat.enemies[1].id))
 -- Controlled replacement rebinds both owner pointers, as GameUI.beginRun does.
 host.run=Run.new(F.Data,17);host.battleUI.run=host.run;assert(Run.startCombat(host.run,'cultist_solo'))
 local expected=F.Combat.copy(host.run);local map=F.Combat.copy(host.map)
 host:refresh();assert(changes()==1,'only explicit refresh, no stale completion callback')
 assert(not host.battleUI.busy and panel:GetChild('endTurn').interactable)
 assert(not oldBox.alive,'old native actor must be retired, even when actor IDs repeat')
 local oldFinal=F.Combat.copy(old)
 for _=1,100 do H.tick(host,expected,.1)end
 H.same(host.run,expected,'replacement full run');H.same(host.map,map,'replacement map')
 H.same(old,oldFinal,'old run after cancellation');assert(changes()==1 and not host.battleUI.busy)
 host:disable();print('CURRENT_UI_BOUNDARY busy replacement')
end
-- Presentation preparation occurs before Run.play; native target input must not commit.
-- A throwing sound service on the successful retry must not interrupt completion.
do
 local soundCalls=0
 local host,panel,surfaces=H.setup(11,true,function()soundCalls=soundCalls+1;error('CURRENT_UI_AUDIO_UNAVAILABLE')end)
 local battle=host.run.combat;local slot
 for i,card in ipairs(battle.hand)do if card.cardId=='strike'then slot=i end end
 H.click(panel,'card'..assert(slot));local expected=F.Combat.copy(host.run);local map=F.Combat.copy(host.map)
 local ui=host.battleUI;local render=ui.render
 ui.render=function()error('CURRENT_UI_PREPARE_FAILURE')end
 assert(surfaces:find(battle.enemies[1].id)):GetChild('hit').click()
 assert(not ui.busy);H.same(host.run,expected,'prepare failure no command');H.same(host.map,map,'prepare map')
 ui.render=render;ui:render();local direct=directStrike(host);local beforeAudio=soundCalls
 assert(surfaces:find(battle.enemies[1].id)):GetChild('hit').click();H.same(host.run,direct,'prepare retry committed')
 H.drain(host,direct);H.clear(direct.combat.events);H.same(host.run,direct,'prepare retry playback')
 assert(soundCalls>beforeAudio,'real retry feedback must exercise the unavailable audio service')
 idle(host,direct,map);host:disable();print('CURRENT_UI_BOUNDARY prepare no commit and audio isolation')
end
-- A genuinely retained nonblocking effect must not paint into the next encounter.
do
 local host,panel,surfaces=H.setup(11,true);strike(host,panel,surfaces)
 for _=1,400 do if not host.battleUI.busy then break end;host:update(.01)end
 local ui=host.battleUI;assert(not ui.busy and next(ui.feedback.effects),'requires a real idle effect tail')
 local oldBox=assert(surfaces:find(host.run.combat.enemies[1].id))
 host.run=Run.new(F.Data,19);host.battleUI.run=host.run;assert(Run.startCombat(host.run,'cultist_solo'))
 local expected=F.Combat.copy(host.run);local map=F.Combat.copy(host.map)
 host:refresh();H.tick(host,expected,.02)
 assert(not oldBox.alive and next(ui.feedback.effects)==nil and next(ui.feedback.poses)==nil)
 local box=assert(surfaces:find(host.run.combat.enemies[1].id))
 assert(not box:GetChild('floating').visible and box:GetChild('hpGhost').fillAmount==1 and panel.x==0)
 idle(host,expected,map);host:disable();print('CURRENT_UI_BOUNDARY idle encounter isolation')
end
print('CURRENT_GAME_UI_FAILURE_BOUNDARIES_PASS')
