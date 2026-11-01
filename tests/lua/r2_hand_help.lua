local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local h,u,p,event=H.setup({'defend','shrug_it_off'},{'cultist'})
local battle=h.run.combat
local function slot(id)
 for i,c in ipairs(battle.hand)do if c.cardId==id then return i,c end end
 error('missing fixture card '..id)
end
local function read(id,expected)
 local i,c=slot(id);local name='card'..i
 local energy,hp,count=battle.energy,battle.player.hp,#battle.hand
 event(name,'down',17);h:update(0.36)
 assert(p:GetChild('statusInfo').visible,'ordinary '..id..' hold must open full-effect details')
 assert(u.info and u.info.uid==c.uid,'detail must retain the held instance identity')
 assert(p:GetChild('statusInfo'):GetChild('text1').text:find(expected,1,true),'detail must include the card effect')
 event(name,'up',17);event(name,'click',17);h:update(0.4)
 assert(battle.energy==energy and battle.player.hp==hp and #battle.hand==count,'reading must not play a card')
 assert(u.selected==nil,'help release must not leave a selected card')
 p:GetChild('statusInfo'):GetChild('hit').click({touchId=21})
end
read('defend','5')
read('shrug_it_off','抽')
-- A long no-keyword card must expose every chunk through real page callbacks.
local text=string.rep('获得格挡并抽牌。',40)..'完整效果终点'
u.presentation.shrug_it_off.combatText=nil
u.presentation.shrug_it_off.text=text..'<color=#FF0000>末尾</color>'
local longSlot=slot('shrug_it_off');local longName='card'..longSlot
event(longName,'down',19);h:update(0.36)
local info=p:GetChild('statusInfo')
assert(u.info and u.info.pages>1,'long body must paginate')
event(longName,'up',19);info:GetChild('page').click({touchId=19})
assert(u.info.page==1,'the opening hold release must not skip the first detail page')
assert(info:GetChild('page').visible,'held details must permit reading later pages after release')
local seen=''
local pages=u.info.pages
for page=1,pages do
 for row=1,require('abyss_theme').layout.statusInfo.rows do
  local line=info:GetChild('text'..row)
  if line.visible then seen=seen..line.text end
 end
 if page<pages then info:GetChild('page').click({touchId=20})end
end
assert(seen==text..'末尾','all long effects must remain reachable without truncation or split markup')
info:GetChild('hit').click({touchId=21})
-- When the engine omits the opening Click, a new physical page Down is fresh.
for _,id in ipairs({30,false})do
 local touch=id or nil
 event(longName,'down',touch);h:update(0.36);event(longName,'up',touch)
 assert(u.info and u.info.page==1)
 local page=info:GetChild('page')
 assert(page.listeners.down,'page must recognize a fresh physical Down')
 page.listeners.down({touchId=touch});page.click({touchId=touch})
 assert(u.info.page==2,'one fresh page tap must work even with the same or anonymous touch')
 info:GetChild('hit').click({touchId=31})
end
local i=slot('defend');local name='card'..i
event(name,'down',18)
table.remove(battle.hand,i);u:render();h:update(0.4)
assert(not p:GetChild('statusInfo').visible,'departed UID must not open late help')
event(name,'up',18);event(name,'click',18)
assert(#battle.hand==1,'stale release must not consume the replacement card')
-- Context changes after Down must keep the new generic reader closed.
local remaining='card1'
event(remaining,'down',22);battle.turn=battle.turn+1;h:update(0.4)
assert(not p:GetChild('statusInfo').visible,'a prior-turn hold must not open help')
event(remaining,'up',22);event(remaining,'click',22)
event(remaining,'down',23);u.active=false;h:update(0.4)
assert(not p:GetChild('statusInfo').visible,'inactive owner must reject delayed help')
assert(#battle.hand==1 and battle.energy==3,'invalidated help must not mutate combat')
print('R2_HAND_HELP_PASS')
