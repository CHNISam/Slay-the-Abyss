local F=dofile('tests/lua/support/game_ui_fixture.lua')
local E=require('abyss_events')
local A=require('abyss_actor')
local host,root=F.fixture()
assert(F.start(host));assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
local battle=F.Combat.new(F.Data,{enemies={'guardian','guardian'},deck={'strike'},seed=42})
local function select(actor,id)
 for i,intent in ipairs(actor.intents)do if intent.id==id then actor.intentIndex=i;return intent end end
 error('missing fixture move')
end
for _,actor in ipairs(battle.enemies)do select(actor,'guardian_3')end
host.run.combat=battle;host:refresh();host:update(.8)
local manager=require('abyss_monster_surfaces').get(root:GetChild('battlePanel'))
local boxes={manager:find(battle.enemies[1].id),manager:find(battle.enemies[2].id)}
-- Ignore trailing helper returns from the second expression.
boxes[3],boxes[4]=nil,nil
local function shown(index)return boxes[index]:GetChild('intent').text end
local alpha=boxes[1]:GetChild('intentIcon').imageColor.a
assert(shown(1)=='5x4' and shown(2)=='5x4','initial source Whirlwind must be5x4')
for _,actor in ipairs(battle.enemies)do select(actor,'guardian_2')end
host.battleUI:render();host:update(0)
assert(shown(1)=='5x4' and shown(2)=='5x4','selected next single attack cannot itself alter displayed source intent')
local function playMutation(mutate)
 local before,first=E.frame(battle),#battle.events+1
 mutate()
 local owner=host.battleUI
 owner.busy,owner.feedbackRun,owner.feedbackBattle=true,host.run,battle
 owner.feedbackLast=#battle.events
 owner.feedback:begin(before,battle,first,host.presentation,nil)
 return battle.events[first]
end
local marker=playMutation(function()A.applyPower(battle,battle.enemies[1],'strength',1,battle.enemies[1])end)
assert(marker.sourceIntentPowers and marker.sourceIntentPowers.scope=='all-monsters','actual ApplyPower producer must supply global source callback')
assert(shown(1)=='33x4' and shown(2)=='32x4','global applyPowers uses each CURRENT selected base but OLD displayed multiplier4')
assert(boxes[1]:GetChild('intentIcon').imageColor.a==alpha,'power refresh must not createIntent/reset alpha')
for _=1,100 do if not host.battleUI.busy then break end;host:update(.01)end
assert(not host.battleUI.busy)
local raw=playMutation(function()A.status(battle,battle.enemies[1],'strength',1,battle.enemies[1])end)
assert(not raw.sourceIntentPowers,'raw status mutation is not a source callback')
assert(shown(1)=='33x4' and shown(2)=='32x4','raw status/render cannot silently recalculate displayed damage')
for _=1,100 do if not host.battleUI.busy then break end;host:update(.01)end
assert(shown(1)=='33x4','tick must not recompute from changed power hashes')
playMutation(function()A.applyPower(battle,battle.enemies[1],'strength',0,battle.enemies[1])end)
assert(shown(1)=='34x4' and shown(2)=='32x4','accepted zero stack is still a real source applyPowers boundary')
host:disable();print('INDEPENDENT_REAL_GUARDIAN_HYBRID_PASS')
