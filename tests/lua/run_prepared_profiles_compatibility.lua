package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,P,C,D=require('abyss_run'),require('abyss_character_profiles'),require('abyss_combat'),require('abyss_data')
local function same(a,b)
 if type(a)~='table'or type(b)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
-- Observed with exact01c1f94f Run/Combat/Profile modules: all constructors
-- succeed; Defect alone retains unsupported_starting_orb without a profile.
for _,id in ipairs({'watcher','silent','defect','ironclad'})do
 local source=P.prepare(D,id);local before=C.copy(source)
 local r=Run.new(source,42)
 assert(r.data~=source and r.data.rules~=source.rules and r.data.cards.cards~=source.cards.cards)
 assert(r.character==nil and r.characterProfile==nil and r.originalCommands==nil)
 assert(r.data.experimentalCharacter==id and r.hp==source.rules.player.maxHp and #r.deck==#source.cards.starter_deck.cards)
 assert(not r.data.runCardCatalog and not r.data.runCardCharacter)
 same(r.data.rules,source.rules);same(r.data.cards.starter_deck,source.cards.starter_deck)
 for _,key in ipairs({'reward','src','shop'})do same(r.data.cards.sourcePools[key],source.cards.sourcePools[key])end
 local count=0;for _,c in ipairs(r.data.cards.cards)do if c.color==({watcher='purple',silent='green',defect='blue',ironclad='red'})[id]and c.rarity~='special'then count=count+1 end end
 assert(count==(id=='ironclad'and 66 or 75),'legacy prepared data is not rebuilt as a full catalogue')
 local ok,reason=Run.startCombat(r,'cultist_solo')
 if id=='defect'then assert(not ok and reason=='unsupported_starting_orb')
 else assert(ok,reason);assert(r.combat.experimentalCharacter==id and not r.combat.orbs and not r.combat.player.stance)end
 same(source,before)
 -- Caller catalogue flags never authorize an owned registration or switch the
 -- legacy combat defaults. The complete input still gets a private copy.
 source.runCardCatalog=true;source.runCardCharacter='defect'
 local markedBefore=C.copy(source);local marked=Run.new(source,43,{experimental=true})
 assert(marked.data~=source and not marked.data.runCardCatalog and not marked.data.runCardCharacter)
 assert(marked.character==nil and marked.characterProfile==nil)
 ok,reason=Run.startCombat(marked,'cultist_solo')
 if id=='defect'then assert(not ok and reason=='unsupported_starting_orb')else assert(ok,reason);assert(not marked.combat.orbs)end
 same(source,markedBefore)
end
print('RUN_PREPARED_PROFILES_COMPATIBILITY_PASS historical four prepared constructors/resources/pools/start outcomes, no inferred profile and no caller-flag ownership')
