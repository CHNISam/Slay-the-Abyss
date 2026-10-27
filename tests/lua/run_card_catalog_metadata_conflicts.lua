package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
for _,item in ipairs({{id='strike',fact={sourceId='Bash',type='attack',rarity='basic',healing=false}},
 {id='feed',fact={sourceId='Feed',type='attack',rarity='rare',healing=false}},
 {id='self_repair',fact={sourceId='Self Repair',type='power',rarity='uncommon',healing=false}},
 {id='bandage_up',fact={sourceId='Bandage Up',type='skill',rarity='uncommon',healing=false}}})do
 for _,spec in ipairs({{}, {character='silent',experimental=true}})do
  local source=C.copy(D);source.cards.sourcePools.cardSourceMetadata={[item.id]=C.copy(item.fact)}
  local ok,err=pcall(Run.new,source,42,next(spec)and spec or nil)
  assert(not ok and tostring(err):find('incompatible caller card metadata: '..item.id,1,true),'caller source metadata must not override verified identity/HEALING for '..item.id)
  assert(source.cards.sourcePools.cardSourceMetadata[item.id].sourceId==item.fact.sourceId)
 end
end
local source=C.copy(D);source.cards.sourcePools.cardSourceMetadata={strike={callerWord='word only'}}
local r=Run.new(source,42,{character='silent',experimental=true})
local entry=r.data.cards.sourcePools.cardSourceMetadata.strike
assert(entry.sourceId=='Strike_R'and entry.type=='attack'and entry.healing==false and entry.callerWord=='word only')
print('RUN_CARD_CATALOG_METADATA_CONFLICTS_PASS actual Run rejects red identity/HEALING and cross-color tag conflicts; partial caller words get canonical facts')
