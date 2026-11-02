local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Provider=require('abyss_compendium_catalog')
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local calls,create=0,Provider.new
Provider.new=function(...)calls=calls+1;return create(...)end
Run.new=function()error('read-only host must not construct a Run')end
for name,value in pairs(Random)do if type(value)=='function'then
 Random[name]=function()error('read-only host must not invoke RNG '..name)end
end end
math.random=function()error('read-only host must not use math.random')end
math.randomseed=function()error('read-only host must not reseed randomness')end
local ui,root=F.fixture()
assert(calls==0,'constructing the game host must not eagerly build a compendium')
assert(ui.run==nil and ui.mode=='menu' and not ui.characterOpen)
local selected=ui.characterSelection.info
local menu=root:GetChild('menuPanel')
local visible=menu.visible
assert(type(ui.productionCompendium)=='function','production host has no compendium data API')
local catalog=ui:productionCompendium()
assert(calls==1 and #catalog:list('cards')==356 and #catalog:list('relics')==149 and #catalog:list('potions')==33)
assert(catalog:card('strike',true).definition.effects[1].value==9)
assert(catalog:card('blade_dance')and not catalog:card('strike_green'))
local card=catalog:card('strike');card.definition.effects[1].value=999
local second=ui:productionCompendium()
assert(second~=catalog and second:card('strike').definition.effects[1].value==6)
assert(ui.run==nil and ui.mode=='menu' and ui.characterSelection.info==selected and not ui.characterOpen)
assert(menu.visible==visible,'data query must not navigate or change visible controls')
print('COMPENDIUM_HOST_API_PASS lazy production query, no Run/RNG, detached data and unchanged menu')
