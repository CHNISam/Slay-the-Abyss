local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local View=require('abyss_battle_potion_view')
local Pool=require('abyss_potion_random')
local host,ui,panel,event,tap=H.setup({'defend'},{'cultist'})
local data=host.run.data
data.characterId='watcher'
require('abyss_class_potions').register(data)
require('abyss_silent_potions').register(data)
local definitions,seen={},{}
for _,item in ipairs(data.potions.potions)do
 definitions[item.id]=item
 assert(utf8.len(View.shortName(item))==2,item.id..' must retain its full short name')
 local caption=View.slotLabel(item)
 assert(utf8.len(caption)==1,item.id..' must fit one native text line')
 assert(not seen[caption],item.id..' caption collides with '..tostring(seen[caption]))
 seen[caption]=item.id
end
for _,character in ipairs({'ironclad','silent','defect','watcher','shared'})do
 for _,item in ipairs(Pool.pool(character))do assert(definitions[item.id],character..' missing caption definition '..item.id)end
end
assert(View.shortName(definitions.strength_potion)=='力量')
assert(View.shortName(definitions.flex_potion)=='肌肉')
assert(View.shortName(definitions.dexterity_potion)=='敏捷')
assert(View.shortName(definitions.speed_potion)=='速度')
assert(View.slotLabel(definitions.energy_potion)=='量' and View.slotLabel(definitions.power_potion)=='能')
assert(View.slotLabel(definitions.heart_of_iron)=='钢' and View.slotLabel(definitions.essence_of_steel)=='甲')
assert(H.Run.obtainRelic(host.run,'Potion Belt'))
local group=panel:GetChild('potionHelp')
local function box(slot)return slot<4 and panel:GetChild('potion'..slot)or group:GetChild('potion'..slot)end
for first=1,#data.potions.potions,5 do
 host.run.potions={}
 for slot=1,5 do local item=data.potions.potions[first+slot-1];if item then host.run.potions[slot]=item.id end end
 host:refresh()
 for slot=1,5 do
  local id=host.run.potions[slot]
  for _,state in ipairs({'normal','hover','pressed','disabled'})do
   local face=box(slot):GetChild(state);local label=face:GetChild('label')
   assert(label.visible==(id~=nil),'caption visibility follows physical inventory')
   assert(label.text==(id and View.slotLabel(definitions[id])or ''),'caption follows exact slot identity')
  end
 end
 local before=host.run.potions[1]
 tap('potion1',200+first)
 assert(ui.potionMenu and host.run.potions[1]==before,'reading identity remains explicit-use')
 local popup=group:GetChild('potionPopup')
 assert(popup:GetChild('title').text==definitions[before].name,'popup retains full exact name')
 for _,kind in ipairs({'down','up','click'})do popup:GetChild('dismiss').listeners[kind]({touchId=400+first})end
end
-- A press on an old bottle must not use the replacement after its short name changes.
host.run.potions={'strength_potion'};host:refresh();event('potion1','down',700)
host.run.potions={'flex_potion'};host:refresh();event('potion1','up',700);event('potion1','click',700)
assert(host.run.potions[1]=='flex_potion' and not ui.potionMenu,'old pointer cannot open a replacement')
host.run.potions={};host:refresh()
assert(not box(1):GetChild('normal'):GetChild('label').visible,'empty slot retires its caption')
print('POTION_SLOT_IDENTITY_PASS '..#data.potions.potions..' definitions, five pools, all physical states')
