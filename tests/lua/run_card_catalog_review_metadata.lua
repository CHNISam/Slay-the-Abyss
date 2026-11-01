package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local source=require('abyss_colorless_cards').withCards(C.copy(D))
source.cards.sourcePools.cardSourceMetadata={}
source.metadataAlias=source.cards.sourcePools.cardSourceMetadata
source.metadataAlias.strike={sourceId='Strike_R',type='attack',rarity='basic',healing=false,callerWord='current'}
source.metadataEntryAlias=source.metadataAlias.strike
source.metadataAlias.self=source.metadataAlias
source.sourcePoolsAlias=source.cards.sourcePools
source.cards.sourcePools.entryAlias=source.metadataAlias.strike
for _,spec in ipairs({{}, {character='ironclad',experimental=true},{character='silent',experimental=true},{character='defect',experimental=true},{character='watcher',experimental=true}})do
 local r=Run.new(source,42,next(spec)and spec or nil)
 assert(r.data.metadataAlias==r.data.cards.sourcePools.cardSourceMetadata,'private metadata map must be filled in place')
 assert(r.data.metadataAlias~=source.metadataAlias and r.data.metadataAlias.strike.sourceId=='Strike_R')
 assert(r.data.sourcePoolsAlias==r.data.cards.sourcePools and r.data.metadataAlias.self==r.data.metadataAlias)
 assert(r.data.metadataEntryAlias==r.data.metadataAlias.strike and r.data.metadataEntryAlias==r.data.cards.sourcePools.entryAlias)
 assert(r.data.metadataEntryAlias.callerWord=='current')
 assert(r.data.metadataAlias.cold_snap.sourceId=='Cold Snap'and r.data.metadataAlias.self_repair.healing==true)
end
assert(source.metadataAlias.self==source.metadataAlias and source.metadataAlias.cold_snap==nil and source.metadataEntryAlias.callerWord=='current','source metadata is never filled or cached in place')
print('RUN_CARD_CATALOG_REVIEW_METADATA_PASS actual source metadata map alias and full cross-color facts remain private')
