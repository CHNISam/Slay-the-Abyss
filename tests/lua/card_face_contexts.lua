local function plainCardTitle(text)return (text:gsub('<color=#[%x]+>',''):gsub('</color>',''))end
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map,Nodes=require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local P=require('abyss_character_presentation')
local BattleUI,DeckUI,NodeUI=require('abyss_battle_ui'),require('abyss_deck_ui'),require('abyss_node_ui')
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
F.withMonsterActors(platform)
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local run=Run.new(F.Data,42,{character='furina'})
local presentation=P.prepare(F.Presentation,run.data)
local function assertLong(face,upgraded,context)
 local name,kind=face:GetChild('name'),face:GetChild('type')
 assert(name.text=='恰到好处的停顿' and name.fontSize==14,context..' lost readable full title')
 assert(plainCardTitle(kind.text)==(upgraded and '技能 ＋' or '技能'),context..' lost or duplicated upgrade marker')
 assert(name.fontColor.r==255 and name.fontColor.g==255 and name.fontColor.b==255,context..' title must remain white')
 if upgraded then assert(kind.text=='技能 <color=#8DE08A>＋</color>',context..' only the relocated marker is green')end
 assert(name.sizeDeltaY==40 and kind.sizeDeltaY==40,context..' lost native transparent text compatibility')
 assert(face:GetChild('artPlate').sizeDeltaX==144 and face:GetChild('artPlate').sizeDeltaY==64,context..' aperture changed')
end
run.deck={{uid=91,cardId='FR2-053',upgraded=true}}
assert(Run.startCombat(run,'cultist_solo'))
local battle=BattleUI.new(root:GetChild('battlePanel'),run.data,presentation,'click',platform,{embedded=true})
battle.run=run;battle:render()
assertLong(root:GetChild('battlePanel'):GetChild('card1'),true,'battle')
local deck=DeckUI.new(root:GetChild('deckPanel'),presentation,'click',platform,function()end)
assert(deck:open(run));deck:update()
assertLong(root:GetChild('deckPanel'):GetChild('grid').items[0]:GetChild('face'),true,'deck')
assert(deck:close())
for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
assert(Run.finishCombat(run))
-- A controlled reward fixture selects the real long card; rendering still goes
-- through the production reward face, not a test-only title writer.
run.rewards.cards={'FR2-053'};run.rewards.cardUpgrades={true}
battle.rewardScreen='cards';battle:render()
assertLong(root:GetChild('battlePanel'):GetChild('card1'),true,'reward')
local shopRun=Run.new(F.Data,42,{character='furina'})
local map=Map.generate(shopRun.data,42)
for _=1,17 do
 local choices,found=Map.available(map),false
 for _,node in ipairs(choices)do if node.type=='shop' then assert(Nodes.enter(shopRun,map,node.id));found=true;break end end
 if found then break end
 assert(Map.choose(map,assert(choices[1]).id))
end
shopRun.nodeFlow.cards[1].id='FR2-053'
local node=NodeUI.new(root:GetChild('nodePanel'),shopRun,map,presentation,'click',function()end,platform)
node:render()
assertLong(root:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1'),false,'shop')
-- Reusing the actual battle/deck slots must clear the relocated marker. X costs
-- and repeatable upgrade counts retain their existing rule-derived values.
local traveler=Run.new(F.Data,42)
local text=P.prepare(F.Presentation,traveler.data)
traveler.deck={{uid=1,cardId='whirlwind',upgraded=true}}
assert(Run.startCombat(traveler,'cultist_solo'))
battle:setData(traveler.data,text);battle.run=traveler;battle:render()
local face=root:GetChild('battlePanel'):GetChild('card1')
assert(face:GetChild('cost').text=='X' and face:GetChild('type').text=='攻击')
assert(plainCardTitle(face:GetChild('name').text)==text.whirlwind.name..'＋')
traveler.deck={{uid=2,cardId='searing_blow',upgraded=true,upgrades=999}}
deck:setPresentation(text);assert(deck:open(traveler));deck:update()
face=root:GetChild('deckPanel'):GetChild('grid').items[0]:GetChild('face')
assert(plainCardTitle(face:GetChild('name').text)==text.searing_blow.name..'＋999')
assert(face:GetChild('type').text=='攻击' and face:GetChild('cost').text=='2')
print('LUA_CARD_FACE_CONTEXTS_PASS battle/reward/deck/shop; long upgrade, X cost, repeat upgrade, recycled marker')
