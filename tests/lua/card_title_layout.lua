local function plainCardTitle(text)return (text:gsub('<color=#[%x]+>',''):gsub('</color>',''))end
-- Conservative native glyph budgets; this is not an in-client visual acceptance.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,T,P,E,Run,Data=require('abyss_card_display'),require('abyss_theme'),require('abyss_character_presentation'),require('abyss_presentation'),require('abyss_run'),require('abyss_data')
local expected={['FR2-053']=true,['FR2-065']=true,['FR2-069']=true,['FR2-075']=true,['RD2-003']=true,['RD2-004']=true}
local colors={ironclad='red',silent='green',defect='blue',watcher='purple'}
local roles={hutao='HT',arlecchino='AR',furina='FR',raiden='RD'}
local frozen=require('abyss_original_v4_data')
-- Independent component libraries supply expected IDs; Run owns their assembly.
local official={red={},green={},blue={},purple={}}
local red=require('abyss_run_red_card_contract')
for _,card in ipairs(Data.cards.cards)do if red.isRed(card.id)then official.red[card.id]=true end end
for _,class in ipairs({'silent','defect','watcher'})do
 local library=require('abyss_character_profiles').prepare({rules={player={}},cards={cards={}},
  statuses={statuses={}},relics={relics={}},potions={potions={}}},class)
 for _,card in ipairs(library.cards.cards)do
  if card.color==colors[class] and card.type~='status' and card.type~='curse' and card.rarity~='special'then
   assert(not official[colors[class]][card.id],'duplicate component identity: '..card.id)
   official[colors[class]][card.id]=true
  end
 end
end
for color,ids in pairs(official)do
 local count=0;for _ in pairs(ids)do count=count+1 end
 assert(count==75,'incomplete independent official '..color..' library')
end
local text,font,_,marker=D.title('恰到好处的停顿',true)
assert(text=='恰到好处的停顿' and marker=='＋' and font==14,
 'long upgraded title must preserve its name and move only the marker out of the artwork')
local total,moved,expectedVariants=0,0,0
local movedIds={}
for _,class in ipairs({'ironclad','silent','defect','watcher','hutao','arlecchino','furina','raiden'}) do
 local run=Run.new(Data,42,{character=class,experimental=true})
 local definitions,identities,metadata={},{},assert(run.data.cards.sourcePools.cardSourceMetadata)
 for _,card in ipairs(run.data.cards.cards)do
  assert(not definitions[card.id],'duplicate current definition: '..class..'/'..card.id)
  definitions[card.id]=card
 end
 -- Join the full source metadata index, then independently require all input
 -- definitions and the official class/role identities, without a stale pool size.
 for id,fact in pairs(metadata)do
  local card=assert(definitions[id],'source catalog definition was not checked: '..class..'/'..id)
  assert(fact.type==card.type and fact.rarity==card.rarity,'source catalog identity mismatch: '..id)
  identities[#identities+1]=id
 end
 for _,card in ipairs(Data.cards.cards)do assert(definitions[card.id],'base input omitted: '..card.id)end
 if colors[class]then
  local counts={red=0,green=0,blue=0,purple=0}
  for _,card in pairs(definitions)do
   if counts[card.color] and card.type~='status' and card.type~='curse' and card.rarity~='special'then
    counts[card.color]=counts[card.color]+1
   end
  end
  for color,count in pairs(counts)do assert(count==75,'complete official '..color..' card library was not checked')end
  for color,ids in pairs(official)do for id in pairs(ids)do
   assert(definitions[id] and definitions[id].color==color,'official component identity omitted: '..class..'/'..id)
  end end
 else
  for _,raw in ipairs(frozen.cards)do if raw.role==roles[class]then
   assert(definitions[raw.id] and definitions[raw.id].originalV4,'frozen role card omitted: '..raw.id)
  end end
 end
 assert(#identities==#run.data.cards.cards,'every definition needs its source identity receipt: '..class)
 table.sort(identities)
 print('CARD_TITLE_CATALOG '..class..' '..table.concat(identities,','))
 local checked,variants={},0
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
  if marker~='' then
   assert(upgraded and expected[card.id] and text==name and marker=='＋',card.id)
   assert(not movedIds[card.id],'overflow identity checked twice: '..card.id)
   movedIds[card.id]=true;moved=moved+1
  end
  local control,kind={},{}
  assert(D.writeTitle(control,name,upgraded,count,kind,'技能'))
  assert(plainCardTitle(control.text)==text and control.fontSize==font and control.adaptiveFontSize==false)
  assert(plainCardTitle(kind.text)=='技能'..(marker~='' and ' '..marker or ''),'upgrade marker did not reach existing type line: '..card.id)
  if upgraded then assert((control.text..kind.text):find('<color=#8DE08A>'..suffix..'</color>',1,true),'only the upgrade marker is green')end
  total=total+1;variants=variants+1;checked[card.id]=(checked[card.id]or 0)+1
 end end
 for _,id in ipairs(identities)do assert(checked[id]==2,'base and upgrade must both be checked: '..class..'/'..id)end
 assert(variants==#identities*2)
 expectedVariants=expectedVariants+#identities*2
 print('CARD_TITLE_COVERAGE '..class..' expectedids='..#identities..' variants='..variants)
end
for id in pairs(expected)do assert(movedIds[id],'expected overflow identity omitted: '..id)end
assert(total==expectedVariants and moved==6,'complete current pool or six overflow titles were missed')
print('CARD_TITLE_TOTAL expectedids='..math.floor(expectedVariants/2)..' variants='..total..' overflow='..moved)
print('LUA_CARD_TITLE_LAYOUT_PASS '..total..' variants; six upgrade markers use the existing type slot')
