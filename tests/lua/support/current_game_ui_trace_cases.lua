-- Replaces the current-runtime coverage of historical case 34, not its body.
local H=dofile('tests/lua/support/current_game_ui_parity_fixture.lua')
local F,Run=H.F,H.Run
return function(seed)
 assert(type(seed)=='number' and seed>=1 and seed<=6 and seed%1==0)
 local total=0
 local host,panel,surfaces=H.setup(seed)
 local direct=F.Combat.copy(host.run);local map=F.Combat.copy(host.map)
 H.detached(host.run,direct);H.detached(host.map,map)
 H.same(host.run,direct,'initial run');H.same(host.map,map,'initial map')
 for step=1,20 do
  if host.run.phase~='combat' then break end
  local battle=host.run.combat;local events=battle.events;local slot
  for i,card in ipairs(battle.hand)do if F.Combat.canPlay(battle,card.uid,1)then slot=i;break end end
  if slot then
   local uid=battle.hand[slot].uid;local _,reason=F.Combat.canPlay(battle,uid,nil)
   local target=reason=='invalid_target' and 1 or nil
   assert(Run.play(direct,uid,target));H.play(host,panel,surfaces,slot,1)
  else assert(Run.endTurn(direct));H.click(panel,'endTurn')end
  assert(host.battleUI.busy,'command must enter real playback')
  -- Compare ALL current fields, including all event frames, source callbacks,
  -- immutable catalogs and every RNG stream. Nothing is normalized or ignored.
  H.same(host.run,direct,'seed'..seed..' command'..step);H.same(host.map,map,'command map')
  H.drain(host,direct)
  H.clear(direct.combat.events) -- only the documented one-shot UI consumption
  assert(battle.events==events and #events==0,'consume once, retain event table identity')
  H.same(host.run,direct,'after playback');H.same(host.map,map,'after playback map')
  for _=1,4 do H.tick(host,direct,.2)end
  assert(battle.events==events and #events==0,'idle must not replay or repopulate events')
  H.same(host.run,direct,'idle');H.same(host.map,map,'idle map')
  total=total+1
 end
 host:disable()
 print('CURRENT_UI_PLAYBACK_SEED '..seed)
 assert(total>0);print('CURRENT_GAME_UI_TRACE_PARITY_PASS seed='..seed..' commands='..total)
end
