package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Run=require('abyss_combat'),require('abyss_actor'),require('abyss_run')
local Display=require('abyss_card_display')
local data=Run.new(require('abyss_data'),42).data
local look=require('abyss_character_presentation').prepare(require('abyss_presentation'),data)
local catalog={cards={}};for _,d in ipairs(data.cards.cards)do catalog.cards[d.id]=d end
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn)
 if not ok then failed=failed+1 end
 print((ok and 'ok 'or 'not ok ')..count..' '..name..(ok and ''or ': '..tostring(why)))
end
local function plain(text)return text:gsub('<[^>]+>','')end
local function damage(text)return tonumber(plain(text):match('造成(%d+)'))end
local function battle(id,up)
 local s=C.new(data,{deck={{uid=7001,cardId=id,upgraded=up,misc=id=='ritual_dagger'and 31 or nil}},enemies={'jaw_worm'},seed=42})
 s.enemies[1].hp,s.enemies[1].maxHp=300,300;s.energy=3
 return s,s.hand[1]
end
local modifiers={
 {name='base',dagger=31,greed={20,25}},
 {name='Strength',strength=4,dagger=35,greed={24,29}},
 {name='Weak',strength=4,weak=1,dagger=26,greed={18,21}},
 {name='Vulnerable',strength=4,weak=1,vulnerable=1,dagger=39,greed={27,32}},
 {name='Intangible',strength=4,weak=1,vulnerable=1,intangible=1,dagger=1,greed={1,1}},
}
for _,id in ipairs({'ritual_dagger','hand_of_greed'})do for _,up in ipairs({false,true})do
 local value=up and 25 or 20;local growth=up and 5 or 3
 test(id..(up and '+'or '')..' non-combat permanent text',function()
  local instance={cardId=id,upgraded=up,misc=id=='ritual_dagger'and 31 or nil}
  local definition=C.cardDefinition({catalog=catalog},instance)
  local text=Display.permanentText(look[id],definition,instance)
  eq(damage(text),id=='ritual_dagger'and 31 or value)
  if id=='ritual_dagger'then eq(tonumber(text:match('永久增加(%d+)点伤害')),growth)
  else eq(tonumber(text:match('获得(%d+)金币')),value)end
  assert(not text:find('{effects',1,true))
 end)
 for _,m in ipairs(modifiers)do test(id..(up and '+'or '')..' '..m.name..' preview/text/actual damage',function()
  local s,c=battle(id,up)
  for _,key in ipairs({'strength','weak'})do if m[key]then A.addStatus(s.player,key,m[key])end end
  for _,key in ipairs({'vulnerable','intangible'})do if m[key]then A.addStatus(s.enemies[1],key,m[key])end end
  local expected=id=='ritual_dagger'and m.dagger or m.greed[up and 2 or 1]
  local definition=C.cardDefinition(s,c);local preview=C.cardPreview(s,c,1)
  local text=Display.combatText(look[id],definition,c,preview)
  local permanent=Display.permanentText(look[id],definition,c)
  local hp=s.enemies[1].hp;assert(C.play(s,c.uid,1));eq(hp-s.enemies[1].hp,expected)
  eq(damage(text),expected);assert(preview[1],'missing actual damage preview');eq(preview[1].low,expected);eq(preview[1].high,expected)
  eq(damage(permanent),id=='ritual_dagger'and 31 or value)
  if id=='ritual_dagger'then eq(tonumber(plain(text):match('永久增加(%d+)点伤害')),growth)
  else eq(tonumber(plain(text):match('获得(%d+)金币')),value)end
  assert(not text:find('{effects',1,true))
 end)end
 test(id..(up and '+'or '')..' killing blow keeps fixed gold/growth and updates permanent misc',function()
  local s,c=battle(id,up);A.addStatus(s.player,'strength',4);A.addStatus(s.enemies[1],'vulnerable',1)
  local expected=id=='ritual_dagger'and 52 or (up and 43 or 36)
  s.enemies[1].hp=expected;local gold=s.player.gold
  local text=Display.combatText(look[id],C.cardDefinition(s,c),c,C.cardPreview(s,c,1))
  assert(C.play(s,c.uid,1));eq(s.enemies[1].hp,0);eq(damage(text),expected)
  if id=='ritual_dagger'then
   eq(c.misc,31+growth);eq(s.ritualDaggerGrowth[7001],growth);eq(s.player.gold,gold)
   eq(damage(Display.permanentText(look[id],C.cardDefinition(s,c),c)),31+growth)
  else eq(s.player.gold-gold,value);eq(tonumber(plain(text):match('获得(%d+)金币')),value)end
 end)
end end
assert(failed==0,tostring(failed)..'/'..count..' colorless attack display cases failed')
print('COLORLESS_ATTACK_DISPLAY '..count..' real non-combat/combat cases passed')
