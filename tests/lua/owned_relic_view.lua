local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Theme=require('abyss_theme')
local h,r=F.fixture()
assert(F.start(h))
local run=h.run
run.relics={'anchor','anchor'}
for i=1,40 do run.relics[#run.relics+1]='burning_blood' end
h:refresh()
-- Top-bar art slots: owned-only discs bound to Theme.icon.relic.
local bar=r:GetChild('relicBar')
assert(bar.visible~=false,'relic disc row hidden on map')
for i=1,Theme.layout.relicView.bar.count do
  local slot=bar:GetChild('slot'..i)
  assert(slot.visible==true,'slot '..i..' should show owned relic')
  assert(slot:GetChild('rim') and slot:GetChild('face') and slot:GetChild('icon'),'disc art layers missing')
end
-- Twelve-disc row: 42 relics show eleven icons and a '+31' overflow chip.
assert(Theme.layout.relicView.bar.count==12)
assert(bar:GetChild('tray').visible==false,'legacy grouped tray stays hidden')
assert(r:GetChild('relicEntry').visible==false,'legacy text entry stays hidden')
local last=bar:GetChild('slot'..Theme.layout.relicView.bar.count)
assert(last:GetChild('more').visible==true and last:GetChild('more').text=='+31',last:GetChild('more').text)
assert(last:GetChild('icon').visible==false,'overflow chip must not stack on an icon')
assert(bar:GetChild('slot1'):GetChild('more').visible==false)
local V=require('abyss_relic_view_ui')
local function same(a,b)for i=1,math.max(#a,#b)do if a[i]~=b[i]then return false end end return true end
assert(same(V.barCells(0,3),{false,false,false}))
assert(same(V.barCells(2,3),{true,true,false}))
assert(same(V.barCells(3,3),{true,true,true}))
assert(same(V.barCells(4,3),{true,true,'+2'}))
local function iconOf(id)local v=Theme.icon.relic[id];return type(v)=='table' and v.id or v end
assert(require('abyss_relic_view_ui').icon('anchor')==iconOf('anchor'))
local panel=r:GetChild('relicPanel')
local entry=r:GetChild('relicEntry'):GetChild('open'):GetChild('hit')
assert(bar:GetChild('slot1'):GetChild('hit').click())
assert(h.deckUI.visible and h.deckUI.detailOnly=='relics' and h.relicUI.visible and not h.mapUI.visible)
assert(panel.visible==true and r:GetChild('deckPanel').visible==false,'relic overlay must replace the text dump')
assert(panel:GetChild('title').text=='持有遗物 · 42 件')
local row1=panel:GetChild('row1')
assert(row1.visible==true and row1:GetChild('name').text=='石锚',row1:GetChild('name').text)
assert(row1:GetChild('description').text:find('获得 10 点格挡',1,true))
assert(row1:GetChild('slot'):GetChild('icon'))
assert(h.relicUI.rows[1].icon==iconOf('anchor'))
local perPage=#Theme.layout.relicView.rows*#Theme.layout.relicView.columns
assert(perPage==4,'larger complete descriptions need four entries per page')
local expectedPages=math.ceil(#run.relics/perPage)
assert(expectedPages==11 and h.relicUI:pages()==expectedPages)
assert(panel:GetChild('pageHint').text=='第 1/'..expectedPages..' 页')
assert(panel:GetChild('next'):GetChild('hit').click())
assert(h.relicUI.page==2 and panel:GetChild('row1'):GetChild('name').text=='余烬之心')
assert(panel:GetChild('row1'):GetChild('description').text:find('回复 6 点生命',1,true))
-- No English placeholders anywhere in the visible panel.
for slot=1,perPage do
  local row=panel:GetChild('row'..slot)
  if row.visible then for _,n in ipairs({'name','description'}) do
    assert(not row:GetChild(n).text:find('%a%a%a'),'English text in relic panel: '..row:GetChild(n).text)
  end end
end
assert(panel:GetChild('close'):GetChild('hit').click())
assert(not h.deckUI.visible and not h.relicUI.visible and panel.visible==false and h.mode=='map' and h.run==run)
-- Tapping a disc opens directly on that relic's page.
assert(bar:GetChild('slot2'):GetChild('hit').click())
assert(h.relicUI.visible and h.relicUI.page==1)
assert(entry:GetChild('normal'):GetChild('label').text=='遗物 42')
assert(entry:GetChild('normal'):GetChild('count').text=='42')
assert(panel:GetChild('close'):GetChild('hit').click())
assert(h:openDeck())
assert(not h:openRelics())
do
  local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
  local host,_,_,emit,_,_,_,root=H.setup()
  emit('endTurn','down',7)
  assert(root:GetChild('relicBar'):GetChild('slot1'):GetChild('hit').click())
  assert(host.deckUI.visible and host.relicUI.visible)
  assert(root:GetChild('relicPanel'):GetChild('close'):GetChild('hit').click())
  emit('endTurn','up',7);emit('endTurn','click',7)
  assert(host.run.combat.turn==1,'old action must not survive relic modal')
end
do
  local G=dofile('tests/lua/support/game_ui_fixture.lua')
  local h2,r2=G.fixture();assert(G.start(h2))
  h2.run.relics={'neows_lament','maw_bank','anchor','ancient_tea_set'}
  h2.run.relicCounters={neows_lament=2,maw_bank=-2,ancient_tea_set=-2}
  h2:refresh()
  assert(r2:GetChild('relicBar'):GetChild('slot1'):GetChild('hit').click())
  local p=r2:GetChild('relicPanel')
  local function chip(i)local c=p:GetChild('row'..i):GetChild('chip');return c.visible and c:GetChild('label').text or nil end
  assert(chip(1)=='剩余 2 场',tostring(chip(1)))
  assert(chip(2)=='已失效')
  assert(chip(3)==nil,'anchor has no counter chip')
  assert(chip(4)=='已蓄能','tea set -2 must not read 已耗尽')
end
print('LUA_OWNED_RELIC_VIEW 4 passed')
