package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=require('abyss_character_presentation')
local Profiles=require('abyss_character_profiles')
local C=require('abyss_combat')
local Run=require('abyss_run')
local Display=require('abyss_card_display')
local Theme=require('abyss_theme')
local Data=require('abyss_data')
local Existing=require('abyss_presentation')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local BattleUI=require('abyss_battle_ui')
local DeckUI=require('abyss_deck_ui')
local cases=0
local function test(name,fn)fn();cases=cases+1;print('ok '..cases..' '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local rendered=0
for _,id in ipairs({'ironclad','silent','defect','watcher'}) do
 test(id..' all profile cards basic and upgraded reach real battle and deck render',function()
  local prepared=Profiles.prepare(Data,id)
  local text=P.prepare(Existing,prepared)
  local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
  local battleUI=BattleUI.new(root:GetChild('battlePanel'),prepared,text,'click',platform,{embedded=true})
  local run=Run.new(Data,'1',{experimental=true,character=id})
  local deck={}
  for _,card in ipairs(prepared.cards.cards) do
   local display=text[card.id]
   assert(display.name:find('[\128-\255]') and #display.text>0 and #display.upgradeText>0)
   eq(display.type,card.type)
   for _,up in ipairs({false,true}) do
    local options={seed=42,deck={{cardId=card.id,upgraded=up}}}
    if id=='defect' then options.orbSlots=3;options.orbRandomSeed='17' end
    if id=='watcher' then options.enableStances=true end
    local battle=C.new(prepared,options)
    run.phase='combat';run.combat=battle
    battleUI.run=run;battleUI.target=1;battleUI:render()
    local box=root:GetChild('battlePanel'):GetChild('card1')
    assert(#box:GetChild('name').text>0 and #box:GetChild('label').text>0)
    local definition=C.cardDefinition(battle,battle.hand[1])
    local expectedCost=definition.costMode=='all_energy' and 'X' or definition.cost==-2 and '—' or string.format('%.0f',definition.cost)
    eq(up and display.upgradeCost or display.cost,expectedCost)
    local raw=up and display.upgradeText or display.text
    local combat=up and display.upgradeCombatText or display.combatText
    if combat then
     local output=Display.format(combat,definition,C.cardPreview(battle,battle.hand[1],1),Theme.color)
     assert(#output>0 and not output:find('{effects',1,true))
    end
    assert(not raw:find('{effects',1,true),'static deck text must have resolved numbers')
    deck[#deck+1]={uid=#deck+1,cardId=card.id,upgraded=up}
    rendered=rendered+1
   end
  end
  -- Read-only deck rendering exercises every item through the real adapter.
  run.deck=deck
  local deckUI=DeckUI.new(root:GetChild('deckPanel'),text,'click',platform,function()end)
  assert(deckUI:open(run));deckUI:update()
  local grid=root:GetChild('deckPanel'):GetChild('grid')
  for i=1,#deck do
   local control=grid:recycle(0,i-1)
   assert(#control:GetChild('face'):GetChild('name').text>0)
   assert(#control:GetChild('face'):GetChild('label').text>0)
  end
 end)
end

test('existing approved display remains detached and known unchanged cards retain wording',function()
 local prepared=Profiles.prepare(Data,'ironclad');local result=P.prepare(Existing,prepared)
 eq(result.strike.text,Existing.strike.text);eq(result.strike.name,Existing.strike.name)
 result.strike.text='changed';assert(Existing.strike.text~='changed');assert(result~=Existing)
 eq(Data.cards.cards[1].id,'strike')
end)
test('new dynamic damage tokens follow actual Combat preview instead of static base',function()
 local data=Profiles.prepare(Data,'defect');local text=P.prepare(Existing,data)
 local battle=C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck={'cold_snap'}})
 battle.player.statuses.strength=4
 local card=battle.hand[1];local definition=C.cardDefinition(battle,card)
 local rendered=Display.format(text.cold_snap.combatText,definition,C.cardPreview(battle,card,1),Theme.color)
 assert(rendered:find('10',1,true) and rendered:find('↑',1,true));assert(text.cold_snap.text:find('6',1,true))
end)
test('Shiv Miracle discard triggers X cost retain exhaust and ethereal are truthful',function()
 local silent=P.prepare(Existing,Profiles.prepare(Data,'silent'))
 assert(silent.shiv.text:find('消耗',1,true) and silent.shiv.text:find('4',1,true) and silent.shiv.upgradeText:find('6',1,true))
 assert(silent.tactician.text:find('1',1,true) and silent.tactician.upgradeText:find('2',1,true))
 assert(silent.reflex.text:find('2',1,true) and silent.reflex.upgradeText:find('3',1,true))
 local watcher=P.prepare(Existing,Profiles.prepare(Data,'watcher'))
 assert(watcher.miracle.text:find('保留',1,true) and watcher.miracle.text:find('消耗',1,true))
 eq(watcher.miracle.cost,'0');assert(watcher.miracle.upgradeText:find('2',1,true))
 local warrior=P.prepare(Existing,Profiles.prepare(Data,'ironclad'))
 eq(warrior.whirlwind.cost,'X');assert(warrior.true_grit.text:find('随机',1,true) and warrior.true_grit.upgradeText:find('选择',1,true))
 assert(warrior.warcry.text:find('消耗',1,true) and warrior.clash.text:find('全部为攻击牌',1,true))
 local function burnValue(text)
  return assert(tonumber(text:match('受到%s*(%d+)%s*点伤害')),'missing exact Burn damage')
 end
 local defectData=Profiles.prepare(Data,'defect')
 local before=Existing.burn and Existing.burn.upgradeText
 local modern=P.prepare(Existing,defectData).burn
 eq(burnValue(modern.text),2);eq(burnValue(modern.upgradeText),4)
 if Existing.burn then eq(modern.name,Existing.burn.name);eq(Existing.burn.upgradeText,before) end
 for _,up in ipairs({false,true}) do
  local battle=C.new(defectData,{seed=42,deck={{cardId='burn',upgraded=up}}})
  eq(C.cardDefinition(battle,battle.hand[1]).burnDamage,up and 4 or 2)
 end
 local native
 for _,card in ipairs(Data.cards.cards) do if card.id=='burn' then native=C.copy(card) end end
 assert(native and native.burnDamage==nil and native.endTurnDamage==2)
 local original=P.prepare({}, {cards={cards={native}}}).burn
 eq(burnValue(original.text),native.endTurnDamage)
 eq(burnValue(original.upgradeText),native.upgrade and native.upgrade.endTurnDamage or native.endTurnDamage)
 -- Also exercise the native schema when its upgrade explicitly changes damage.
 local nativeUpgrade=C.copy(native);nativeUpgrade.upgrade=C.copy(nativeUpgrade.upgrade or {})
 nativeUpgrade.upgrade.endTurnDamage=4
 local fallback=P.prepare({}, {cards={cards={nativeUpgrade}}}).burn
 eq(burnValue(fallback.text),2);eq(burnValue(fallback.upgradeText),4)
end)
test('unknown op in either branch refuses even if existing presentation is available',function()
 for _,up in ipairs({false,true}) do
  local data=Profiles.prepare(Data,'defect');local card=data.cards.cards[4]
  if up then card.upgrade={effects={{op='invented',value=1}}} else card.effects={{op='invented',value=1}} end
  assert(not pcall(P.prepare,Existing,data))
 end
end)
test('unknown status orb hand mode and empty card explicitly refuse',function()
 local function zap(data)
  for _,card in ipairs(data.cards.cards) do
   if card.id=='zap' then assert(card.type=='skill' and card.cost>=0);return card end
  end
  error('missing ordinary Zap definition')
 end
 for _,effect in ipairs({{op='gainStatus',status='invented',value=1},{op='channelOrb',orb='invented',value=1},{op='handChoice',mode='invented',value=1}}) do
  local data=Profiles.prepare(Data,'defect');zap(data).effects={effect};assert(not pcall(P.prepare,Existing,data))
 end
 local data=Profiles.prepare(Data,'defect');zap(data).effects={};assert(not pcall(P.prepare,Existing,data))
end)
test('Accuracy Infinite Blades and Mantra helpers provide exact new base and upgrade displays',function()
 local function contains(data,id)for _,c in ipairs(data.cards.cards) do if c.id==id then return true end end end
 local silent=Profiles.prepare(Data,'silent')
 if not contains(silent,'accuracy') then silent=require('abyss_shivs').withCardDefinitions(silent) end
 if not contains(silent,'infinite_blades') then
  silent.cards.cards[#silent.cards.cards+1]={id='infinite_blades',type='power',rarity='uncommon',cost=1,
   effects={{op='gainStatus',status='infinite_blades',value=1}},upgrade={innate=true}}
 end
 local watcher=Profiles.prepare(Data,'watcher')
 if not contains(watcher,'prostrate') then watcher=require('abyss_mantra').withCards(watcher) end
 for _,input in ipairs({{data=silent,ids={'accuracy','infinite_blades'}},{data=watcher,ids={'prostrate','worship','devotion'}}}) do
  local display=P.prepare(Existing,input.data)
  local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
  local ui=BattleUI.new(root:GetChild('battlePanel'),input.data,display,'click',platform,{embedded=true})
  local deck={}
  for _,id in ipairs(input.ids) do
   for _,up in ipairs({false,true}) do
    local battle=C.new(input.data,{seed=42,deck={{cardId=id,upgraded=up}},enableStances=input.data.characterId=='watcher'})
    ui.run={phase='combat',combat=battle,data=input.data,relics={},potions={},gold=99};ui:render()
    local box=root:GetChild('battlePanel'):GetChild('card1');assert(#box:GetChild('label').text>0)
    deck[#deck+1]={uid=#deck+1,cardId=id,upgraded=up};rendered=rendered+1
   end
  end
  local deckUI=DeckUI.new(root:GetChild('deckPanel'),display,'click',platform,function()end)
  assert(deckUI:open({deck=deck,data=input.data}));deckUI:update()
  local grid=root:GetChild('deckPanel'):GetChild('grid')
  for i=1,#deck do assert(#grid:recycle(0,i-1):GetChild('face'):GetChild('label').text>0) end
 end
 local s=P.prepare(Existing,silent)
 assert(s.accuracy.text:find('4',1,true) and s.accuracy.upgradeText:find('6',1,true))
 assert(not s.infinite_blades.text:find('先天',1,true) and s.infinite_blades.upgradeText:find('先天',1,true))
 assert(s.infinite_blades.text:find('从下回合起',1,true) and s.infinite_blades.text:find('1',1,true))
 local w=P.prepare(Existing,watcher)
 assert(w.prostrate.text:find('2 层真言',1,true) and w.prostrate.upgradeText:find('3 层真言',1,true))
 assert(w.prostrate.text:find('4 点格挡',1,true) and w.prostrate.upgradeText:find('4 点格挡',1,true))
 assert(not w.worship.text:find('保留',1,true) and w.worship.upgradeText:find('保留',1,true));eq(w.worship.cost,'2')
 assert(w.devotion.text:find('2 层供奉',1,true) and w.devotion.upgradeText:find('3 层供奉',1,true))
 assert(w.devotion.text:find('每回合抽牌后',1,true) and not w.prostrate.text:find('首次',1,true))
end)
local function has(data,id)for _,c in ipairs(data.cards.cards)do if c.id==id then return true end end end
local extended={}
local function extendedData()
 if extended.ironclad then return extended end
 local w=Profiles.prepare(Data,'ironclad');if not has(w,'corruption') then w=require('abyss_warrior_exhaust_cards').withCards(w)end;extended.ironclad=w
 local s=Profiles.prepare(Data,'silent');if not has(s,'sneaky_strike') then s=require('abyss_silent_discard_cards').withCardDefinitions(s)end;extended.silent=s
 local d=Profiles.prepare(Data,'defect');if not has(d,'loop') then d=require('abyss_orb_powers').withCards(d)end;extended.defect=d
 local p=Profiles.prepare(Data,'watcher');if not has(p,'protect') then p=require('abyss_retained_cards').withCards(p)end;extended.watcher=p
 return extended
end
test('independent exhaust discard orb and retained helpers expose every new base and upgraded card',function()
 local ids={ironclad={'corruption','feel_no_pain','dark_embrace','sentinel','burning_pact'},
  silent={'sneaky_strike','eviscerate','calculated_gamble'},defect={'loop','electrodynamics'},
  watcher={'protect','perseverance','windmill_strike','sands_of_time'}}
 for _,id in ipairs({'ironclad','silent','defect','watcher'})do
  local data=extendedData()[id];local display=P.prepare(Existing,data)
  local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
  local ui=BattleUI.new(root:GetChild('battlePanel'),data,display,'click',platform,{embedded=true})
  local deck={}
  for _,cardId in ipairs(ids[id])do
   assert(has(data,cardId),'independent helper did not supply '..cardId)
   for _,up in ipairs({false,true})do
    local options={seed=42,deck={{cardId=cardId,upgraded=up}},enableStances=id=='watcher'}
    if id=='defect' then options.orbSlots=3;options.orbRandomSeed='17'end
    local battle=C.new(data,options)
    ui.run={phase='combat',combat=battle,data=data,relics={},potions={},gold=99};ui:render()
    local box=root:GetChild('battlePanel'):GetChild('card1');assert(#box:GetChild('name').text>0 and #box:GetChild('label').text>0)
    local definition=C.cardDefinition(battle,battle.hand[1]);local text=display[cardId]
    eq(up and text.upgradeCost or text.cost,string.format('%.0f',definition.cost))
    deck[#deck+1]={uid=#deck+1,cardId=cardId,upgraded=up};rendered=rendered+1
   end
  end
  local deckUI=DeckUI.new(root:GetChild('deckPanel'),display,'click',platform,function()end)
  assert(deckUI:open({deck=deck,data=data}));deckUI:update();local grid=root:GetChild('deckPanel'):GetChild('grid')
  for i=1,#deck do assert(#grid:recycle(0,i-1):GetChild('face'):GetChild('label').text>0)end
 end
end)
test('new effect order counts upgrades and historical keywords are not generic placeholders',function()
 local w=P.prepare(Existing,extendedData().ironclad)
 assert(w.corruption.text:find('耗能变为 0',1,true));eq(w.corruption.cost,'3');eq(w.corruption.upgradeCost,'2')
 assert(w.feel_no_pain.text:find('3 点固定格挡',1,true)and w.feel_no_pain.upgradeText:find('4 点固定格挡',1,true))
 assert(w.dark_embrace.text:find('抽 1 张牌',1,true));eq(w.dark_embrace.cost,'2');eq(w.dark_embrace.upgradeCost,'1')
 assert(w.sentinel.text:find('被消耗时，获得 2',1,true)and w.sentinel.upgradeText:find('被消耗时，获得 3',1,true))
 local choice=assert(w.burning_pact.text:find('选择并消耗',1,true));local draw=assert(w.burning_pact.text:find('抽 2',1,true));assert(choice<draw)
 local s=P.prepare(Existing,extendedData().silent)
 assert(s.sneaky_strike.text:find('12 点伤害',1,true)and s.sneaky_strike.upgradeText:find('16 点伤害',1,true));eq(s.sneaky_strike.cost,'2')
 assert(s.sneaky_strike.text:find('若本回合主动弃过牌',1,true)and s.sneaky_strike.text:find('2 点能量',1,true))
 assert(s.eviscerate.text:find('7 点伤害，重复 3 次',1,true)and s.eviscerate.upgradeText:find('9 点伤害，重复 3 次',1,true))
 assert(s.eviscerate.text:find('费用降低 1',1,true))
 assert(s.calculated_gamble.text:find('其余所有手牌，再抽等量牌',1,true)and s.calculated_gamble.text:find('消耗',1,true))
 assert(not s.calculated_gamble.upgradeText:find('消耗',1,true))
 local d=P.prepare(Existing,extendedData().defect)
 assert(d.loop.text:find('1 层循环',1,true)and d.loop.upgradeText:find('2 层循环',1,true))
 assert(d.electrodynamics.text:find('生成 2 个闪电球',1,true)and d.electrodynamics.upgradeText:find('生成 3 个闪电球',1,true))
 local p=P.prepare(Existing,extendedData().watcher)
 assert(p.perseverance.text:find('格挡增加 2',1,true)and p.perseverance.upgradeText:find('格挡增加 3',1,true))
 assert(p.windmill_strike.text:find('伤害增加 4',1,true)and p.windmill_strike.upgradeText:find('伤害增加 5',1,true))
 assert(p.sands_of_time.text:find('费用降低 1',1,true));eq(p.sands_of_time.cost,'4')
end)
test('unknown new exhaust or orb Power remains a rejection',function()
 for _,op in ipairs({'gainExhaustPower','gainOrbPower'})do
  local data=C.copy(extendedData().defect);data.cards.cards[4].effects={{op=op,status='invented',value=1}}
  assert(not pcall(P.prepare,Existing,data))
 end
end)
test('retained growth is read from real CardDefinition and CardPreview after a real turn',function()
 local data=extendedData().watcher;local display=P.prepare(Existing,data)
 local cases={{id='perseverance',base=5,up=7,step=2,upStep=3},{id='windmill_strike',base=7,up=10,step=4,upStep=5}}
 for _,case in ipairs(cases)do
  for _,up in ipairs({false,true})do
   local battle=C.new(data,{seed=42,deck={{cardId=case.id,upgraded=up}},enableStances=true})
   local instance=battle.hand[1];assert(C.endTurn(battle));eq(battle.hand[1],instance)
   local expected=(up and case.up or case.base)+(up and case.upStep or case.step)
   local definition=C.cardDefinition(battle,instance);eq(definition.effects[1].value,expected)
   local preview=C.cardPreview(battle,instance,1);eq(preview[1].low,expected)
   local text=display[case.id];local template=up and text.upgradeCombatText or text.combatText
   local shown=Display.format(template,definition,preview,Theme.color)
   assert(shown:find(string.format('%.0f',expected)..' 点',1,true))
   local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
   local ui=BattleUI.new(root:GetChild('battlePanel'),data,display,'click',platform,{embedded=true})
   ui.run={phase='combat',combat=battle,data=data,relics={},potions={},gold=99};ui:render()
   assert(root:GetChild('battlePanel'):GetChild('card1'):GetChild('label').text:find(string.format('%.0f',expected)..' 点',1,true))
  end
 end
end)
test('Sands and Eviscerate live costs come from Combat overrides while presentation stores base cost',function()
 local data=extendedData().watcher;local presentation=P.prepare(Existing,data)
 local s=C.new(data,{seed=42,deck={'sands_of_time'},enableStances=true})
 local instance=s.hand[1];assert(C.endTurn(s));eq(C.cardDefinition(s,instance).cost,3);eq(presentation.sands_of_time.cost,'4')
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local ui=BattleUI.new(root:GetChild('battlePanel'),data,presentation,'click',platform,{embedded=true})
 ui.run={phase='combat',combat=s,data=data,relics={},potions={},gold=99};ui:render()
 eq(root:GetChild('battlePanel'):GetChild('card1'):GetChild('cost').text,'3')
 local d=extendedData().silent;local shown=P.prepare(Existing,d)
 local battle=C.new(d,{seed=42,deck={'eviscerate','prepared','defend_green'}})
 local evis,prepared,defend
 for _,c in ipairs(battle.hand)do if c.cardId=='eviscerate'then evis=c elseif c.cardId=='prepared'then prepared=c else defend=c end end
 assert(C.play(battle,prepared.uid));assert(battle.pendingDiscard)
 assert(require('abyss_discard').choose(battle,{defend.uid},battle.pendingDiscard.token,C))
 eq(C.cardDefinition(battle,evis).cost,2);eq(shown.eviscerate.cost,'3')
 local r=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local u=BattleUI.new(r:GetChild('battlePanel'),d,shown,'click',platform,{embedded=true})
 u.run={phase='combat',combat=battle,data=d,relics={},potions={},gold=99};u:render()
 local slot;for i,c in ipairs(battle.hand)do if c==evis then slot=i end end
 eq(r:GetChild('battlePanel'):GetChild('card'..slot):GetChild('cost').text,'2')
end)
print('CHARACTER_PRESENTATION_PASS '..cases..' rendered_card_variants='..rendered)
