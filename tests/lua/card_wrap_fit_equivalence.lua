local before=dofile('tests/fixtures/card-wrap-measurement-before.lua')
local fit=require('abyss_card_display').fit
local texts={"伤害 ，","伤害\n，","（当前 100 点）","Deal 100 damage. Gain Block!","one exceptionallylongword", "", "<b>伤害</b> ！"}
for _,card in pairs(require('abyss_presentation')) do
 if type(card)=='table' then
  if type(card.text)=='string' then texts[#texts+1]=card.text end
  if type(card.upgradeText)=='string' then texts[#texts+1]=card.upgradeText end
 end
end
local count=0
for _,text in ipairs(texts) do for _,font in ipairs({16,22}) do
 for _,width in ipairs({60,144}) do for _,height in ipairs({50,110}) do
 for _,geometry in ipairs({{}, {1.65,1.25}}) do
  local a,b=before(text,font,width,height,geometry[1],geometry[2])
  local x,y=fit(text,font,width,height,geometry[1],geometry[2])
  assert(a==x and b==y,'fit output changed: '..text)
  count=count+1
 end
 end end
end end
assert(count>=56)
print('CARD_WRAP_EQUIVALENCE_PASS '..count)
