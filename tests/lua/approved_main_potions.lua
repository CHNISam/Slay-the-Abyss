local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel,event,tap,drain=H.setup({'defend'},{'cultist','jaw_worm'})
local battle=host.run.combat
host.run.potions={'energy_potion','fire_potion','regen_potion'};host:refresh()
local group=panel:GetChild('potionHelp')
local popup=assert(group:GetChild('potionPopup'))
local function action(name,touch)
 local c=popup:GetChild(name)
 for _,kind in ipairs({'down','up','click'})do if c.listeners and c.listeners[kind]then c.listeners[kind]({touchId=touch})end end
end
local energy=battle.energy
local first=tap('potion1',201)
assert(ui.potionMenu and popup.visible,'first tap opens source effect panel')
assert(battle.energy==energy and host.run.potions[1]=='energy_potion','opening does not use a bottle')
assert(popup:GetChild('title').text=='能量药水')
action('use',201);drain()
assert(battle.energy==energy+2 and not host.run.potions[1] and not ui.potionMenu,'explicit use commits one self potion')
action('use',201);assert(battle.energy==energy+2,'queued use cannot consume another bottle')
local hp=battle.enemies[2].hp
tap('potion2',202);action('use',202)
assert(ui.potionAim and not ui.potionMenu,'target potion enters existing aim only after explicit use')
tap('enemy2',203);drain()
assert(battle.enemies[2].hp==hp-20 and not host.run.potions[2])
local statuses=battle.player.statuses.regen or 0
tap('potion3',204);action('discard',204)
assert(not host.run.potions[3] and (battle.player.statuses.regen or 0)==statuses,'explicit discard never applies effect')
-- A stale release cannot act after a same-slot replacement.
host.run.potions[1]='energy_potion';host:refresh();tap('potion1',205)
local use=popup:GetChild('use')
use.listeners.down({touchId=206})
host.run.potions[1]='regen_potion';host:refresh()
use.listeners.up({touchId=206});use.listeners.click({touchId=206})
assert(host.run.potions[1]=='regen_potion' and battle.energy==energy+2,'slot replacement retires popup action ownership')
-- Original physical fifth slot remains available when the core grants capacity.
assert(H.Run.obtainRelic(host.run,'Potion Belt'));host.run.potions[5]='energy_potion';host:refresh()
local fifth=group:GetChild('potion5');assert(fifth.visible)
for _,kind in ipairs({'down','up','click'})do fifth.listeners[kind]({touchId=207})end
assert(ui.potionMenu and ui.potionMenu.slot==5,'fifth physical slot remains addressable')
action('dismiss',208);assert(not ui.potionMenu and host.run.potions[5]=='energy_potion')
-- Foreign pointers cannot steal A's release/click capability.
for offset,mode in ipairs({'foreignUp','foreignClick','foreignEndDrag','foreignDown'})do
 host.run.potions[1]='energy_potion';host:refresh();tap('potion1',300+offset)
 local a,b=400+offset,500+offset
 local current=host.run.combat
 local before=current.energy
 use.listeners.down({touchId=a})
 if mode=='foreignDown'then use.listeners.down({touchId=b})
 elseif mode=='foreignUp'then use.listeners.up({touchId=b})
 elseif mode=='foreignEndDrag'then use.listeners.endDrag({touchId=b})end
 use.listeners.up({touchId=a})
 if mode=='foreignClick'then use.listeners.click({touchId=b})end
 use.listeners.click({touchId=a});drain()
 assert(current.energy==before+2 and not host.run.potions[1],mode..' cannot cancel matching pointer A')
end
host.run.potions[1]='energy_potion';host:refresh();tap('potion1',601)
local current=host.run.combat
local before=current.energy
use.listeners.down({touchId=602});use.listeners.up({touchId=602});use.listeners.endDrag({touchId=602});use.listeners.click({touchId=602})
assert(current.energy==before and host.run.potions[1]=='energy_potion','matching EndDrag still cancels its token')
action('dismiss',603)
assert(popup.disableCursorEventPassthrough==true,'modal effect card must use native passthrough barrier')
print('APPROVED_MAIN_POTIONS_PASS')
