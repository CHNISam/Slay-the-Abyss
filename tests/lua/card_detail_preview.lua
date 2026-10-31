local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 3
local registered=0
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Combat=F.Combat
local function same(a,b)
 if type(a)~='table' or type(b)~='table' then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local passed=0
local function test(name,fn)
 registered=registered+1
 if registered<sliceFirst or registered>sliceLast then return end
 fn();passed=passed+1;print('PASS '..name)
 print('CARD_DETAIL_PREVIEW_CASE '..registered)
end
local function setup(cards)
 local host,root=F.fixture();assert(F.start(host));host.run.deck=cards
 assert(host:openDeck());host:update(0)
 local panel=root:GetChild('deckPanel')
 return host,panel,panel:GetChild('grid')
end
local function toggle(panel)return panel:GetChild('upgradePreview'):GetChild('hit').click()end

test('ordinary real hit opens current details and preview is reversible without any run mutation',function()
 local host,panel,grid=setup({{uid=101,cardId='bash',upgraded=false}})
 local before=Combat.copy(host.run)
 local hit=grid.items[0]:GetChild('hit')
 assert(hit.visible,'ordinary card detail hit must be visible')
 assert(hit.click());assert(panel:GetChild('details').visible and not grid.visible)
 local current=panel:GetChild('details').text
 assert(current:find('8',1,true),'current Bash damage')
 assert(toggle(panel));local upgraded=panel:GetChild('details').text
 assert(upgraded:find('10',1,true) and upgraded~=current,'upgraded Bash damage')
 assert(toggle(panel));assert(panel:GetChild('details').text==current)
 assert(toggle(panel));assert(panel:GetChild('details').text==upgraded)
 assert(same(before,host.run),'details/preview changed complete Run')
 assert(host.deckUI:back());assert(grid.visible)
 assert(host:closeDeck());assert(same(before,host.run))
end)

test('already upgraded and unupgradeable cards remain current, never downgrade',function()
 for _,card in ipairs({{uid=1,cardId='bash',upgraded=true},{uid=2,cardId='burn',upgraded=false}})do
  local host,panel,grid=setup({card});local before=Combat.copy(host.run)
  assert(grid.items[0]:GetChild('hit').click())
  assert(not panel:GetChild('upgradePreview').visible)
  local text=panel:GetChild('details').text
  assert(not toggle(panel));assert(panel:GetChild('details').text==text)
  assert(same(before,host.run));host:closeDeck()
 end
end)

test('repeatable Searing Blow previews exactly one additional upgrade each time',function()
 local host,panel,grid=setup({{uid=11,cardId='searing_blow',upgraded=true,upgrades=2}})
 local before=Combat.copy(host.run)
 assert(grid.items[0]:GetChild('hit').click());local current=panel:GetChild('details').text
 assert(current:find('21',1,true));assert(panel:GetChild('title').text:find('+2',1,true))
 for _=1,3 do
  assert(toggle(panel));assert(panel:GetChild('details').text:find('27',1,true))
  assert(panel:GetChild('title').text:find('+3',1,true))
  assert(toggle(panel));assert(panel:GetChild('details').text==current)
 end
 assert(same(before,host.run));host:closeDeck()
end)
test('combat detail preserves temporary cost and complete battle while previewing',function()
 local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
 local host,_,_,_,_,_,_,root=H.setup()
 host.run.combat.player.statuses.strength=3
 host.run.combat.discard={{uid=301,cardId='bash',upgraded=false,costForTurn=0,damageBonus=7}}
 local before=Combat.copy(host.run)
 assert(host.deckUI:openPile(host.run,'discard'));host.deckUI:update(0)
 local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
 assert(grid.items[0]:GetChild('hit').click())
 assert(panel:GetChild('details').text:find('费用 0',1,true))
 assert(panel:GetChild('details').text:find('18',1,true),'current damage bonus and strength retained')
 assert(toggle(panel));assert(panel:GetChild('details').text:find('费用 0',1,true))
 assert(panel:GetChild('details').text:find('20',1,true),'upgraded damage bonus and strength retained')
 assert(toggle(panel));assert(same(before,host.run),'combat preview modified real cost/piles/RNG')
 host.deckUI:close();assert(same(before,host.run))
end)

test('return retains filters sort and scroll, stale and destroyed callbacks cannot reopen details',function()
 local cards={};for i=1,20 do cards[i]={uid=i,cardId=i%2==0 and 'bash' or 'defend',upgraded=false}end
 local host,panel,grid=setup(cards)
 assert(host.deckUI:setFilter('attack'));assert(host.deckUI:nextSort());host:update(0)
 grid.scrollProgress=.6
 local first=grid.items[0];local oldClick=first:GetChild('hit').click
 local oldRefresh=grid.refreshCallback
 assert(oldClick());assert(not oldClick(),'stale card cannot replace active detail')
 assert(toggle(panel));assert(host.deckUI:back());host:update(0)
 assert(host.deckUI.typeFilter=='attack' and host.deckUI.sortMode=='name')
 assert(grid.scrollProgress==.6,'detail return lost scroll position')
 local before=Combat.copy(host.run)
 grid.destroyOnRefresh=true;grid:RefreshItems(grid.itemCount,grid.refreshCallback)
 assert(first.alive==false);assert(not oldClick())
 assert(host:closeDeck());assert(not toggle(panel))
 oldRefresh(first,0);assert(not oldClick())
 assert(host:openDeck());host:update(0)
 assert(not panel:GetChild('upgradePreview').visible and not host.deckUI.cardDetail)
 assert(same(before,host.run));host:closeDeck()
end)

test('text-only and V4 inspection keep descriptions and reset preview state',function()
 local host,panel,grid=setup({{uid=1,cardId='bash',upgraded=false}})
 assert(grid.items[0]:GetChild('hit').click());assert(toggle(panel))
 assert(host.deckUI:showText('规则','测试正文'))
 assert(not toggle(panel));assert(not panel:GetChild('upgradePreview').visible)
 assert(host:closeDeck())
 local original=require('abyss_original_v4_display')
 local raw=assert(require('abyss_original_v4_data').cards[1])
 local definition={name=raw.name,originalV4=raw}
 do
  assert(host.deckUI:inspect(host.run,definition,false))
  assert(host.deckUI.detailTitle==definition.name)
  local text=original.describe(definition,false)
  assert(#text>0 and #host.deckUI.detailPages>0)
  assert(not panel:GetChild('upgradePreview').visible);host:closeDeck()
 end
end)

test('controller details hide paging immediately and return to the same controller page',function()
 local focus
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
  modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(v)focus=v end,isController=function()return true end}
 local host,root=F.fixture(nil,nil,nil,nil,false,nil,nil,api);assert(F.start(host))
 host.run.deck={};for i=1,24 do host.run.deck[i]={uid=i,cardId='bash',upgraded=false}end
 assert(host:openDeck());host:update(0);assert(host.deckUI:controllerStep(1));host:update(0)
 local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
 assert(host.deckUI.controllerPage==2 and panel:GetChild('pageHint').visible)
 local function confirm(hit)
  host:syncController();focus=hit;assert(hit.navigationListeners.confirm())
 end
 confirm(grid.items[0]:GetChild('hit'))
 for _,name in ipairs({'previous','next','pageHint'})do assert(not panel:GetChild(name).visible,'detail must hide paging immediately: '..name)end
 host:update(.01)
 local hit=panel:GetChild('upgradePreview'):GetChild('hit');confirm(hit)
 assert(host.deckUI.cardDetail.preview)
 assert(not hit.click(),'same-frame pointer click must not double-toggle')
 assert(host.deckUI.cardDetail.preview)
 host:update(.01);assert(hit.click());assert(not host.deckUI.cardDetail.preview)
 assert(host.deckUI:back());host:update(0)
 assert(host.deckUI.controllerPage==2 and host.deckUI.bindings[grid.items[0]].uid==13)
 host:closeDeck()
end)
test('Searing Blow count-only constructor copies retain their real baseline',function()
 local host,panel,grid=setup({{uid=61,cardId='searing_blow',upgraded=false,upgrades=2,searingBlowCopyUpgrades=2}})
 local before=Combat.copy(host.run);assert(grid.items[0]:GetChild('hit').click())
 assert(panel:GetChild('details').text:find('12',1,true))
 for _=1,2 do
  assert(toggle(panel));assert(panel:GetChild('details').text:find('18',1,true))
  assert(toggle(panel));assert(panel:GetChild('details').text:find('12',1,true))
 end
 assert(same(before,host.run));host:closeDeck()
end)
test('X and unplayable costs remain explicit and readonly',function()
for _,id in ipairs({'whirlwind','burn'})do
 local host,root=F.fixture();assert(F.start(host));host.run.deck={{uid=41,cardId=id,upgraded=false}}
 local before=F.Combat.copy(host.run);assert(host:openDeck());host:update(0)
 local panel=root:GetChild('deckPanel');assert(panel:GetChild('grid').items[0]:GetChild('hit').click())
 assert(panel:GetChild('details').text:find(id=='whirlwind' and '费用 X' or '费用 不可打出',1,true))
 assert(same(before,host.run));host:closeDeck()
end
end)
test('forced selection retains UID callback rather than opening details',function()
 local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
 local host,_,_,_,_,_,_,root=H.setup();local battle=host.run.combat
 battle.hand={{uid=301,cardId='bash',upgraded=false}};battle.pendingChoice={token='review',op='upgradeHand',uids={301}}
 local picked;assert(host.deckUI:open(host.run,battle.pendingChoice,function(token,uid)picked={token,uid}end));host.deckUI:update(0)
 local panel=root:GetChild('deckPanel');assert(not host.deckUI:showCardDetails(battle.hand[1]));assert(not host.deckUI:toggleUpgradePreview())
 assert(not panel:GetChild('close').visible)
 panel:GetChild('grid').items[0]:GetChild('hit').click();assert(picked[1]=='review' and picked[2]==301)
 assert(not host.deckUI.visible and not host.deckUI.cardDetail)
end)
test('a new Run never inherits a previous upgrade preview',function()
 local host,root=F.fixture();assert(F.start(host));host.run.deck={{uid=1,cardId='bash',upgraded=false}}
 assert(host:openDeck());host:update(0);local panel=root:GetChild('deckPanel');local old=panel:GetChild('grid').items[0]:GetChild('hit').click
 assert(old());assert(host.deckUI:toggleUpgradePreview());assert(host:closeDeck())
 local newer=F.Combat.copy(host.run);newer.deck={{uid=91,cardId='defend',upgraded=true}};host.run=newer
 assert(host:openDeck());host:update(0)
 assert(not host.deckUI.cardDetail);assert(panel:GetChild('grid').items[0]:GetChild('hit').click())
 assert(panel:GetChild('title').text:find('防御',1,true));assert(not panel:GetChild('upgradePreview').visible)
 assert(not host.deckUI:toggleUpgradePreview());host:closeDeck()
end)
print('CARD_DETAIL_PREVIEW_PASS '..passed)
assert(registered==11,'all original card detail groups must register')
assert(passed==sliceLast-sliceFirst+1,'every selected card detail group must execute')
