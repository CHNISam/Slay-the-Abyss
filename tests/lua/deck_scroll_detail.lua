local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function same(a,b)
 if type(a)~='table' or type(b)~='table' then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local h,root=F.fixture(nil,nil,nil,{CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag'})
assert(F.start(h));h.run.deck={}
for i=1,40 do h.run.deck[i]={uid=i,cardId='bash',upgraded=false}end
local before=F.Combat.copy(h.run)
assert(h:openDeck());h:update(0)
local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
local hit=grid.items[0]:GetChild('hit')
local function event(dragging,dx,dy)
 return {touchId=7,dragging=dragging,GetPressUIPos=function()return 500,400 end,
  GetUIPos=function()return 500+dx,400+dy end}
end
-- A native scroller owns the offset; card click handling must not reset or hijack it.
-- These events test our dispatch boundary, not the unavailable official Grid physics.
grid.scrollProgress=.45
assert(not hit.click(event(true,0,100)),'dragging click must not open card detail')
assert(not h.deckUI.detailPages and grid.visible and grid.scrollProgress==.45)
assert(not hit.click(event(false,0,100)),'released drag click must not open card detail')
assert(not h.deckUI.detailPages and grid.scrollProgress==.45)
local threshold=F.Theme.layout.cardDrag.threshold
assert(not hit.click(event(false,threshold,0)),'exact threshold is a drag, not a tap')
assert(not hit.click({dragging=true}),'native dragging flag works without position methods')
assert(hit.listeners.drag==nil and hit.listeners.endDrag==nil,'detail must leave native grid drag routing unclaimed')
assert(hit.click(event(false,threshold-1,0)),'small-motion tap must open detail')
assert(h.deckUI.detailPages and not grid.visible)
assert(h.deckUI:back());h:update(0)
assert(grid.scrollProgress==.45 and same(before,h.run))
assert(h:closeDeck());assert(same(before,h.run))
-- Normal C-mode events without position methods remain supported after reopening.
assert(h:openDeck());h:update(0)
local fresh=grid.items[0]:GetChild('hit')
assert(fresh.click({touchId=8,dragging=false}));assert(h.deckUI:back());h:update(0)
assert(h:closeDeck());assert(not fresh.click(event(false,0,0)))
-- The same scroll protection must not choose a forced-choice UID after dragging.
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,_,_,_,_,_,_,battleRoot=H.setup()
local battle=host.run.combat
battle.hand={{uid=301,cardId='bash',upgraded=false}}
battle.pendingChoice={token='scroll-choice',op='upgradeHand',uids={301}}
local picked
assert(host.deckUI:open(host.run,battle.pendingChoice,function(token,uid)picked={token,uid}end));host.deckUI:update(0)
local choiceHit=battleRoot:GetChild('deckPanel'):GetChild('grid').items[0]:GetChild('hit')
assert(not choiceHit.click(event(true,0,100)));assert(not picked and host.deckUI.visible)
choiceHit.click(event(false,0,0));assert(picked[1]=='scroll-choice' and picked[2]==301)
print('DECK_SCROLL_DETAIL_PASS native-drag click rejection, release displacement, tap, readonly scroll ownership')
