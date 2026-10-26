package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run');local C=require('abyss_combat');local Actions=require('abyss_card_actions')
local data=require('abyss_data');local Colorless=require('abyss_colorless_cards')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local r=Run.new(data,19);assert(not data.colorlessCards);eq(#r.data.cards.sourcePools.srcColorless,35)
eq(Colorless.withCards(r.data),r.data)
r.deck={{cardId='ritual_dagger',uid=31,upgraded=false}};r.relics={}
assert(Run.startCombat(r,'cultist_solo'));local c=r.combat.hand[1];eq(c.deckUid,31)
r.combat.enemies[1].hp=1;assert(Run.play(r,c.uid,1));eq(r.deck[1].misc,18)
assert(not Run.finishCombat(r));eq(r.deck[1].misc,18)
r.phase='map';assert(Run.startCombat(r,'cultist_solo'));c=r.combat.hand[1];eq(C.cardDefinition(r.combat,c).effects[1].damage,18)
local duplicate=Actions.fresh(C,r.combat,c.cardId,c);assert(duplicate.deckUid==nil)
r.combat.hand[#r.combat.hand+1]=duplicate;r.combat.enemies[1].hp=1
assert(Run.play(r,duplicate.uid,1));eq(r.deck[1].misc,18)
local presentation=require('abyss_character_presentation').prepare(require('abyss_presentation'),r.data)
for _,id in ipairs(r.data.cards.sourcePools.srcColorless)do assert(presentation[id].text~='');assert(presentation[id].upgradeText~='')end
print('ok colorless permanent growth, copy identity, pool ownership, and readable cards')
