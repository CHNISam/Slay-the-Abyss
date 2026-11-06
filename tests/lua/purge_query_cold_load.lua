package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
assert(package.searchpath('abyss_purge_candidates',package.path),'[PURGE_QUERY_COLD] missing pure abyss_purge_candidates leaf')
for _,name in ipairs({'abyss_run','abyss_transform_card','abyss_card_capability','abyss_event_transform_context','abyss_living_wall'})do
 assert(package.loaded[name]==nil,'[PURGE_QUERY_COLD] VM must begin cold')
 package.preload[name]=function()error('[PURGE_QUERY_COLD] candidate query loaded forbidden '..name,0)end
end
local Candidates=require('abyss_purge_candidates')
local owner={deck={{uid=1,cardId='strike'},{uid=2,cardId='Necronomicurse'}}}
local rows=Candidates.purgeCards(owner)
assert(#rows==1 and rows[1].uid==1 and rows[1]~=owner.deck[1],'[PURGE_QUERY_COLD] filtering/copy contract')
assert(package.loaded.abyss_copy~=nil,'[PURGE_QUERY_COLD] existing Copy capability required')
print('PURGE_QUERY_COLD_PASS Copy-only candidate query')
