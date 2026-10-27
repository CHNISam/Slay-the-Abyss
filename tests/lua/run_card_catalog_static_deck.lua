package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/helpers/?.lua;'..package.path
local H=require('run_catalog');local C=H.C
local P=require('abyss_character_presentation')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local r,s=H.new({'swivel','strike_blue'});H.play(r,'swivel')
local held=H.held(s,'strike_blue');assert(C.cardDefinition(s,held).cost==0,'actual acquired FreeAttackPower still adapts combat cost')
local text=P.prepare(require('abyss_presentation'),r.data)
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local platform={imageSource='static',color=function(red,green,blue,alpha)return{red,green,blue,alpha}end}
local ui=require('abyss_deck_ui').new(root:GetChild('deckPanel'),text,'click',platform,function()end)
assert(ui:open(r));ui:update()
local grid=root:GetChild('deckPanel'):GetChild('grid')
for i,c in ipairs(r.deck)do
 local face=grid:recycle(0,i-1):GetChild('face')
 assert(face:GetChild('cost').text==(c.cardId=='swivel'and '2'or '1'))
 assert(#face:GetChild('name').text>0 and #face:GetChild('label').text>0)
end
local catalog={};for _,c in ipairs(r.data.cards.cards)do catalog[c.id]=c end
local lookup={catalog={cards=catalog}}
assert(C.cardDefinition(lookup,{cardId='strike_blue'}).cost==1,'permanent deck lookup has no combat player or transient Power')
local upgraded=C.cardDefinition(lookup,{cardId='swivel',upgraded=true})
assert(upgraded.cost==2 and upgraded.effects[1].value==11,'upgraded permanent values are resolved without a combat player')
assert(C.cardDefinition(lookup,{cardId='white_noise',upgraded=true}).cost==0,'an actual upgrade cost change is resolved without a player')
assert(C.cardDefinition(s,held).cost==0 and s.player.statuses.free_attack==1,'static deck lookup must not consume or mutate the real Power')
print('RUN_CARD_CATALOG_STATIC_DECK_PASS actual DeckUI without player and combat-only FreeAttackPower cost remain distinct')
