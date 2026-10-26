package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R,P=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_character_profiles')
local function same(a,b)
 if type(a)~='table' or type(b)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function oracle(state,kind,rng)
 local pools=state.sourcePools;local ids={}
 for _,rarity in ipairs({'common','uncommon','rare'})do for _,id in ipairs(pools.src[rarity])do
  local meta=assert(pools.cardSourceMetadata[id]);if meta.type==kind and not meta.healing then ids[#ids+1]=id end
 end end
 local result,seen={},{}
 while #result<3 do local id=ids[R.randomInt(rng,#ids-1)+1];if not seen[id]then seen[id]=true;result[#result+1]=id end end
 return result
end
for _,case in ipairs({{148,'skill_potion','skill'},{38,'attack_potion','attack'}})do
 local run=Run.new(D,tostring(case[1]),{character='watcher',experimental=true});assert(Run.startCombat(run,'cultist_solo'))
 local state=run.combat;local mother=C.copy(state.sourcePools.src);local expectedRng=R.cloneState(state.cardRandomRng)
 local expected=oracle(state,case[3],expectedRng);assert(Run.obtainPotion(run,case[2]));assert(Run.usePotion(run,1))
 local p=assert(state.pendingChoice)
 for i,c in ipairs(p.cards)do assert(c.cardId==expected[i],'real potion generation must use source HEALING exclusion: seed'..case[1]);assert(c.cardId~='wish' and c.cardId~='lesson_learned')end
 assert(same(R.snapshot(state.cardRandomRng),R.snapshot(expectedRng)),'source RNG words and counter match first group')
 oracle(state,case[3],expectedRng);assert(Run.chooseCard(run,p.token,1))
 assert(same(R.snapshot(state.cardRandomRng),R.snapshot(expectedRng)),'Discovery retrieval consumes exactly one unused second group')
 assert(same(state.sourcePools.src,mother),'HEALING excludes generation without deleting from mother pools')
end
local data=P.prepare(D,'watcher');local cards={};for _,c in ipairs(data.cards.cards)do cards[c.id]=c end
local count=0;for id,meta in pairs(data.cards.sourcePools.cardSourceMetadata)do
 assert((assert(cards[id]).healing==true)==meta.healing,'actual Watcher definition HEALING mismatch: '..id);count=count+1
end
assert(count==71 and cards.wish.healing and cards.lesson_learned.healing)
print('WATCHER_HEALING_GENERATION_SOURCE real seeds148/38, source RNG words/counters, all71 definition tags and unchanged mother pools passed')
