package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
for _,registered in ipairs({false,true})do
 local source=C.copy(D)
 if registered then source=require('abyss_colorless_cards').withCards(source)end
 -- A caller flag is not ownership: Run must first detach the complete graph.
 source.runCardCatalog=true
 source.cards.sourcePools.cardSourceMetadata={}
 source.metadataAlias=source.cards.sourcePools.cardSourceMetadata
 source.cardListAlias=source.cards.cards;source.statusListAlias=source.statuses.statuses
 local count,statusCount=#source.cards.cards,#source.statuses.statuses
 local first
 for _,spec in ipairs({{}, {character='ironclad',experimental=true},{character='silent',experimental=true},{character='defect',experimental=true},{character='watcher',experimental=true}})do
  local r=Run.new(source,42,next(spec)and spec or nil)
  assert(r.data~=source and r.data.metadataAlias==r.data.cards.sourcePools.cardSourceMetadata and r.data.metadataAlias~=source.metadataAlias)
  assert(r.data.cardListAlias==r.data.cards.cards and r.data.statusListAlias==r.data.statuses.statuses)
  assert(r.data.metadataAlias.strike.sourceId=='Strike_R'and r.data.metadataAlias.ritual_dagger.sourceId=='RitualDagger')
  assert(r.data.colorlessCards and #r.data.cards.sourcePools.srcColorless==35)
  if first then assert(first.data.metadataAlias~=r.data.metadataAlias and first.data.cardListAlias~=r.data.cardListAlias)else first=r end
 end
 assert(#source.cards.cards==count and #source.statuses.statuses==statusCount and next(source.metadataAlias)==nil)
 assert(source.colorlessCards==(registered and true or nil),'owned registration never trusts a caller marker or mutates its source')
 assert(Run.startCombat(first,'cultist_solo'));local a=first.combat
 a.sourcePools.cardSourceMetadata.strike.sourceId='battle only'
 assert(first.data.metadataAlias.strike.sourceId=='Strike_R')
 assert(Run.obtainPotion(first,'smoke_bomb'));assert(Run.usePotion(first,1));assert(Run.startCombat(first,'cultist_solo'))
 assert(first.combat.sourcePools.cardSourceMetadata.strike.sourceId=='Strike_R'and first.combat.sourcePools~=a.sourcePools)
end
print('RUN_CARD_CATALOG_OWNED_REGISTRATION_PASS private Run ownership before registration, both caller modes/five profiles, two-Run and two-battle metadata isolation')
