package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua');local R=require('abyss_run');local C=require('abyss_combat')
local ui,root=F.fixture();ui.seed=30;ui:start();assert(R.startCombat(ui.run,'cultist_solo'))
local s=ui.run.combat
s.hand={{uid=101,cardId='bloodletting',upgraded=false},{uid=102,cardId='infernal_blade',upgraded=false}};s.draw={};s.discard={};s.exhaust={};s.nextUid=103;s.energy=3
ui:refresh()
local function settle()
 for _=1,500 do ui:update(.05);if not ui.battleUI.busy then break end end
 ui:refresh()
end
local function playFirst()
 F.click(root,'battlePanel','card1');F.click(root,'battlePanel','playArea');settle()
end
playFirst();assert(s.player.damagedThisCombat==1)
playFirst();local c=assert(s.hand[1]);assert(c.cardId=='blood_for_blood');assert(C.cardDefinition(s,c).cost==0)
print('GENERATED seed=30 card='..c.cardId..' uid='..c.uid..' damagedThisCombat='..s.player.damagedThisCombat..' temporaryCost='..C.cardDefinition(s,c).cost)
F.click(root,'battlePanel','endTurn');settle();assert(s.turn==2 and s.player.damagedThisCombat==1)
local slot;for i,v in ipairs(s.hand) do if v.uid==c.uid then slot=i end end;assert(slot)
local expected=4-s.player.damagedThisCombat
local shown=root:GetChild('battlePanel'):GetChild('card'..slot):GetChild('cost').text
local actual=C.cardDefinition(s,c).cost;local ok,reason=C.canPlay(s,c.uid,1)
print('REGRESSION expectedCost='..expected..' actualCost='..actual..' uiCost='..shown..' energy='..s.energy..' playable='..tostring(ok)..' reason='..tostring(reason))
assert(actual==expected,'Blood for Blood expected cost '..expected..', actual '..actual)
assert(shown==tostring(expected) and s.energy==3 and ok,'correct-cost card must be playable at three energy')
print('PASS: generated Blood for Blood retains all prior combat HP-loss discounts.')
