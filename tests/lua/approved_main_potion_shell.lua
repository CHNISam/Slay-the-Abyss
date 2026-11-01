local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme=require('abyss_theme')
local host,ui,panel,event,tap,drain=H.setup({'defend'},{'cultist','jaw_worm'})
local group=panel:GetChild('potionHelp')
local popup=group:GetChild('potionPopup')
local function action(name,touch)
 local part=popup:GetChild(name)
 for _,kind in ipairs({'down','up','click'})do if part.listeners[kind]then part.listeners[kind]({touchId=touch})end end
end
local function sameColour(actual,expected,label)
 for _,key in ipairs({'r','g','b','a'})do assert(actual[key]==expected[key],label..' '..key)end
end
local function shell(slot,kind,selected)
 local box=slot<=3 and panel:GetChild('potion'..slot) or group:GetChild('potion'..slot)
 for _,state in ipairs({'normal','hover','pressed','disabled'})do
  local face=box:GetChild(state)
  local empty=assert(face:GetChild('emptyShell'),'Main must expose a real empty shell, not the old solid plate')
  local ordinary=assert(face:GetChild('filledShell'))
  local fire=assert(face:GetChild('fireShell'))
  local glow=assert(face:GetChild('selectedShell'))
  assert(empty.visible==(kind=='empty'),'empty shell ownership '..slot..'/'..state)
  assert(ordinary.visible==(kind=='normal'),'ordinary shell ownership '..slot..'/'..state)
  assert(fire.visible==(kind=='fire'),'fire shell ownership '..slot..'/'..state)
  assert(glow.visible==(selected==true),'selected shell ownership '..slot..'/'..state)
  assert(not face:GetChild('plate').visible and not face:GetChild('border').visible,'legacy solid circle must stay hidden')
  local bottle=face:GetChild('bottle')
  assert(bottle.visible==(kind~='empty'),'empty slots never paint a bottle')
  if kind~='empty'then
   assert(bottle.imageId==Theme.icon.potion[host.run.potions[slot]],'official bottle ID must remain real')
   local tone=kind=='fire' and Theme.color.potionShell.fire or Theme.color.potionShell.normal
   local tint=Theme.icon.potionTint[host.run.potions[slot]]
   sameColour(bottle.imageColor,tint or tone.ink,'configured bottle ink')
  end
  sameColour(ordinary:GetChild('rim').imageColor,selected and Theme.color.potionShell.selected.border or Theme.color.potionShell.normal.border,'ordinary rim')
  sameColour(fire:GetChild('rim').imageColor,selected and Theme.color.potionShell.selected.border or Theme.color.potionShell.fire.border,'fire rim')
 end
end
host.run.potions={[1]='fire_potion',[3]='block_potion'};host:refresh()
shell(1,'fire',false);shell(2,'empty',false);shell(3,'normal',false)
local hp=host.run.combat.enemies[1].hp
tap('potion1',701);assert(ui.potionMenu and not ui.potionAim);shell(1,'fire',true)
action('dismiss',702);assert(not ui.potionMenu);shell(1,'fire',false)
tap('potion1',703);action('use',704)
assert(ui.potionAim and not ui.potionMenu);shell(1,'fire',true)
tap('enemy1',705);drain()
assert(host.run.combat.enemies[1].hp==hp-20 and not host.run.potions[1]);shell(1,'empty',false)
local block=host.run.combat.player.block
tap('potion3',706);shell(3,'normal',true);action('discard',707)
assert(not host.run.potions[3] and host.run.combat.player.block==block);shell(3,'empty',false)
-- A stale menu must be retired before this same render paints the new shell.
host.run.potions[1]='fire_potion';host:refresh();tap('potion1',708)
host.run.potions[1]='block_potion';host:refresh()
assert(not ui.potionMenu and not ui.potionAim);shell(1,'normal',false)
host.run.potions[1]='fire_potion';host:refresh();tap('potion1',709)
assert(H.Run.discardPotion(host.run,1));assert(H.Run.obtainPotion(host.run,'fire_potion'));host:refresh()
assert(not ui.potionMenu);shell(1,'fire',false)
assert(H.Run.obtainRelic(host.run,'Potion Belt'));host.run.potions[5]='block_potion';host:refresh()
assert(group:GetChild('potion5').visible);shell(5,'normal',false)
print('APPROVED_MAIN_POTION_SHELL_PASS empty/normal/fire/menu/aim/dismiss/discard/use/stale/fifth')
