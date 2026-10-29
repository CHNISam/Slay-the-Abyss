local F=dofile('tests/lua/support/game_ui_fixture.lua')
local focus
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
    modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(value)focus=value end,
    isController=function()return true end}
local h,root=F.fixture(nil,nil,nil,nil,false,nil,nil,api)
assert(F.start(h))
h.run.relics={}
for i=1,42 do h.run.relics[i]='anchor' end
h:refresh()
local open,close=h.openRelics,h.closeDeck
local opens,closes=0,0
h.openRelics=function(self,...)opens=opens+1;return open(self,...)end
h.closeDeck=function(self,...)closes=closes+1;return close(self,...)end
local bar=root:GetChild('relicBar'):GetChild('slot1'):GetChild('hit')
local panel=root:GetChild('relicPanel')
local function confirm(hit)
    h:syncController();api.setFocus(hit)
    assert(hit.navigationListeners.confirm())
end
confirm(bar)
assert(opens==1 and h.relicUI.visible and h.relicUI.page==1)
bar.click();assert(opens==1,'same-frame native Click repeated bar action')
h:update(.01);bar.click();assert(opens==2,'fresh-frame bar Click was blocked')
for _,case in ipairs({{'next',2,3},{'previous',2,1}})do
    local hit=panel:GetChild(case[1]):GetChild('hit')
    confirm(hit);assert(h.relicUI.page==case[2])
    hit.click();assert(h.relicUI.page==case[2],'same-frame Click double-turned '..case[1])
    h:update(.01);assert(hit.click());assert(h.relicUI.page==case[3],'fresh Click lost '..case[1])
end
local closeHit=panel:GetChild('close'):GetChild('hit')
confirm(closeHit)
assert(closes==1 and not h.relicUI.visible and not h.deckUI.visible and h.mode=='map')
closeHit.click();assert(closes==1,'same-frame close action repeated')
h:update(.01);assert(bar.click());assert(h.relicUI.visible and opens==3)
assert(closeHit.click());assert(closes==2 and not h.deckUI.visible and not h.relicUI.visible)
print('RELIC_CONTROLLER_CLICK_PASS next previous close bar; same-frame blocked, next-frame live')
