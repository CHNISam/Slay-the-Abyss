local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel,event,tap,drain=H.setup({'defend'},{'cultist'})
local battle=host.run.combat
local function same(a,b)
 assert(type(a)==type(b),'readout changed rule type')
 if type(a)~='table'then assert(a==b,'readout changed rule value');return end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil,'readout added a rule field')end
end
local function readout(expected,charged)
 local number,icon=panel:GetChild('energy'),panel:GetChild('energyIcon')
 assert(number.visible and icon.visible)
 local shadow=assert(icon.children.valueShadow,'approved numeric drop shadow is missing')
 assert(number.text==expected and shadow.text==expected,'foreground and shadow must follow the same actual energy')
 local colour=number.fontColor
 assert(colour.r==255 and colour.g==248 and colour.b==236,'zero and charged values both stay white')
 assert(icon:GetChild('light').visible==charged,'zero energy must retain its dark state')
end
readout('3/3',true)
tap('card1',71);tap('playArea',71);drain();readout('2/3',true)
assert(battle.energy==2 and #battle.hand==0 and battle.player.block==5,'one core Defend command')
for _,value in ipairs({0,5})do
 battle.energy=value;local before=H.F.Combat.copy(battle)
 ui:render();ui:render();readout(value..'/3',value>0);same(battle,before)
end
host.run.phase='reward';host.run.rewards={gold=0,goldClaimed=false,manualContinue=true,cardResolved=false,cards={'strike'}}
ui:render()
for _,name in ipairs({'energyRing','energyDisc','energyIcon','energy'})do assert(not panel:GetChild(name).visible,'reward hides whole orb '..name)end
host.run.phase='combat';ui:render();readout('5/3',true)
print('APPROVED_ENERGY_ORB_PASS')
