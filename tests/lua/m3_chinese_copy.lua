local F=dofile('tests/lua/support/game_ui_fixture.lua')
local h,r=F.fixture();assert(F.start(h))
local CardDisplay=require('abyss_card_display')
for _,d in ipairs(h.run.data.cards.cards)do
 local p=F.Presentation[d.id]
 if p then
  for _,upgraded in ipairs({false,true})do
   local text=CardDisplay.permanentText(p,d,{cardId=d.id,upgraded=upgraded})
   assert(not text:find('打击类牌。',1,true),'redundant strike tag in normal body '..d.id)
   assert(not text:gsub('<[^>]*>',''):find('[A-Za-z][A-Za-z]'),'English effect text '..d.id)
   assert(not text:find('TODO',1,true) and not text:find('TBD',1,true),'placeholder '..d.id)
  end
 end
end
local RelicNames=require('abyss_relic_names')
assert(RelicNames.get(h.run.data,'chemical_x')=='化学物质零号')
for _,d in ipairs(h.run.data.relics.relics)do
 -- Reward/node labels use the display resolver, not the raw source label.
 local name=RelicNames.get(h.run.data,d.id)
 assert(name:find('[\228-\233]') and not name:find('[A-Za-z]'),'non-Chinese relic name '..d.id)
 local text=h.nodeUI:describeRelic(h.run,d.id)
 assert(text~='' and text:find('[\228-\233]') and not text:find('[A-Za-z][A-Za-z]'),'non-Chinese relic effect '..d.id)
end
assert(h:openMenu())
local menu=r:GetChild('runMenu')
local run,map=h.run,h.map
local hp,gold,deck,relics=run.hp,run.gold,run.deck,run.relics
assert(menu:GetChild('help').visible,'approved menu help must be discoverable')
assert(menu:GetChild('help'):GetChild('hit').click())
local guide=r:GetChild('exitPanel'):GetChild('guide')
assert(h.controlsOpen and guide.visible)
assert(guide:GetChild('battle'):GetChild('how4').text=='点击右下角「结束回合」')
assert(guide:GetChild('map'):GetChild('how4').text=='先点商品查看详情，再确认购买')
assert(not h:confirmExit() and not menu:GetChild('abandon'):GetChild('hit').click())
assert(guide:GetChild('close'):GetChild('hit').click() and h.menuOpen and not h.controlsOpen)
assert(menu:GetChild('abandon'):GetChild('hit').click())
local exit=r:GetChild('exitPanel')
assert(exit:GetChild('help').visible,'approved exit help must be discoverable')
assert(exit:GetChild('help'):GetChild('hit').click() and h.controlsOpen and guide.visible)
assert(not exit:GetChild('confirm'):GetChild('hit').click())
assert(guide:GetChild('close'):GetChild('hit').click() and h.exitOpen and not h.controlsOpen)
assert(h.run==run and h.map==map and run.hp==hp and run.gold==gold and run.deck==deck and run.relics==relics)
assert(exit:GetChild('message').text:find('无法恢复',1,true))
assert(exit:GetChild('whyText').text:find('帮助作者提升等级',1,true),'Owner exact copy must remain')
assert(exit:GetChild('cancel'):GetChild('hit').click())
assert(not h.exitOpen and not h.controlsOpen)
print('M3_CHINESE_COPY_PASS')
