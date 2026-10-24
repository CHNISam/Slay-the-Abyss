local F=dofile('tests/lua/support/game_ui_fixture.lua')
package.preload.abyss_w75_policy=function()return dofile('scripts/warrior75-autoplay-policy.lua')end
local Driver=dofile('scripts/warrior75-native-autoplay.lua')
local Run=require('abyss_run')
local ui=F.fixture();assert(ui:start());assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
local s=ui.run.combat
-- Explicit local fixture tests command routing, not a normal-run claim.
s.hand={{uid=101,cardId='burning_pact'},{uid=102,cardId='wound'},{uid=103,cardId='strike'}}
s.draw={};s.discard={};s.exhaust={};s.nextUid=104
assert(Run.play(ui.run,101));ui:refresh()
for _=1,500 do ui:update(.05);if not ui.battleUI.busy then break end end
assert(s.pendingChoice and ui.deckUI.visible)
Driver.update(ui,.7)
assert(not s.pendingChoice and s.exhaust[1].uid==102,'driver must select through the public modal command')
print('ok autoplay commands - pending choice is resolved through BattleUI, while modal is open')
local other=F.fixture();assert(other:start())
local r=other.run;local deckSize=#r.deck;local gold=r.gold
r.phase='reward';r.rewards={gold=14,goldClaimed=false,manualContinue=true,cardResolved=false,cards={'flex'}}
other:refresh()
Driver.update(other,.7);assert(r.gold==gold+14 and r.phase=='reward')
Driver.update(other,.7);assert(r.phase=='map' and not r.pendingCombatRewards.rewards.cardResolved and #r.deck==deckSize)
print('ok autoplay commands - claims gold once and Proceed retains an unclaimed card row')
