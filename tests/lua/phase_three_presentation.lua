package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=require('abyss_character_presentation')
local Profiles=require('abyss_character_profiles')
local C=require('abyss_combat')
local Data=require('abyss_data')
local Existing=require('abyss_presentation')
local Display=require('abyss_card_display')
local Theme=require('abyss_theme')
local Triggers=require('abyss_card_triggers')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local BattleUI=require('abyss_battle_ui')
local DeckUI=require('abyss_deck_ui')
local Frozen=dofile('tests/lua/support/frozen_display_877c4af.lua')
local cases,rendered=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();cases=cases+1;print('ok phase_three_presentation '..cases..' - '..name)end
local function has(d,id)for _,c in ipairs(d.cards.cards)do if c.id==id then return true end end end
local function prepared(id,source)
 local d=Profiles.prepare(source or Data,id)
 if id=='silent' and not has(d,'bane') then d=require('abyss_silent_attack_cards').withCardDefinitions(d) end
 if id~='watcher' and not has(d,({ironclad='rage',silent='after_image',defect='heat_sinks'})[id]) then d=Triggers.withCards(d,id) end
 return d
end
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
for _,id in ipairs({'ironclad','silent','defect','watcher'})do
 test(id..' every basic and upgrade reaches real BattleUI and DeckUI',function()
  local data=prepared(id);local text=P.prepare(Existing,data)
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
local function show(class,id,statuses,setup,up)
 local data=prepared(class);local texts=P.prepare(Existing,data)
 local opts={seed=42,cardRandomSeed='17',deck={{cardId=id,upgraded=up}},enableStances=class=='watcher'}
 if class=='defect'then opts.orbSlots=3;opts.orbRandomSeed='17'end
 local s=C.new(data,opts)
 for k,v in pairs(statuses or {})do s.player.statuses[k]=v end
 if setup then setup(s)end
 local card=s.hand[1];local definition=C.cardDefinition(s,card)
 local label=texts[id];local template=(up and label.upgradeCombatText or label.combatText)or(up and label.upgradeText or label.text)
 return Display.format(template,definition,C.cardPreview(s,card,1),Theme.color),label,s
end
test('source-driven conditions and generated cards do not trust arbitrary text',function()
 local s=P.prepare(Existing,prepared('silent'))
 assert(s.bane.text:find('中毒',1,true)and s.grand_finale.text:find('抽牌堆为空',1,true))
 assert(s.heel_hook.text:find('虚弱',1,true)and s.dodge_and_roll.text:find('下回合',1,true))
 local w=P.prepare(Existing,prepared('watcher'))
 assert(w.signature_move.text:find('其他攻击',1,true)and w.follow_up.text:find('上一张',1,true))
 assert(w.evaluate.text:find('洞见',1,true)and w.carve_reality.text:find('惩罚',1,true)and w.deceive_reality.text:find('安全',1,true))
 local data=prepared('watcher');for _,c in ipairs(data.cards.cards)do c.text='虚构的999999点伤害';c.upgradeText=c.text end
 local p=P.prepare(Existing,data);assert(not p.halt.text:find('999999',1,true))
end)
test('phase-three damage and next-turn block use actual modified previews',function()
 for _,spec in ipairs({{'watcher','bowling_bash',9},{'defect','barrage',6},{'defect','ftl',7},{'silent','heel_hook',7}})do
  local rendered=show(spec[1],spec[2],{strength=2})
  assert(rendered:find(tostring(spec[3]),1,true)and rendered:find('↑',1,true),rendered)
 end
 local rendered=show('silent','dodge_and_roll',{dexterity=3,frail=1})
 local _,n=rendered:gsub('5↑','');eq(n,2) -- Both current and next-turn Block must use floor((4+3)*.75).
 rendered=show('defect','reinforced_body',{dexterity=2,frail=1})
 assert(rendered:find('6↓',1,true),rendered)
end)
test('Halt displays actual total and Brilliance captures Mantra once',function()
 local r=show('watcher','halt',{dexterity=2,frail=1},function(s)s.player.stance='Wrath'end)
 assert(r:find('11',1,true),r)
 r=show('watcher','brilliance',{strength=2},function(s)s.mantraGained=5;s.player.stance='Divinity'end)
 assert(r:find('57',1,true),r)
 local heavy=show('ironclad','heavy_blade',{strength=2});assert(heavy:find('20',1,true),heavy)
end)
test('Bane nested conditional damage has its own exact dynamic token',function()
 local r,label=show('silent','bane',{strength=2})
 assert(label.combatText:find('{effects.1.then.0.value}',1,true))
 local _,n=r:gsub('9↑','');eq(n,2);assert(not r:find('{effects',1,true))
end)
test('six card-trigger powers describe conditions and retain innate upgrades',function()
 local s=P.prepare(Existing,prepared('silent'));local d=P.prepare(Existing,prepared('defect'));local w=P.prepare(Existing,prepared('ironclad'))
 assert(s.after_image.text:find('每打出一张牌',1,true)and s.after_image.upgradeText:find('先天',1,true))
 assert(s.thousand_cuts.text:find('固定伤害',1,true)and s.envenom.text:find('未被格挡',1,true))
 assert(d.heat_sinks.text:find('能力牌',1,true)and d.storm.text:find('闪电球',1,true))
 assert(d.storm.upgradeText:find('先天',1,true)and w.rage.text:find('本回合',1,true))
end)
test('877c4af forty-card historical input keeps its prepared wording unchanged',function()
 local historical=C.copy(Data);historical.cards=C.copy(Frozen.cards);eq(#historical.cards.cards,40)
 local base=P.prepare(Frozen.existing,require('abyss_warrior_cards').withFoundationCards(historical))
 local expanded=P.prepare(Frozen.existing,prepared('ironclad',historical))
 for _,c in ipairs(historical.cards.cards)do
  if expanded[c.id]then eq(expanded[c.id].name,base[c.id].name);eq(expanded[c.id].text,base[c.id].text);eq(expanded[c.id].upgradeText,base[c.id].upgradeText)end
 end
 local original=Existing.strike.text;expanded.strike.text='mutated';eq(Existing.strike.text,original)
end)
test('verified native-only nine keep their existing display while altered effects still reject',function()
 local wanted={armaments=true,havoc=true,sword_boomerang=true,dual_wield=true,infernal_blade=true,
  searing_blow=true,double_tap=true,feed=true,juggernaut=true}
 local definitions={cards={cards={}}};local original=C.copy(Existing);local count=0
 for _,c in ipairs(Data.cards.cards)do if wanted[c.id]then definitions.cards.cards[#definitions.cards.cards+1]=C.copy(c);count=count+1 end end
 eq(count,9);local shown=P.prepare(Existing,definitions)
 for id in pairs(wanted)do
  assert(shown[id]~=Existing[id]);for key,value in pairs(Existing[id])do eq(shown[id][key],value)end
 end
 for id,row in pairs(Existing)do for key,value in pairs(row)do eq(value,original[id][key])end end
 for _,up in ipairs({false,true})do
  local bad=C.copy(definitions);local c
  for _,entry in ipairs(bad.cards.cards)do if entry.id=='armaments'then c=entry end end
  if up then c.upgrade.effects={{op='invented',value=1}}else c.effects={{op='invented',value=1}}end
  assert(not pcall(P.prepare,Existing,bad))
 end
 local bad=C.copy(definitions);bad.cards.cards[1].condition='invented';assert(not pcall(P.prepare,Existing,bad))
 assert(not pcall(P.prepare,{},definitions))
end)
test('unknown operations statuses conditions and nested branches still reject',function()
 for _,e in ipairs({{op='gainStrengthPower',status='invented',value=1},{op='gainCardTriggerPower',status='invented',value=1},
  {op='makeTempCard',cardId='invented',pile='hand',value=1},{op='previousCardType',cardType='invented',effect={op='energy',value=1}},
  {op='conditional',['if']='target_poison',['then']={{op='invented',value=1}}},
  {op='conditional',['if']='target_poison',['then']={{op='conditional',['if']='target_poison',['then']={{op='damage',value=1}}}}}})do
  local d=prepared('watcher');d.cards.cards[1].effects={e};assert(not pcall(P.prepare,Existing,d))
 end
 for _,field in ipairs({'condition','costMode'})do local d=prepared('watcher');d.cards.cards[1][field]='invented';assert(not pcall(P.prepare,Existing,d))end
end)
print('phase_three_presentation: '..cases..' passed; '..rendered..' real card render variants')
