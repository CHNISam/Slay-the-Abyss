local first,last=...
first,last=first or 1,last or 1
assert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=4 and first<=last,'invalid original fixture slice')
local registered=0
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=require('abyss_character_presentation')
local C=require('abyss_combat')
local Existing=require('abyss_presentation')
local Display=require('abyss_card_display')
local Theme=require('abyss_theme')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local BattleUI=require('abyss_battle_ui')
local DeckUI=require('abyss_deck_ui')
local cases,rendered=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)registered=registered+1;if registered<first or registered>last then return end;fn();cases=cases+1;print('ok phase_four_presentation_render '..cases..' - '..name)end
local prepared=dofile('tests/lua/support/phase_four_presentation_data.lua')
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
-- Own process: keep all four original class cases within the unchanged 30s limit.
for _,id in ipairs({'ironclad','silent','defect','watcher'})do
 test(id..' every basic and upgrade reaches real BattleUI and DeckUI',function()
  local data=prepared(id);local text=P.prepare(Existing,data)
  eq(#data.cards.cards,({ironclad=80,silent=90,defect=90,watcher=100})[id])
  local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
  local ui=BattleUI.new(root:GetChild('battlePanel'),data,text,'click',platform,{embedded=true})
  local deck={}
  for _,card in ipairs(data.cards.cards)do
   local label=assert(text[card.id]);assert(label.name:find('[\128-\255]') and #label.text>0 and #label.upgradeText>0)
   for _,up in ipairs({false,true})do
    local opts={seed=42,cardRandomSeed='17',deck={{cardId=card.id,upgraded=up}}}
    if id=='defect'then opts.orbSlots=3;opts.orbRandomSeed='17'end
    if id=='watcher'then opts.enableStances=true end
    local s=C.new(data,opts)
    dofile('tests/lua/support/presentation_hand.lua')(s,card.id)
    ui.run={phase='combat',combat=s,data=data,relics={},potions={},gold=99};ui.target=1;ui:render()
    local box=root:GetChild('battlePanel'):GetChild('card1')
    assert(#box:GetChild('name').text>0 and #box:GetChild('label').text>0)
    local definition=C.cardDefinition(s,s.hand[1]);local preview=C.cardPreview(s,s.hand[1],1)
    local cost=definition.costMode=='all_energy' and 'X' or definition.cost==-2 and '—' or string.format('%.0f',definition.cost)
    eq(up and label.upgradeCost or label.cost,cost)
    local raw=up and label.upgradeText or label.text
    assert(not raw:find('{effects',1,true))
    local dynamic=up and label.upgradeCombatText or label.combatText
    if dynamic then assert(not Display.format(dynamic,definition,preview,Theme.color):find('{effects',1,true))end
    deck[#deck+1]={uid=#deck+1,cardId=card.id,upgraded=up};rendered=rendered+1
   end
  end
  local d=DeckUI.new(root:GetChild('deckPanel'),text,'click',platform,function()end)
  assert(d:open({deck=deck,data=data}));d:update()
  local grid=root:GetChild('deckPanel'):GetChild('grid')
  for i=1,#deck do assert(#grid:recycle(0,i-1):GetChild('face'):GetChild('label').text>0)end
 end)
end
assert(registered==4,'class render discovery changed')
local expected=0;for i=first,last do expected=expected+({160,180,180,200})[i]end
eq(cases,last-first+1);eq(rendered,expected)
print('phase_four_presentation_render: '..cases..' passed; '..rendered..' real card render variants')
