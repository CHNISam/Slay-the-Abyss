package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,P,D=require('abyss_run'),require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data')
local function same(a,b)
 if type(a)~='table'or type(b)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'unexpected field '..tostring(k))end
end
local function find(data,id)for _,c in ipairs(data.cards.cards)do if c.id==id then return c end end;error('missing '..id)end
for _,spec in ipairs({{label='default'},{label='ironclad',id='ironclad'},{label='silent',id='silent'},{label='defect',id='defect'},{label='watcher',id='watcher'}})do
 local raw=spec.id and P.prepare(D,spec.id)or D
 local r=Run.new(D,42,spec.id and {character=spec.id,experimental=true}or nil)
 local colors={red=0,green=0,blue=0,purple=0};local native=0
 for _,c in ipairs(r.data.cards.cards)do
  if colors[c.color]and c.rarity~='special'and c.type~='status'and c.type~='curse'then colors[c.color]=colors[c.color]+1 end
  if c.runNativeABI then native=native+1 end
 end
 for color,n in pairs(colors)do assert(n==75,spec.label..' '..color..' incomplete')end;assert(native==9)
 same(r.data.rules,raw.rules);same(r.data.cards.starter_deck.cards,raw.cards.starter_deck.cards);same(r.relics,raw.rules.player.startingRelics)
 for _,key in ipairs({'reward','src','shop'})do same(r.data.cards.sourcePools[key],raw.cards.sourcePools[key])end
 local n=0;for _,pool in pairs(r.data.cards.sourcePools.reward)do n=n+#pool end
 assert(n==((not spec.id or spec.id=='ironclad')and 72 or 71))
 local states={};for _,s in ipairs(r.data.statuses.statuses)do states[s.id]=s end
 assert(states.intangible.priority==75 and states.rage.priority==5)
 local burn=find(r.data,'burn');assert(burn.burnDamage==2 and burn.upgrade.burnDamage==4)
 assert(Run.startCombat(r,'cultist_solo'));assert(r.combat.player.stance=='Neutral')
 assert(r.combat.orbs.slots==(spec.id=='defect'and 3 or 0))
 for _,id in ipairs({'master_reality','rage','evolve','feel_no_pain','corruption','self_repair'})do assert(not r.combat.player.statuses[id],'catalogue must not grant Power '..id)end
end
local raw=P.prepare(D,'ironclad');local normal=0
for _,c in ipairs(raw.cards.cards)do if c.type~='status'and c.type~='curse'and c.rarity~='special'then normal=normal+1 end end
assert(normal==66 and not raw.runCardCatalog,'historical Profile.prepare must remain its original66-card component')
local v4=Run.new(D,42,{character='furina'});assert(not v4.data.runCardCatalog and not v4.data.runCardCharacter)
assert(Run.startCombat(v4,'cultist_solo'));assert(v4.combat.originalV4 and not v4.combat.orbs and not v4.combat.player.stance)
print('RUN_CARD_CATALOG_CONTRACTS_PASS default/four classes 300, unchanged72/71 pools/resources, native9, canonical states, inert library and V4 isolation')
