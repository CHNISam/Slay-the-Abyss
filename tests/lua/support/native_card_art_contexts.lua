package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Run,Map,Nodes=require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local Display=require('abyss_card_display')
local DeckUI,NodeUI=require('abyss_deck_ui'),require('abyss_node_ui')
local platform={imageSource='static',imageTypes={basic=17,stretch=23},color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local function pool()
 return {name='artSamples',kind='container',visible=false,children={{name='group000',kind='container',children={
  {name='shape0000',kind='image',size={1,1},visible=false},{name='shape0001',kind='image',size={1,1},visible=false}}}}}
end
local function metadata(id,n)
 local slots={};for i=1,n do slots[i]={image=i==1 and 106056 or 106057,position={i,2},size={3,4},rotation={20,30,40},
  pivot={.5,.5},anchorMin={.5,.5},anchorMax={.5,.5},scale={1,1},colour={11,22,33,44},imageType='basic'}end
 return {cardId=id,luaSha256=id,capacity=2,slots=slots}
end
F.Presentation.cleave.nativeArt=metadata('cleave',2)
F.Presentation.heavy_blade.nativeArt=metadata('heavy_blade',1)
-- The real recyclable deck template gets a synthetic two-slot pool only here;
-- native candidate generation deliberately leaves this unbounded template off.
for _,entry in pairs(F.Templates)do for _,c in ipairs(entry.children or {})do
 if c.name=='face'then c.children[#c.children+1]=pool()end
end end
local function root()
 local r=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 for _,face in ipairs({r:GetChild('battlePanel'):GetChild('card1'),r:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1'),
  r:GetChild('nodePanel'):GetChild('pickerView'):GetChild('card1')})do face.children.artSamples=F.control(pool(),face)end
 return Native.decorate(r)
end
local run=Run.new(F.Data,42);run.deck={{uid=91,cardId='cleave',upgraded=true}}
assert(Run.startCombat(run,'cultist_solo'))
local BattleUI=require('abyss_battle_ui')
local r=root();local battle=BattleUI.new(r:GetChild('battlePanel'),run.data,F.Presentation,'click',platform,{embedded=true})
battle.run=run;battle:render()
local face=r:GetChild('battlePanel'):GetChild('card1')
local function art(face,enabled,node)
 assert(face:GetChild('artSamples').visible==enabled,'real shared host was not bound/cleared')
 if node then
  local visible=0;for key in pairs(F.Theme.icon.cardArt)do if face:GetChild('art_'..key).visible then visible=visible+1 end end
  assert(visible==(enabled and 0 or 1),'node art_* fallback stale')
 else assert(face:GetChild('art').visible~=enabled,'fallback visibility stale')end
end
art(face,true)
local name=face:GetChild('name').text
assert(name:find(F.Presentation.cleave.name,1,true) and name:find('＋',1,true),'upgrade title independent')
assert(face:GetChild('cost').text=='1' and face:GetChild('type').text=='攻击')
local baseText=face:GetChild('label').text
run.combat.player.statuses.strength=7;battle:render()
assert(face:GetChild('label').text~=baseText,'Combat.cardPreview dynamic value not refreshed')
assert(face:GetChild('name').text==name,'dynamic rules overwrote independent title')
run.combat.hand[1].cardId='heavy_blade';battle:render();art(face,true)
assert(not face:GetChild('artSamples'):GetChild('group000'):GetChild('shape0001').visible,'large-to-small tail')
run.combat.hand[1].cardId='strike';battle:render();art(face,false)
run.combat.hand[1].cardId='cleave';battle:render();art(face,true)
run.combat.hand={};battle:render();assert(not face:GetChild('artSamples').visible,'empty slot not cleared')
for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
assert(Run.finishCombat(run));run.rewards.cards={'cleave'};run.rewards.cardUpgrades={true}
battle:render();battle.rewardScreen='cards';battle:render();art(face,true)
run.rewards.cards={'strike'};battle:render();art(face,false)
local deck=DeckUI.new(r:GetChild('deckPanel'),F.Presentation,'click',platform,function()end)
for i=1,3 do
 run.deck={{uid=91,cardId=i==2 and 'heavy_blade' or 'cleave',upgraded=i==3}}
 assert(deck:open(run));deck:update()
 local grid=r:GetChild('deckPanel'):GetChild('grid');local item=grid.items[0];local f=item:GetChild('face')
 art(f,true);local stale=grid.refreshCallback
 assert(deck:close());assert(not f:GetChild('artSamples').visible,'deck close did not clear pool')
 stale(item,0);assert(not f:GetChild('artSamples').visible,'late grid callback revived closed art')
end
local shop=Run.new(F.Data,42);local map=Map.generate(shop.data,42)
for _=1,17 do
 local choices,found=Map.available(map),false
 for _,node in ipairs(choices)do if node.type=='shop'then assert(Nodes.enter(shop,map,node.id));found=true;break end end
 if found then break end;assert(Map.choose(map,assert(choices[1]).id))
end
shop.nodeFlow.cards[1].id='cleave'
local node=NodeUI.new(r:GetChild('nodePanel'),shop,map,F.Presentation,'click',function()end,platform)
node:render();local offer=r:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1');art(offer,true,true)
shop.nodeFlow.cards[1].id='heavy_blade';node:render();art(offer,true,true)
shop.nodeFlow.cards[1].id='defend';node:render();art(offer,false,true)
shop.nodeFlow.cards[1].id='cleave';node:render();art(offer,true,true)
node:setVisible(false);assert(not offer:GetChild('artSamples').visible,'node hide not cleared')
node:setVisible(true);node:render();art(offer,true,true)
shop.deck={{uid=99,cardId='cleave',upgraded=true}}
node.mode,node.picker,node.pickPage='picker','remove',1;node:render()
art(r:GetChild('nodePanel'):GetChild('pickerView'):GetChild('card1'),true,true)
assert(not offer:GetChild('artSamples').visible,'page switch left unused shop art active')
node.mode,node.picker='main',nil;node:render()
assert(not r:GetChild('nodePanel'):GetChild('pickerView'):GetChild('card1'):GetChild('artSamples').visible,'picker art survived page switch')
-- Construct the actual root GameUI, whose NodeUI options are a filtered table.
local GameUI=require('abyss_game_ui')
local hostRoot=root()
local host=GameUI.new(hostRoot,F.Data,F.Presentation,'click',platform)
host.run,host.map,host.mode=shop,map,'node'
host.nodeUI.run,host.nodeUI.map=shop,map;host:refresh()
art(hostRoot:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1'),true,true)
print('NATIVE_CARD_ART_CONTEXTS_PASS battle/reward/deck/shop; four-live-texts/dynamic-preview/recycle/art_*')
