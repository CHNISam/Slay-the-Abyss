local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=require('abyss_theme')
local host,ui,panel=H.setup({'anger','whirlwind','defend'},{'cultist'})
local battle=host.run.combat
local slots={}
for slot,card in ipairs(battle.hand)do slots[card.cardId]=slot end
local function face(id)return panel:GetChild('card'..slots[id])end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function visual(id,blocked,reason)
 local box=face(id)
 assert(box:GetChild('blockedVeil').visible==blocked,id..' temporary input lock became a rule prohibition')
 if reason then assert(box:GetChild('blockedReason').text==reason,id..' lost actual core refusal')end
end
battle.energy=0;ui:render()
assert(H.F.Combat.canPlay(battle,battle.hand[slots.anger].uid,1))
assert(H.F.Combat.canPlay(battle,battle.hand[slots.whirlwind].uid,1))
visual('anger',false);visual('whirlwind',false);visual('defend',true,'能量不足')
local before=H.F.Combat.copy(host.run)
ui.busy=true;ui.feedbackRun=host.run;ui.feedbackBattle=battle
ui:render()
assert(ui.busy,'fixture must retain the real busy gate')
visual('anger',false);visual('whirlwind',false);visual('defend',true,'能量不足')
local cost=face('defend'):GetChild('cost').fontColor
assert(cost.r==Theme.cardSkin.costTone.up.r and cost.g==Theme.cardSkin.costTone.up.g,'real energy refusal must remain red')
ui:playSlot(slots.anger);assert(ui.selected==nil,'busy cannot select a card')
ui.selected=battle.hand[slots.anger].uid;ui:playSelected(1);ui.selected=nil
assert(same(host.run,before),'busy command or visual changed the run')
ui.busy=false;ui.active=false;ui:render()
visual('anger',false);visual('whirlwind',false);visual('defend',true,'能量不足')
ui:playSlot(slots.anger);assert(ui.selected==nil,'overlay cannot select a card')
assert(same(host.run,before),'overlay visual or input changed the run')
ui.active=true;battle.phase='enemy';ui:render()
visual('anger',true,'本回合不能打出');visual('whirlwind',true,'本回合不能打出')
battle.phase='player';ui:render()
visual('anger',false);visual('whirlwind',false);visual('defend',true,'能量不足')
assert(same(host.run,before),'turn visual refresh changed the run')
ui:playSlot(slots.anger);assert(ui.selected==battle.hand[slots.anger].uid,'fresh unlocked selection must recover')
-- Exercise the real command/feedback pipeline, rather than only a held busy flag.
local actual,playback,view=H.setup({'defend','anger','whirlwind'},{'cultist'})
local committed=actual.run.combat
committed.energy=1;playback:render()
local defend
for slot,card in ipairs(committed.hand)do if card.cardId=='defend'then defend=slot end end
playback:playSlot(defend);playback:playSelected()
assert(playback.busy and committed.energy==0,'real defend command must enter busy playback after spending one energy')
local saw=false
for _=1,300 do
 playback:update(.01)
 local frame=playback.displayBattle
 if playback.busy and frame and frame.phase=='player' and frame.energy==0 then
  for slot,card in ipairs(frame.hand)do
   if card.cardId=='anger' or card.cardId=='whirlwind'then
    assert(not view:GetChild('card'..slot):GetChild('blockedVeil').visible,'real feedback invented an unplayable zero/X card')
    saw=true
   end
  end
 end
 if not playback.busy then break end
end
assert(saw and not playback.busy,'real command must publish a busy zero-energy frame and unlock')
print('CARD_BUSY_VISUAL_PASS zero/X/cost/busy/overlay/turn/read-only')
