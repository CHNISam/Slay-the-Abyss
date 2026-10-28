package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Rewards=require('abyss_relic_rewards')
local reads=0
local cards,deck={},{}
for i=1,64 do
 local row={id='card_'..i,type=i%2==0 and 'skill' or 'attack',rarity=i%3==0 and 'rare' or 'common'}
 cards[i]=setmetatable({},{__index=function(_,key)if key=='id'then reads=reads+1 end;return row[key]end})
 deck[i]={cardId=row.id}
end
local run={data={cards={cards=cards},relics={relics={}}},deck=deck,relics={},act=2,floor=24}
local context=Rewards.context(run)
assert(#context.deck==64 and context.act==2 and context.floor==24 and context.room=='monster')
for i,row in ipairs(context.deck)do
 assert(row.type==(i%2==0 and 'SKILL' or 'ATTACK') and row.rarity==(i%3==0 and 'RARE' or 'COMMON'))
end
assert(reads<=#cards*2+#deck,'relic context rescans the complete card catalogue per owned card: '..reads)
print('RELIC_CONTEXT_LINEAR_LOOKUPS '..reads)

local definitions={{id='same',type='attack',rarity='common'},{id='same',type='power',rarity='rare'}}
run.data.cards.cards=definitions;run.deck={{cardId='same'},{cardId='missing'},{cardId='same'}}
local first=Rewards.context(run,{floor=48,room='shop'})
assert(#first.deck==2 and first.deck[1].type=='ATTACK' and first.deck[2].rarity=='COMMON')
assert(first.floor==48 and first.room=='shop' and run.floor==24,'context cannot change Run')
definitions[1].type='skill';definitions[1].rarity='uncommon'
local changed=Rewards.context(run)
assert(changed.deck[1].type=='SKILL' and changed.deck[1].rarity=='UNCOMMON','catalogue changes must be observed without stale caches')
first.deck[1].type='EXTERNAL'
assert(changed.deck[1].type=='SKILL' and definitions[1].type=='skill','returned context remains detached')
assert(#Rewards.context({deck={},relics={},act=1,floor=1}).deck==0,'empty decks need no card catalogue')
print('RELIC_CONTEXT_LOOKUP_PASS first-match/missing/order/current-catalogue/detached/empty')
