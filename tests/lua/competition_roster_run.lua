-- Actual Run admission. No natural acquisition, platform or device claim.
local Run,Data,C=require('abyss_run'),require('abyss_data'),require('abyss_combat')
local Seed=require('abyss_run_seed')
local Catalog=require('abyss_run_card_catalog')
local Original=require('abyss_original_v4_profiles')
local Random=require('abyss_sts_random')
local function options(id)return {experimental=true,campaign=true,campaignProfile='competition-two-act',character=id}end
local failures,count={},0
local function test(name,fn)
 local ok,why=pcall(fn);count=count+1
 print((ok and 'PASS 'or 'FAIL ')..name)
 if not ok then failures[#failures+1]=name..': '..tostring(why)end
end
local function same(a,b)
 if type(a)~='table'or type(b)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
test('canonical Geo is public and frozen Raiden remains explicit development',function()
 local geo=Run.new(Data,'3',options())
 assert(not geo.characterProfile and geo.maxHp==80 and geo.campaignProfile=='competition-two-act')
 local function unchangedPools(run,id,source)
  local full=options(id);full.campaignProfile='full-source'
  local reference=Run.new(source or Data,'3',full)
  same(run.data.cards.sourcePools,reference.data.cards.sourcePools)
  same(run.deck,reference.deck);same(run.relics,reference.relics)
  for _,key in ipairs({'eventRng','cardRng','miscRng','treasureRng'})do
   same(Random.snapshot(run[key]),Random.snapshot(reference[key]))
  end
 end
 unchangedPools(geo)
 for _,id in ipairs({'raiden','RD'})do
  local full=options(id);full.campaignProfile='full-source'
  local run=Run.new(Data,'3',full)
  assert(run.character=='raiden'and run.characterProfile.originalV4 and run.characterProfile.role=='RD')
  assert(run.data.originalV4Role=='RD'and run.campaignProfile=='full-source')
  assert(run.data.cards.starter_deck.cards[1]:match('^RD'))
  unchangedPools(run,id)
 end
 -- A shared raw catalogue carries default source metadata, not a selected role.
 local raw=Catalog.prepare(Data,Data,nil,false);local before=C.copy(raw)
 assert(raw.runCardCatalog and raw.runCardCharacter=='ironclad'and not raw.experimentalCharacter)
 local full=options('raiden');full.campaignProfile='full-source'
 local raiden=Run.new(raw,'3',full)
 assert(raiden.character=='raiden'and raiden.data.originalV4Role=='RD')
 unchangedPools(raiden,'raiden',raw);same(raw,before)
end)
local function denied(data,id)
 local before=C.copy(data)
 local normalize,prepare,original=Seed.normalize,Catalog.prepareSelected,Original.prepare
 local calls=0
 Seed.normalize=function(...)calls=calls+1;return normalize(...)end
 Catalog.prepareSelected=function(...)calls=calls+1;return prepare(...)end
 Original.prepare=function(...)calls=calls+1;return original(...)end
 local ok,why=pcall(Run.new,data,'3',options(id))
 Seed.normalize,Catalog.prepareSelected,Original.prepare=normalize,prepare,original
 assert(not ok and tostring(why):find('competition_character_unavailable',1,true),'competition admitted '..tostring(id)..': '..tostring(why))
 assert(calls==0,'rejected identity reached adaptation or seed/RNG initialization')
 same(data,before)
end
test('all other direct role factories reject before adaptation or RNG',function()
 -- A raw shared catalogue cannot smuggle Raiden into the public profile.
 local raw=Catalog.prepare(Data,Data,nil,false);denied(raw,'raiden');denied(raw,'RD')
 for _,id in ipairs({'hutao','arlecchino','furina','raiden','silent','defect','watcher','HT','AR','FR','RD','unknown'})do denied(Data,id)end
end)
test('prepared source identity cannot bypass omitted character',function()
 for _,id in ipairs({'silent','defect','watcher'})do local prepared=Catalog.prepareSelected(Data,id);denied(prepared)end
 for _,id in ipairs({'hutao','arlecchino','furina','raiden'})do local prepared=Original.prepare(Data,id);denied(prepared)end
end)
test('contradictory caller identity markers fail closed',function()
 for _,key in ipairs({'experimentalCharacter','characterId','originalV4Role'})do
  local data=C.copy(Data);data[key]=key=='originalV4Role'and 'HT'or 'silent'
  denied(data,'ironclad')
 end
end)
assert(#failures==0,table.concat(failures,'\n'))
print('COMPETITION_ROSTER_RUN_PASS '..count..'; native/natural NOT_RUN')
