local before=dofile('tests/fixtures/card-wrap-measurement-before.lua')
local fit=require('abyss_card_display').fit
local texts={"伤害 ，","伤害\n，","（当前 100 点）","Deal 100 damage. Gain Block!","one exceptionallylongword", "", "<b>伤害</b> ！"}
local groups={};for i=1,#texts do groups[i]='legacy'end
local legacyTexts,newTexts=0,0
for id,card in pairs(require('abyss_presentation')) do
 if type(card)=='table' then
  for _,field in ipairs({'text','upgradeText'})do
   if type(card[field])=='string'then
    texts[#texts+1]=card[field];groups[#texts]=id=='necronomicurse' and 'necronomicurse'or 'legacy'
    if id=='necronomicurse'then newTexts=newTexts+1 else legacyTexts=legacyTexts+1 end
   end
  end
 end
end
assert(legacyTexts==180 and newTexts==2,'all original card texts plus both new curse variants required')
local count,legacyCases,newCases=0,0,0
for index,text in ipairs(texts) do for _,font in ipairs({16,22}) do
 for _,width in ipairs({60,144}) do for _,height in ipairs({50,110}) do
 for _,geometry in ipairs({{}, {1.65,1.25}}) do
  local a,b=before(text,font,width,height,geometry[1],geometry[2])
  local x,y=fit(text,font,width,height,geometry[1],geometry[2])
  assert(a==x and b==y,'fit output changed: '..text)
  count=count+1
  if groups[index]=='necronomicurse'then newCases=newCases+1 else legacyCases=legacyCases+1 end
 end
 end end
end end
assert(legacyCases==2992 and newCases==32)
print('CARD_WRAP_LEGACY_PASS '..legacyCases)
print('CARD_WRAP_NECRONOMICURSE_PASS '..newCases)
print('CARD_WRAP_EQUIVALENCE_PASS '..count)
