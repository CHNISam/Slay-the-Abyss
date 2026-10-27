package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Profiles=require('abyss_character_profiles');local C=require('abyss_combat');local data=require('abyss_data')
local Run=require('abyss_run')
local expected={silent={19,33,19},defect={18,36,17},watcher={19,35,17}}
for _,id in ipairs({'silent','defect','watcher'})do
 local prepared=Profiles.prepare(data,id)
 local count=0
 for i,rarity in ipairs({'common','uncommon','rare'})do
  local reward=prepared.cards.sourcePools.reward[rarity];local src=prepared.cards.sourcePools.src[rarity]
  assert(#reward==expected[id][i],id..' '..rarity..' must use its complete original pool')
  assert(#src==#reward)
  for n,cardId in ipairs(reward)do assert(src[#src-n+1]==cardId)end
  count=count+#src
 end
 assert(count==71)
 local s=C.new(prepared,{deck={'chrysalis'},enemies={'jaw_worm'},seed=7,shuffleSeed='7'})
 local card=s.hand[1];local energy=s.energy;local before=C.copy(s.cardRandomRng)
 local ok,why=C.play(s,card.uid)
  assert(ok,why);assert(s.energy==energy-2 and #s.draw==3 and #s.exhaust==1)
  for _,generated in ipairs(s.draw)do local definition=C.cardDefinition(s,generated);assert(definition.type=='skill' and definition.cost<=0)end
  assert(s.cardRandomRng.counter>before.counter,'complete class generation consumes the source stream')
 local missing=C.new(prepared,{deck={'chrysalis'},enemies={'jaw_worm'},seed=7,shuffleSeed='7'})
 missing.catalog.cards[missing.sourcePools.src.common[1]]=nil
 local snapshot=C.copy(missing)
 local refused,reason=C.play(missing,missing.hand[1].uid)
 assert(not refused and reason:find('incomplete_generation_pool',1,true))
 assert(missing.energy==snapshot.energy and missing.hand[1].uid==snapshot.hand[1].uid and #missing.events==#snapshot.events)
 assert(missing.cardRandomRng.counter==snapshot.cardRandomRng.counter)
 local run=Run.new(data,19,{character=id,experimental=true})
 assert(Run.startCombat(run,'cultist_solo'));run.combat.enemies[1].hp=0
 local counter=run.cardRng.counter;assert(Run.finishCombat(run));assert(run.cardRng.counter>counter,'rewards must consume the source card stream')
end
print('ok complete class source pools and explicit missing-generation rejection')
