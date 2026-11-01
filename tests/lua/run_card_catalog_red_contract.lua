package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Contract,C,D=require('abyss_run_red_card_contract'),require('abyss_combat'),require('abyss_data')
local count=0;local strike
for _,c in ipairs(D.cards.cards)do if c.type~='status'and c.type~='curse'and c.rarity~='special'then
 assert(Contract.isRed(c.id)and Contract.matches(c),'frozen native red mismatch: '..c.id);count=count+1
 if c.id=='strike'then strike=C.copy(c)end
end end
assert(count==75 and not Contract.isRed('cold_snap'))
local graph={};graph.self=graph;strike.callerGraph=graph;strike.name='当前词条'
assert(Contract.matches(strike),'wording and caller extension graphs are excluded')
strike.effects[1].value=123;assert(not Contract.matches(strike),'actual damage must participate')
strike.effects[1].value=6;strike.requiresNoOtherAttack=true
assert(not Contract.matches(strike,{requiresNoOtherAttack=true}),'known extra gameplay fields cannot bypass the native ABI contract')
print('RUN_CARD_CATALOG_RED_CONTRACT_PASS all frozen75 hashes, real semantic negatives and metadata/cycle exclusion')
