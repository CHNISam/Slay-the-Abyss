local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel,event=H.setup({'defend','defend','defend'})
local function snap(label)
 local b=host.run.combat
 local values={label,host.mode,tostring(ui.active),host.run.phase,b.phase,b.turn,b.energy,b.player.hp,#b.events,#b.hand}
 for i=1,#b.hand do
  local box=panel:GetChild('card'..i);local hit=box:GetChild('hit')
  values[#values+1]=table.concat({b.hand[i].uid,box.x,box.y,box.scale[1],box.localRotationZ,hit.x,hit.y,hit.sizeDeltaX,hit.sizeDeltaY,hit.localRotationZ},',')
 end
 print('RUNTIME_TRAJECTORY '..table.concat(values,'|'))
end
ui:update(10);snap('settled')
ui:setHover(1);ui:update(.05);snap('hover')
ui:setHover(nil);ui:update(.05);snap('return')
event('card1','down',7);event('card1','drag',7,100,0);snap('drag')
ui:update(.5);event('dragLayer','up',7,100,-300);ui:update(.05);snap('cancel')
host:resize(1600,900);ui:update(10);snap('resize')
assert(host:openDeck());snap('covered');host:closeDeck();snap('uncovered')
ui:setActive(false);snap('unmount');ui:setActive(true);snap('remount')
host.run.combat=H.F.Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist'}});host:refresh();ui:update(10);snap('new-battle')
host:disable();snap('disable')
