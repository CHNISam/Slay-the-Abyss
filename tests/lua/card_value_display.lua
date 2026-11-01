package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Combat = require('abyss_combat')
local Data = require('abyss_data')
local Display = require('abyss_card_display')
local count = 0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function state(id, statuses, upgraded)
 local s=Combat.new(Data,{deck={{cardId=id,upgraded=upgraded}},enemies={'jaw_worm','cultist'}})
 for k,v in pairs(statuses or {}) do Combat.addStatus(s.player,k,v) end
 return s,s.hand[1]
end
local function check(id,statuses,base,current,direction,upgraded)
 local s,card=state(id,statuses,upgraded)
 local token=Display.values(Combat.cardDefinition(s,card),Combat.cardPreview(s,card))[1]
 eq(token.base,base) eq(token.current,current) eq(token.direction,direction)
 eq(token.text,tostring(current)..(direction=='up' and '↑' or direction=='down' and '↓' or ''))
 eq(token.colourKey,direction=='up' and 'cardValueIncrease' or direction=='down' and 'cardValueDecrease' or 'text')
 count=count+1
end
check('strike',{},6,6,'same')
check('strike',{strength=2},6,8,'up')
check('strike',{weak=1},6,4,'down')
check('strike',{strength=2,weak=1},6,6,'same')
check('defend',{},5,5,'same')
check('defend',{frail=1},5,3,'down')
check('defend',{dexterity=3},5,8,'up')
check('defend',{dexterity=3,frail=1},5,6,'up')
check('defend',{frail=1},8,6,'down',true)
check('defend',{dexterity=-20},5,0,'down')
local s,card=state('iron_wave',{strength=-1,dexterity=2})
local tokens=Display.values(Combat.cardDefinition(s,card),Combat.cardPreview(s,card))
eq(tokens[1].direction,'up') eq(tokens[2].direction,'down')
s,card=state('body_slam',{strength=1}) s.player.block=9
eq(Display.values(Combat.cardDefinition(s,card),Combat.cardPreview(s,card))[1],nil)
s,card=state('strike',{weak=1}) Combat.addStatus(s.enemies[2],'vulnerable',1)
for _,t in ipairs({{nil,4,'down'},{2,6,'same'},{nil,4,'down'}}) do
 local token=Display.values(Combat.cardDefinition(s,card),Combat.cardPreview(s,card,t[1]))[1]
 eq(token.current,t[2]) eq(token.direction,t[3])
end
local invalid=Display.values({effects={{op='draw',value=2},{op='damage',value=6}}},{{op='draw',low=3,high=3},{op='damage',low=4,high=9}})
eq(next(invalid),nil)
local palette=require('abyss_theme').color
local function format(id,statuses,template,target)
 local s,card=state(id,statuses)
 if target then Combat.addStatus(s.enemies[target],'vulnerable',1) end
 return Display.format(template,Combat.cardDefinition(s,card),Combat.cardPreview(s,card,target),palette)
end
eq(format('defend',{frail=1},'获得 {effects.0.value} 点格挡。'),'获得 <color=#EF7672>3↓</color> 点格挡。')
eq(format('strike',{weak=1},'造成 {effects.0.value} 点伤害。'),'造成 <color=#EF7672>4↓</color> 点伤害。')
eq(format('defend',{dexterity=3},'获得 {effects.0.value} 点格挡。'),'获得 <color=#7DC77A>8↑</color> 点格挡。')
eq(format('strike',{strength=2,weak=1},'造成 {effects.0.value} 点伤害。'),'造成 6 点伤害。')
eq(format('iron_wave',{strength=-1,dexterity=2},'先获得 {effects.0.value} 格挡，再造成 {effects.1.value} 伤害。'),
 '先获得 <color=#7DC77A>7↑</color> 格挡，再造成 <color=#EF7672>4↓</color> 伤害。')
eq(format('bash',{strength=2},'造成 {effects.0.value} 伤害，施加 {effects.1.value} 层易伤。'),
 '造成 <color=#7DC77A>10↑</color> 伤害，施加 2 层易伤。')
print('LUA_CARD_VALUE_DISPLAY_PASS '..count)
