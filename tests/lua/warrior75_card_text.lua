-- Conservative layout budgets, not native screenshot certification.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,C,T=require('abyss_card_display'),require('abyss_combat'),require('abyss_theme')
local data,P=require('abyss_data'),require('abyss_presentation')
local s=C.new(data,{deck={},enemies={'cultist'},seed=1})
local n,original,necronomicurse=0,0,0
for _,definition in ipairs(data.cards.cards)do
 for _,up in ipairs({false,true})do
  local display=P[definition.id]
  local title,font,fits=D.title(display.name,up)
  assert(fits,'title does not fit: '..definition.id)
  assert(title:gsub('\n',' ')==display.name..(up and '＋' or ''),'title lost or renamed characters')
  assert(font>=T.font.minimum and font<=T.font.cardName)
  for _,buff in ipairs({0,999})do
   local c={uid=1,cardId=definition.id,upgraded=up};s.hand={c};s.player.block=999
   s.player.statuses={strength=buff,dexterity=buff,weak=buff>0 and 1 or nil,frail=buff>0 and 1 or nil}
   local card=C.cardDefinition(s,c);local live=up and display.upgradeCombatText or display.combatText
   local text=up and display.upgradeText or display.text
   if live then text=D.format(live,card,C.cardPreview(s,c,1),T.color)end
   if definition.id=='body_slam' then text=text..'（当前 1498 点）' end
   local body={};assert(D.writeBody(body,text),'body does not fit: '..definition.id..(up and '+' or '')..' '..text)
   assert(body.text==text,'body was truncated');assert(body.fontSize>=T.font.minimum)
  end
  n=n+1
  if definition.id=='necronomicurse' then necronomicurse=necronomicurse+1 else original=original+1 end
 end
end
assert(original==180,'all original ninety card pairs remain covered')
assert(necronomicurse==2,'the added Necronomicurse keeps both upgrade variants')
assert(n==182)
print('Card text: 180 original and 2 Necronomicurse variants retain full names and text at approved font bounds; native visual verification still required.')
