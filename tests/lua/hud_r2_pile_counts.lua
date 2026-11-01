local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel=H.setup()
local battle=host.run.combat
for _,count in ipairs({0,1,9,10,99,100,999})do
 local cards={};for i=1,count do cards[i]={uid=1000+i,cardId='defend',upgraded=false}end
 battle.draw,battle.discard=cards,{};host:refresh()
 assert(panel:GetChild('draw').text==tostring(count))
 assert(panel:GetChild('discard').text=='0')
 battle.draw,battle.discard={},cards;host:refresh()
 assert(panel:GetChild('draw').text=='0')
 assert(panel:GetChild('discard').text==tostring(count))
 assert(#battle.discard==count and #battle.draw==0,'render modified pile data')
end
print('HUD_R2_COUNTS_PASS')
