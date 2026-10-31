local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='endDrag'}
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function emit(hit,event,id)return assert(hit.listeners[event])({touchId=id})end
local function tap(hit,id)emit(hit,'down',id);emit(hit,'up',id);return emit(hit,'click',id)end
for _,mode in ipairs({'map','battle'})do
 local host,root=F.fixture(nil,nil,nil,cursor);assert(F.start(host))
 if mode=='battle'then assert(require('abyss_run').startCombat(host.run,'cultist_solo'));host:refresh()end
 assert(host.mode==mode)
 local panel=root:GetChild(mode=='battle' and 'battlePanel' or 'mapPanel')
 local hp=panel:GetChild('resourceHints'):GetChild('hp'):GetChild('hit')
 local gold=panel:GetChild('resourceHints'):GetChild('gold'):GetChild('hit')
 local deck=root:GetChild('deckPanel');local outside=deck:GetChild('blocker')
 local before=F.Combat.copy(host.run)
 emit(outside,'down',1)
 assert(tap(hp,2) and host.deckUI.visible)
 local player=mode=='battle' and host.run.combat.player or host.run
 assert(deck:GetChild('details').text:find(tostring(player.hp)..'/'..tostring(player.maxHp),1,true))
 emit(outside,'up',1);assert(emit(outside,'click',1) and host.deckUI.visible,'old outside press closed new hint')
 if mode=='battle'then host.battleUI:playSlot(1);host.battleUI:endTurn()
 else assert(not host.mapUI:choose(F.Nodes.available(host.run,host.map)[1].id))end
 assert(same(before,host.run),'hint allowed a background command')
 assert(tap(outside,3) and not host.deckUI.visible,'fresh outside tap did not close hint')
 emit(hp,'down',4)
 assert(tap(gold,5))
 assert(deck:GetChild('details').text:find(tostring(host.run.gold),1,true) and deck:GetChild('details').text:find('商店',1,true))
 assert(tap(outside,6) and not host.deckUI.visible)
 emit(hp,'up',4);assert(not emit(hp,'click',4) and not host.deckUI.visible,'old resource tap reopened hint')
 assert(host:openMenu());assert(not tap(gold,7) and not host.deckUI.visible,'resource hint bypassed menu')
 assert(root:GetChild('runMenu'):GetChild('blocker').listeners.click({touchId=8}))
 assert(not host.exitOpen and same(before,host.run),'outside menu dismissal mutated run')
 assert(tap(gold,9) and host:closeDeck())
 assert(host:openDeck());assert(deck:GetChild('blocker').listeners.click({touchId=10}) and host.deckUI.visible,'normal deck acquired outside dismissal')
 assert(host:closeDeck() and same(before,host.run))
 if mode=='map'then
  emit(hp,'down',11);assert(host:openPotions())
  emit(hp,'up',11);assert(not emit(hp,'click',11) and not host.deckUI.visible,'old tap crossed potion modal')
  assert(not tap(gold,12) and not host.deckUI.visible and host.potionUI.visible,'fresh tap crossed potion modal')
  assert(host:closePotions());assert(tap(gold,13) and host:closeDeck(),'resource did not resume after potion modal')
  emit(hp,'down',14);assert(host:openPotions() and host:closePotions())
  emit(hp,'up',14);assert(not emit(hp,'click',14) and not host.deckUI.visible,'old resource tap revived after potion close')
  assert(tap(hp,15) and host:closeDeck())
 end
end
local host,root=F.fixture()
assert(host:openMenu() and not root:GetChild('runMenu'):GetChild('map').visible)
assert(root:GetChild('runMenu'):GetChild('catch').listeners.click() and host.exitOpen)
assert(root:GetChild('runMenu'):GetChild('blocker').listeners.click() and not host.exitOpen)
local focus
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
 modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
host,root=F.fixture(nil,nil,nil,nil,false,nil,nil,api);assert(F.start(host))
host:update(.01);host:syncController()
local gold=root:GetChild('mapPanel'):GetChild('resourceHints'):GetChild('gold'):GetChild('hit')
assert(gold.canControllerFocus,'resource hint missing controller focus');focus=gold
gold.navigationListeners.confirm();assert(host.deckUI.visible)
host:update(.01);host:syncController()
local close=root:GetChild('deckPanel'):GetChild('close'):GetChild('hit');focus=close
close.navigationListeners.cancel();assert(not host.deckUI.visible,'controller return did not dismiss resource hint')
gold.click();assert(not host.deckUI.visible,'controller pointer echo reopened resource hint')
print('RESOURCE_HINTS_PASS map battle read-only values fresh input modal outside')
