package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,P,D=require('abyss_run'),require('abyss_combat'),require('abyss_character_presentation'),require('abyss_data')
local r=Run.new(D,42);local text=P.prepare(require('abyss_presentation'),r.data)
local supported=require('abyss_card_capability').isImplemented;local count=0
for _,card in ipairs(r.data.cards.cards)do
 local view=assert(text[card.id]);assert(#view.name>0 and #view.text>0 and #view.upgradeText>0)
 assert(view.name:find('[\128-\255]')and not view.text:find('{effects',1,true)and not view.upgradeText:find('{effects',1,true))
 assert(view.type==card.type)
 if({red=true,green=true,blue=true,purple=true})[card.color]and card.rarity~='special'then
  local up=C.copy(card);for k,v in pairs(card.upgrade or{})do up[k]=C.copy(v)end
  assert(supported(card)and supported(up),'both actual variants must be implemented: '..card.id);count=count+1
 end
end
assert(count==300)
assert(text.whirlwind.cost=='X'and text.burn.upgradeText:find('4',1,true))
print('RUN_CARD_CATALOG_PRESENTATION_PASS complete Run300/600 capability, real base/upgraded text and native9 display ABI')
