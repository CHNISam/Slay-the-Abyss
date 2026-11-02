local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run');local Candidate=require('abyss_run_potion_candidate')
local function setup()
 local h,root=F.fixture();assert(F.start(h));assert(Run.startCombat(h.run,'cultist_solo'))
 for _,id in ipairs({'block_potion','energy_potion','fire_potion'})do assert(Run.obtainPotion(h.run,id))end
 h:refresh();assert(h.battleUI:openPotionMenu(1))
 local panel=root:GetChild('battlePanel');local stage=panel:GetChild('stage')or panel
 return h,h.battleUI,stage,stage:GetChild('potionHelp'):GetChild('potionPopup')
end
local h,u,_,popup=setup()
local prepares=0;local prepare=Candidate.prepare
Candidate.prepare=function(...)prepares=prepares+1;return prepare(...)end
local saved={};local function remember(v)
 if type(v)~='table' or saved[v]then return end
 local copy={};saved[v]=copy;for k,item in pairs(v)do copy[k]=item;remember(k);remember(item)end
end;remember(h.run)
u:render(true)
local renderCount=prepares
for original,copy in pairs(saved)do
 for k,v in pairs(original)do assert(copy[k]==v,'render changed live run/RNG')end
 for k,v in pairs(copy)do assert(original[k]==v,'render removed live run/RNG')end
end
print('POTION_POPUP_SLOT_VIEW three-bottle single render candidatePrepares='..renderCount)
assert(popup:GetChild('use').interactable)
-- Busy frames own only a presentation cache, never a fresh eligibility query.
prepares=0;u.busy=true;u.feedbackRun=h.run;u.feedbackBattle=h.run.combat
u:render(true)
assert(prepares==0 and not popup.visible and not u.potionMenu,'busy reused eligibility must not reopen popup')
u.busy=false;u:render();assert(u:openPotionMenu(1))
-- No refresh before the actual click: actions.item must query the changed model.
h.run.combat.player.block=2147483647
assert(popup:GetChild('use').click()==false,'stale Use consumed a newly invalid potion')
assert(h.run.potions[1]=='block_potion' and not u.busy)
h.run.combat.player.block=0
u:render(true);assert(popup:GetChild('use').interactable)
assert(popup:GetChild('use').click())
for _=1,400 do if not u.busy then break end;h:update(.05)end
assert(not u.busy and not h.run.potions[1] and h.run.combat.player.block==12,'fresh valid Use failed')
Candidate.prepare=prepare
-- A public command may reenter at a native setter between frame preparation
-- and the popup. Positions still submit when unchanged sizes are cached.
-- Same run/battle/inventory/turn/input generations do not suffice.
local h2,u2,stage,p2=setup();local r,b=h2.run,h2.run.combat
b.hand={{uid=101,cardId='burning_pact',upgraded=false},{uid=102,cardId='defend',upgraded=false},{uid=103,cardId='strike',upgraded=false}}
h2:refresh()
local stamp={r,b,r.potions,r.roomGeneration,r.combatGeneration,b.turn,u2.rewardRender,u2.selectionEpoch}
local reward=stage:GetChild('rewardList');local setter=reward.SetAnchoredPosition;local injected=false
reward.SetAnchoredPosition=function(self,...)
 local result=setter(self,...)
 if not injected then
  injected=true;assert(Run.play(r,101,nil))
  assert(h2.run==stamp[1] and r.combat==stamp[2] and r.potions==stamp[3])
  assert(r.roomGeneration==stamp[4] and r.combatGeneration==stamp[5] and b.turn==stamp[6])
  assert(u2.rewardRender==stamp[7] and u2.selectionEpoch==stamp[8])
 end
 return result
end
u2:render(true);reward.SetAnchoredPosition=setter
assert(injected==true,'native reentry injection did not execute')
local fresh=Run.potionView(r)[1]
assert(not fresh.canUse and not p2:GetChild('use').interactable,'popup reused a pre-reentry view')
print('POTION_POPUP_SLOT_VIEW reentrant public command fresh reason='..tostring(fresh.reason))
assert(renderCount==4,'popup simulated unselected inventory slots')
print('POTION_POPUP_SLOT_VIEW_PASS readonly/reentry/changed-state-use/valid-use')
