local F=dofile('tests/lua/support/game_ui_fixture.lua')
local h,r=F.fixture()
assert(F.start(h))
local run=h.run
run.relics={'anchor','anchor'}
for i=1,40 do run.relics[#run.relics+1]='burning_blood' end
local entry=r:GetChild('relicEntry'):GetChild('open'):GetChild('hit')
assert(entry.click())
assert(h.deckUI.visible and h.deckUI.detailOnly and not h.mapUI.visible)
local text=table.concat(h.deckUI.detailPages,'\n')
assert(text:find('1. 石锚',1,true) and text:find('2. 石锚',1,true) and text:find('42. 余烬之心',1,true))
assert(text:find('获得 10 点格挡',1,true) and text:find('回复 6 点生命',1,true))
local panel=r:GetChild('deckPanel')
assert(#h.deckUI.detailPages>1)
assert(panel:GetChild('detailHit').click())
assert(h.deckUI.detailPage==2)
assert(panel:GetChild('close'):GetChild('hit').click())
assert(not h.deckUI.visible and h.mode=='map' and h.run==run)
assert(entry.click())
assert(h.deckUI.detailPage==1)
assert(panel:GetChild('close'):GetChild('hit').click())
assert(h:openDeck())
assert(not h:openRelics())
do
  local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
  local host,_,_,emit,_,_,_,root=H.setup()
  emit('endTurn','down',7)
  assert(root:GetChild('relicEntry'):GetChild('open'):GetChild('hit').click())
  assert(host.deckUI.visible)
  assert(root:GetChild('deckPanel'):GetChild('close'):GetChild('hit').click())
  emit('endTurn','up',7);emit('endTurn','click',7)
  assert(host.run.combat.turn==1,'old action must not survive relic modal')
end
do
  local G=dofile('tests/lua/support/game_ui_fixture.lua')
  local h2,r2=G.fixture();assert(G.start(h2))
  h2.run.relics={'neows_lament','maw_bank','anchor'}
  h2.run.relicCounters={neows_lament=2,maw_bank=-2}
  assert(r2:GetChild('relicEntry'):GetChild('open'):GetChild('hit').click())
  local t=table.concat(h2.deckUI.detailPages,'\n')
  assert(t:find('〔剩余 2 场〕',1,true),t)
  assert(t:find('〔已失效〕',1,true),t)
  assert(not t:find('石锚　〔',1,true),t)
end
print('LUA_OWNED_RELIC_VIEW 3 passed')
