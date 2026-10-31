local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local unchanged=dofile('tests/lua/support/victory_relic_counters.lua').unchanged
local M={}
local function battle(ids)
 local r=Run.new(D,'42')
 for _,id in ipairs(ids or {})do assert(Run.obtainRelic(r,id))end
 r.hp=20 -- explicit low-health initial condition, no damage/value/RNG override
 local ok,slot=Run.obtainPotion(r,'smoke_bomb');assert(ok)
 assert(Run.startCombat(r,'cultist_solo'));return r,slot
end
local function escape(r,slot,hp,maximum)
 local gold,wins=r.gold,r.victories
 assert(Run.usePotion(r,slot));assert(r.phase=='map' and r.lastResult.outcome=='escaped')
 assert(r.hp==hp and r.maxHp==maximum,'source Smoke victory healing: '..r.hp..'/'..r.maxHp..' ~= '..hp..'/'..maximum)
 assert(not r.combat or r.combat.player.hp==hp and r.combat.player.maxHp==maximum,'retained Smoke combat actor health must match final Run')
 assert(r.gold==gold and r.victories==wins and not r.rewards and not r.potions[slot],'Smoke resource/reward contract')
 local stable=unchanged(r);assert(not Run.usePotion(r,slot));assert(not Run.finishCombat(r));stable()
end
function M.matrix()
 for _,e in ipairs({
  {{},26,80},{{'black_blood'},32,80},{{'meat_on_the_bone'},38,80},{{'face_of_cleric'},27,81},
  {{'meat_on_the_bone','magic_flower'},47,80},{{'meat_on_the_bone','mark_of_bloom'},20,80},
 })do local r,slot=battle(e[1]);escape(r,slot,e[2],e[3])end
 print('SMOKE_VICTORY_HEALING_MATRIX_PASS 6')
end
function M.eventAndOrder()
 local F=dofile('tests/lua/support/event_combat_route_fixture.lua')
 local r=F.event('42','colosseum')
 assert(Run.obtainRelic(r,'meat_on_the_bone'));assert(Run.obtainRelic(r,'face_of_cleric'))
 assert(Run.eventDamage(r,r.hp-20));local ok,slot=Run.obtainPotion(r,'smoke_bomb');assert(ok)
 assert(F.N.chooseEvent(r,'continue'));assert(F.N.chooseEvent(r,'fight'))
 local heals={};local raw=Run.heal
 Run.heal=function(owner,value)heals[#heals+1]={value,owner.hp};return raw(owner,value)end
 local gold,wins=r.gold,r.victories
 assert(Run.usePotion(r,slot));Run.heal=raw
 assert(r.phase=='node' and r.nodeFlow.event.stage=='post_combat','actual event escape continuation')
 assert(r.hp==39 and r.maxHp==81,'event Smoke must not double heal')
 assert(#heals==3 and heals[1][1]==12 and heals[1][2]==20 and heals[2][1]==6 and heals[2][2]==32 and heals[3][1]==1 and heals[3][2]==38,'Meat then held Burning/Cleric exactly once')
 assert(r.gold==gold and r.victories==wins and not r.rewards and not r.eventCombat)
 local stable=unchanged(r);assert(not Run.usePotion(r,slot));stable()
 assert(F.N.chooseEvent(r,'leave'));assert(r.phase=='map')
 print('SMOKE_VICTORY_HEALING_EVENT_PASS')
end
function M.rollback()
 local r,slot=battle({'meat_on_the_bone','face_of_cleric'})
 local stable=unchanged(r);local raw=Run.heal;local reached=false
 Run.heal=function(owner,value)
  local result=raw(owner,value)
  if value==6 then reached=true;assert(owner.hp==38,'failure occurs after two real heals');error('injected late Smoke healing failure')end
  return result
 end
 local ok,why=Run.usePotion(r,slot);Run.heal=raw
 assert(reached and not ok and why=='potion_effect_failed',tostring(why));stable()
 escape(r,slot,39,81)
 print('SMOKE_VICTORY_HEALING_ROLLBACK_PASS')
end
function M.hud()
 local F=dofile('tests/lua/support/game_ui_fixture.lua')
 local h,root=F.fixture();assert(F.start(h));local r=h.run
 assert(Run.obtainRelic(r,'face_of_cleric'));assert(Run.obtainPotion(r,'smoke_bomb'))
 r.hp=20;assert(Run.startCombat(r,'cultist_solo'));h:refresh()
 assert(Run.usePotion(r,1));h:refresh();h:update(0)
 assert(root:GetChild('mapPanel'):GetChild('resources'):GetChild('hp').text=='27/81','actual map HP HUD must show final source health')
 assert(r.combat.player.hp==27 and r.combat.player.maxHp==81,'retained escaped actor health')
 assert(Run.startCombat(r,'cultist_solo'));h:refresh()
 assert(r.hp==27 and r.maxHp==81 and r.combat.player.hp==27 and r.combat.player.maxHp==81,'next public battle uses final source health')
 print('SMOKE_VICTORY_HEALING_HUD_PASS')
end
return M
