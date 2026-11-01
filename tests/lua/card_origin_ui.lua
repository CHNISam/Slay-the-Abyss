local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Origin=require('abyss_card_origin')
local h,r=F.fixture();assert(F.start(h))
local card=h.run.deck[1];local before=Origin.state(card);card.upgraded=true;card.upgrades=1
Origin.record(h.run,card,before,'permanent_upgrade',{kind='relic',relicId='whetstone'})
local function same(a,b)
 if type(a)~='table' or type(b)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local original=F.Combat.copy(h.run)
assert(h:openDeck());h:update(0)
local p=r:GetChild('deckPanel');local grid=p:GetChild('grid')
assert(grid.items[0]:GetChild('hit').click())
local text=p:GetChild('details').text
assert(text:find('永久升级',1,true) and text:find('磨刀石',1,true),'real deck detail must expose source')
assert(text:find('打击标签',1,true),'ordinary strike keyword remains discoverable')
assert(h.deckUI:back());assert(h:closeDeck());assert(same(original,h.run),'origin detail mutated Run')
assert(h:openRelics());assert(h:closeDeck());assert(same(original,h.run),'inventory inspection mutated Run')
print('CARD_ORIGIN_UI_PASS')
