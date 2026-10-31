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
for _,d in ipairs(h.run.data.relics.relics)do
 assert(d.name:find('[\228-\233]') and not d.name:find('[A-Za-z]'),'non-Chinese relic name '..d.id)
 local text=h.nodeUI:describeRelic(h.run,d.id)
 assert(text~='' and text:find('[\228-\233]') and not text:find('[A-Za-z][A-Za-z]'),'non-Chinese relic effect '..d.id)
end
assert(h:openMenu())
local menu=r:GetChild('runMenu')
assert(menu:GetChild('help').visible==false,'menu help must be removed')
assert(not menu:GetChild('help'):GetChild('hit').click(),'hidden help must reject stale/direct click')
assert(menu:GetChild('abandon'):GetChild('hit').click())
local exit=r:GetChild('exitPanel')
assert(exit:GetChild('help').visible==false)
assert(not exit:GetChild('help'):GetChild('hit').click())
assert(exit:GetChild('message').text:find('无法恢复',1,true))
assert(exit:GetChild('whyText').text:find('帮助作者提升等级',1,true),'Owner exact copy must remain')
assert(exit:GetChild('cancel'):GetChild('hit').click())
assert(not h.exitOpen and not h.controlsOpen)
print('M3_CHINESE_COPY_PASS')
