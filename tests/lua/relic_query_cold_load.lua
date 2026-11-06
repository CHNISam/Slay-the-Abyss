package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Pool=require('abyss_card_pool')
assert(package.loaded.abyss_actor==nil,'[RELIC_QUERY_COLD] loading CardPool eagerly loaded Actor')
local owner={relics={'Question Card','Busted Crown'}}
assert(Pool.rewardCount(owner,3)==2,'[RELIC_QUERY_COLD] reward query returned wrong quantity')
assert(package.loaded.abyss_actor==nil,'[RELIC_QUERY_COLD] reward query loaded Actor execution module')
assert(package.loaded.abyss_relic_hooks==nil,'[RELIC_QUERY_COLD] reward query loaded mixed Hooks facade')
assert(package.loaded.abyss_boss_relics==nil,'[RELIC_QUERY_COLD] reward query loaded mixed Boss facade')
print('RELIC_QUERY_COLD_PASS')
