package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function card(data,id)for _,c in ipairs(data.cards.cards)do if c.id==id then return c end end;error(id)end
local seed=Run.new(D,42)
local function status(data,id)for _,s in ipairs(data.statuses.statuses)do if s.id==id then return s end end;error(id)end
local source=C.copy(D);local foreign=C.copy(card(seed.data,'cold_snap'))
foreign.name='调用方冰寒快照';foreign.callerWords={word='first'}
source.cards.cards[#source.cards.cards+1]=foreign;source.foreignAlias=foreign;source.wordAlias=foreign.callerWords
local power=C.copy(status(seed.data,'rushdown'));power.description='调用方疾袭词条'
source.statuses.statuses[#source.statuses.statuses+1]=power;source.powerAlias=power
for _,spec in ipairs({{}, {character='silent',experimental=true},{character='defect',experimental=true},{character='watcher',experimental=true}})do
 local r=Run.new(source,42,next(spec)and spec or nil);local c=card(r.data,'cold_snap')
 assert(c.name=='调用方冰寒快照'and c.callerWords.word=='first')
 assert(c==r.data.foreignAlias and c.callerWords==r.data.wordAlias and c~=foreign)
 assert(c.effects[1].value==6 and c.sourceId=='Cold Snap')
 assert(status(r.data,'rushdown')==r.data.powerAlias and r.data.powerAlias.description=='调用方疾袭词条'and r.data.powerAlias~=power)
 c.callerWords.word='private';assert(foreign.callerWords.word=='first')
end
foreign.callerWords.word='latest';local fresh=Run.new(source,43)
assert(card(fresh.data,'cold_snap').callerWords.word=='latest','subsequent caller words must not come from a cached input')
foreign.effects[1].value=7
local ok,err=pcall(Run.new,source,44)
assert(not ok and tostring(err):find('incompatible caller foreign card: cold_snap.effects',1,true),'incompatible caller rules must be explicitly refused')
assert(foreign.effects[1].value==7 and foreign.callerWords.word=='latest','refusal must not mutate caller data')
foreign.effects[1].value=6;power.priority=99
ok,err=pcall(Run.new,source,44,{character='watcher',experimental=true})
assert(not ok and tostring(err):find('incompatible caller Power: rushdown',1,true),'incompatible current Power priority must be explicitly refused')
print('RUN_CARD_CATALOG_CALLER_FOREIGN_PASS current compatible foreign definitions/words/meaningful aliases retained privately; incompatible effects explicitly refused')
