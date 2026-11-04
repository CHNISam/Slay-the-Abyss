package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D=require('abyss_combat'),require('abyss_data')
local function eq(a,b,label)assert(a==b,'[COMBAT_PREVIEWS] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function graph(v,seen)
 local kind=type(v)
 if kind=='function'then return 'function'end
 if kind=='string'then return string.format('%q',v)end
 if kind=='number'then return 'number:'..string.format('%.17g',v)end
 if kind~='table'then return kind..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=graph(k,seen)..'='..graph(v[k],seen)end
 return '{'..table.concat(rows,';')..'}'
end
local records={}
local function query(s,p,target,label)
 local before=graph({state=s,instance=p})
 local result=table.pack(pcall(C.cardPreview,s,p,target))
 if not result[1]then result[2]=tostring(result[2]):match(':%d+: (.*)')or result[2]end
 eq(graph({state=s,instance=p}),before,label..' complete input graph/aliases/all RNG unchanged')
 records[#records+1]=graph({label=label,state=s,instance=p,result=result})
 return table.unpack(result,1,result.n)
end
local real=C.new(D,{seed=79,deck={},enemies={'cultist','cultist'}})
local function streams(state)
 for _,name in ipairs({'monsterHpRng','aiRng','shuffleRng','cardRandomRng','miscRng','cardRng'})do
  state[name]=require('abyss_sts_random').fromSeed('42')
 end
end
streams(real)
local s={player={hp=50,block=4,statuses={}},enemies={{hp=50,statuses={}},{hp=50,statuses={}}},
 rules={combat=real.rules.combat},relics={}}
streams(s)
local p={uid=800,cardId='strike'};s.hand={p,{uid=801,cardId='defend'}}
s.alias=s.hand;s.rngAlias=s.cardRng
s.player.statuses.strength=2;s.enemies[1].statuses.vulnerable=1
local definition=C.cardDefinition
local effects
C.cardDefinition=function()return {effects=effects}end
local families={'damage','damageAll','barrageDamage','bowlingBash','ftlDamage','heelHook','fiendFire','fearNoEvil','wallop','flowDamage','sunderDamage','finisherDamage','flechettesDamage','skewer','glassKnife','watcherFinalRagnarok','watcherFinalExpungerHits','watcherFinalLessonLearned','feed','reaper','damageRandom','blizzardDamage','randomEngineAttack','thunderStrike','whirlwind','reaperDamage','damageEqualToBlock','block','nextBlock','xBlock','secondWind','stackBlock','autoShields','escapePlan','watcherFinalSpiritShield','halt','colorless'}
for _,op in ipairs(families)do
 effects={{op=op,value=3,damage=5,kind='ritual',wrathValue=9}}
 for _,target in ipairs({0,1,2,8})do local ok,r=query(s,p,target,op..target);eq(ok,true,op);eq(r[1]~=nil,true,op..' slot')end
end
effects={{op='unknown'},{op='damage',value=3},{op='conditional',['then']={{op='unknown'},{op='block',value=4}},['else']={{op='damage',value=90}}}}
local ok,r=query(s,p,1,'sparse recursive slots');eq(ok,true,'sparse');eq(r[1],nil,'hole retained');eq(r[2].low,7,'following original index');eq(r[3]['then'][2].low,4,'then retained');eq(r[3]['else'],nil,'no else')
effects={[1]={op='damage',value=3},[3]={op='block',value=4}}
ok,r=query(s,p,1,'ipairs nil cutoff');eq(r[3],nil,'nil truncates effects')
s.enemies[1].hp=0;s.enemies[2].statuses.vulnerable=1;effects={{op='damageAll',value=3}}
ok,r=query(s,p,2,'dead first AOE slot');eq(r[1].low,5,'dead first slot neutral');eq(r[1].targets[1],5,'dead target slot retained')
ok,r=query(s,p,1,'dead aimed neutral');eq(r[1].targets,nil,'dead aim cannot borrow live enemy')
effects={{op='randomEngineAttack',value=3},{op='thunderStrike',value=3},{op='damageRandom',value=3}}
s.enemies[1].hp=50
ok,r=query(s,p,1,'random neutral versus aimed');eq(r[1].low,5,'engine neutral');eq(r[2].low,5,'thunder neutral');eq(r[3].low,7,'damageRandom old aimed semantics')
s.player.statuses.dexterity=2;s.player.statuses.frail=1;s.player.stance='Wrath'
effects={{op='halt',value=3,wrathValue=9}}
ok,r=query(s,p,0,'Halt separate floors');eq(r[1].low,11,'Halt floors each component')
effects={{op='watcherFinalSpiritShield',value=3}}
ok,r=query(s,{uid=p.uid,cardId='strike'},0,'Spirit same UID copy');eq(r[1].low,3,'same UID excluded')
ok,r=query(s,{uid=999,cardId='strike'},0,'Spirit outside hand');eq(r[1].low,6,'outside hand counts all')
effects=nil;ok=query(s,p,1,'nil effects error');eq(ok,false,'nil effects fails')
effects={{op='conditional'}};ok=query(s,p,1,'nil then error');eq(ok,false,'nil then fails')
-- Dynamic op is read at each original branch, including the returned op.
local reads=0;effects={setmetatable({value=3},{__index=function(_,key)if key=='op'then reads=reads+1;return reads<4 and 'missing'or 'damageAll'end end})}
ok,r=query(s,p,1,'dynamic op');eq(ok,true,'dynamic op');eq(reads,38,'dynamic op read order/count');records[#records+1]='opReads='..reads
C.cardDefinition=definition
s=real
query(s,p,1,'real definition')
query(s,{uid=4,cardId='missing'},1,'unknown card error')
-- Definition runs before player capture; original V4 returns before aimed lookup.
local oldV4=require('abyss_original_v4').preview
local trace={};local replacement={statuses={},block=9}
C.cardDefinition=function(state)state.player=replacement;return {effects={{op='damageEqualToBlock'}}}end
local captured=C.cardPreview({player={statuses={},block=2},enemies={},rules=s.rules,relics={}},p,0)
eq(captured[1].low,9,'player captured after definition')
C.cardDefinition=function(state)trace[#trace+1]='definition';state.player=replacement;return {originalV4=true}end
require('abyss_original_v4').preview=function()trace[#trace+1]='V4';return {sentinel=true}end
local special={player=s.player,enemies=setmetatable({},{__index=function()error('aimed lookup before V4')end})}
local v=C.cardPreview(special,p,1);eq(v.sentinel,true,'V4 early');eq(table.concat(trace,','),'definition,V4','entry order')
C.cardDefinition=definition;require('abyss_original_v4').preview=oldV4
local F=dofile('tests/lua/support/original_v4_fixture.lua')
local v4=F.state('AR',nil,2);local card=F.card(v4,'AR2-015',false)
streams(v4)
v4.draw={};v4.discard={{uid=900,cardId='AR2-001'},{uid=901,cardId='AR2-002'},{uid=902,cardId='AR2-003'}}
v4.rngAlias=v4.shuffleRng;local rngBefore=graph(v4.shuffleRng)
local plays=C.play;local staged
C.play=function(state,...)staged=state;return plays(state,...)end
ok,r=query(v4,card,1,'real V4 cloned play');eq(ok,true,'real V4 query');eq(r.originalV4,true,'V4 entries');eq(staged~=v4,true,'play uses clone')
eq(graph(staged.shuffleRng)~=rngBefore,true,'real V4 draw reshuffles clone RNG')
eq(staged.rngAlias==staged.shuffleRng,true,'clone retains RNG alias')
records[#records+1]=graph({staged=staged})
C.play=plays
if QUERY_DIFFERENTIAL_TRACE then
 for _,record in ipairs(records)do print('COMBAT_PREVIEWS_TRACE '..record)end
end
print('COMBAT_PREVIEWS_PASS '..#records)
