local before=dofile('tests/fixtures/card-wrap-measurement-before.lua')
local fit=require('abyss_card_display').fit
local texts={"伤害 ，","伤害\n，","（当前 100 点）","Deal 100 damage. Gain Block!","one exceptionallylongword", "", "<b>伤害</b> ！"}
local fixtures,catalogTexts,catalogIds=#texts,0,{}
for id,card in pairs(require('abyss_presentation')) do
 if type(card)=='table' then
  if type(card.text)=='string' then texts[#texts+1]=card.text;catalogTexts=catalogTexts+1 end
  if type(card.upgradeText)=='string' then texts[#texts+1]=card.upgradeText;catalogTexts=catalogTexts+1 end
  if type(card.text)=='string'or type(card.upgradeText)=='string'then catalogIds[#catalogIds+1]=id end
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
assert(count==#texts*16 and #catalogIds>0,'every current text must execute all sixteen fit geometries')
table.sort(catalogIds)
print('CARD_WRAP_EQUIVALENCE_CATALOG '..table.concat(catalogIds,','))
print('CARD_WRAP_EQUIVALENCE_COVERAGE fixtures='..fixtures..' catalogTexts='..catalogTexts..' variants=16 cases='..count)
print('CARD_WRAP_EQUIVALENCE_PASS '..count)
