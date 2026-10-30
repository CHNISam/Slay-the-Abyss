local function plainCardTitle(text)return (text:gsub('<color=#[%x]+>',''):gsub('</color>',''))end
-- Conservative native glyph budgets; this is not an in-client visual acceptance.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,T,P,E,Run,Data=require('abyss_card_display'),require('abyss_theme'),require('abyss_character_presentation'),require('abyss_presentation'),require('abyss_run'),require('abyss_data')
local expected={['FR2-053']=true,['FR2-065']=true,['FR2-069']=true,['FR2-075']=true,['RD2-003']=true,['RD2-004']=true}
local expectedCount={ironclad=367,silent=367,defect=367,watcher=367,hutao=204,arlecchino=204,furina=204,raiden=204}
local text,font,_,marker=D.title('恰到好处的停顿',true)
assert(text=='恰到好处的停顿' and marker=='＋' and font==14,
 'long upgraded title must preserve its name and move only the marker out of the artwork')
local total,moved=0,0
for _,class in ipairs({'ironclad','silent','defect','watcher','hutao','arlecchino','furina','raiden'}) do
 local run=Run.new(Data,42,{character=class,experimental=true})
 assert(#run.data.cards.cards==expectedCount[class],'complete character catalog was not checked: '..class)
 local presentation=P.prepare(E,run.data)
 for _,card in ipairs(run.data.cards.cards) do for _,upgraded in ipairs({false,true}) do
  local name=presentation[card.id].name
  local count=card.repeatable and 999 or nil
  local suffix=upgraded and ('＋'..(count and tostring(count) or '')) or ''
  local text,font,fits,marker=D.title(name,upgraded,count)
  marker=marker or ''
  assert(fits,'title does not fit: '..card.id)
  assert(text..marker==name..suffix,'title or upgrade marker was lost: '..card.id)
  assert(not text:find('\n',1,true),'title spilled into artwork: '..card.id)
  local _,inside=D.fit(text,font,100,30,1.65)
  assert(inside and font>=14,'title glyphs exceed the approved 30-unit band: '..card.id)
  if marker~='' then assert(upgraded and expected[card.id] and text==name and marker=='＋',card.id);moved=moved+1 end
  local control,kind={},{}
  assert(D.writeTitle(control,name,upgraded,count,kind,'技能'))
  assert(plainCardTitle(control.text)==text and control.fontSize==font and control.adaptiveFontSize==false)
  assert(plainCardTitle(kind.text)=='技能'..(marker~='' and ' '..marker or ''),'upgrade marker did not reach existing type line: '..card.id)
  if upgraded then assert((control.text..kind.text):find('<color=#8DE08A>'..suffix..'</color>',1,true),'only the upgrade marker is green')end
  total=total+1
 end end
end
assert(total==4568 and moved==6,'complete current pool or six overflow titles were missed')
print('LUA_CARD_TITLE_LAYOUT_PASS '..total..' variants; six upgrade markers use the existing type slot')
