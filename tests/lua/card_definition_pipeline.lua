package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D=require('abyss_combat'),require('abyss_data')
local count,records=0,{}
local function eq(a,b,label)assert(a==b,'[DEFINITION_PIPELINE] '..label..': '..tostring(a)..' ~= '..tostring(b))end
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
local function definition(s,instance,label)
 local before=graph({state=s,instance=instance})
 local result=table.pack(pcall(C.cardDefinition,s,instance))
 if not result[1]and type(result[2])=='string'then result[2]=result[2]:match(':%d+: (.*)')or result[2]end
 eq(graph({state=s,instance=instance}),before,label..' inputs/catalog/instances/RNG unchanged')
 records[#records+1]={label=label,state=s,instance=instance,result=result}
 return table.unpack(result,1,result.n)
end
local function get(s,instance,label)
 if instance.uid==nil then instance.uid=10000+#records end
 local ok,d=definition(s,instance,label);eq(ok,true,label..' query '..tostring(not ok and d or ''));return d
end
local function battle(data)
 local R=require('abyss_sts_random');local streams={}
 for _,id in ipairs({'monsterHpRng','aiRng','shuffleRng','cardRandomRng','miscRng'})do streams[id]=R.fromSeed('42')end
 return C.new(data or D,{seed=42,deck={},enemies={'cultist'},cardRandomSeed='42',shuffleSeed='17',
  roomSeed='42',roomStreams=streams,cardRng=R.fromSeed('7')})
end
local function group(name,fn)
 if DEFINITION_GROUP and DEFINITION_GROUP~=name then return end
 fn();count=count+1;print('ok definition group '..name)
end
local function damage(d)
 for _,effect in ipairs(d.effects)do if effect.op=='damage'or effect.op=='damageAll'then return effect.value end end
end

group('native',function()
 local s=battle();s.player.statuses.strength=5
 local p={uid=101,cardId='perfected_strike',upgraded=true}
 s.hand={p,{uid=102,cardId='strike'}};s.draw={{uid=103,cardId='strike'}};s.discard={{uid=104,cardId='strike'}}
 local d=get(s,p,'native Perfected Strike');eq(damage(d),18,'native Strike count includes itself once, no Strength baked in')
 local adapter=require('abyss_silent_discard_cards');local old=adapter.costAdapter
 adapter.costAdapter=function(state,instance,card)
  local out=C.copy(old(state,instance,card));out.experimental=true;out.target=nil;return out
 end
 d=get(s,p,'native flag captured before adapter replacement');adapter.costAdapter=old
 eq(damage(d),18,'native capture survives later adapter flag changes')
 local out={catalog={cards=s.catalog.cards},relics={}}
 local per=get(out,{cardId='searing_blow',upgraded=true,upgrades=2,searingBlowCopyUpgrades=1},'no player count-only copy')
 eq(damage(per),17,'count-only Searing upgrade arithmetic')
 eq(per.selfRetain,true,'existing no-player nil/nil retained-marker behavior preserved')
 local burn=get(out,{cardId='burn',upgraded=false},'no player Burn fallback')
 eq(burn.burnDamage,burn.endTurnDamage,'Burn legacy alias')
end)

group('adapters',function()
 local s=battle(require('abyss_silent').withFoundationCards(D))
 s.player.statuses.accuracy=4
 local shiv={uid=201,cardId='shiv',upgraded=false,shivAccuracyBonus=4,damageBonus=3,combatCost=0,turnCost=0}
 local stages={
  {'abyss_silent_discard_cards','costAdapter','discard'},
  {'abyss_retained_cards','adaptDefinition','retained'},
  {'abyss_warrior_strength_cards','adaptDefinition','strength'},
  {'abyss_watcher_attack_cards','adaptDefinition','watcher'},
  {'abyss_warrior_status_cards','adaptDefinition','status'},
  {'abyss_defect_engine_cards','adaptDefinition','engine'},
  {'abyss_defect_final_cards','adaptDefinition','defect'},
  {'abyss_silent_tactics_cards','adaptDefinition','tactics'},
  {'abyss_shivs','adaptDefinition','shiv'},
  {'abyss_corruption','adaptDefinition','cost'},
  {'abyss_colorless_cards','adapt','colorless'},
  {'abyss_silent_final_cards','adapt','silent'},
 }
 local original={};local seen={}
 for _,row in ipairs(stages)do
  local module,key,label=require(row[1]),row[2],row[3];local old=module[key];original[#original+1]={module,key,old}
  module[key]=function(state,instance,card)
   if instance~=shiv then return old(state,instance,card)end
   local out=C.copy(old(state,instance,card))
   local inherited=out.pipelineStages or {};eq(#inherited,#seen,label..' receives previous returned object')
   inherited[#inherited+1]=label;out.pipelineStages=inherited;seen[#seen+1]=label
   if label=='cost'then eq(damage(out),11,'Shiv base/Accuracy before per-instance bonus and costs')end
   return out
  end
 end
 local d=get(s,shiv,'all adapters return a replacement object')
 for _,row in ipairs(original)do row[1][row[2]]=row[3]end
 eq(table.concat(d.pipelineStages,','),'discard,retained,strength,watcher,status,engine,defect,tactics,shiv,cost,colorless,silent','ordered replacement adapters')
 eq(damage(d),11,'Shiv Accuracy then damage bonus');eq(d==s.catalog.cards.shiv,false,'detached Shiv result')
end)

group('costs',function()
 local s=battle();s.relics={'necronomicon'}
 local d=get(s,{cardId='blood_for_blood',upgraded=false,costReduction=2},'legacy Blood cost reduction');eq(d.cost,2,'legacy reduction applied once')
 d=get(s,{cardId='blood_for_blood',upgraded=false,combatCost=3,turnCost=2,costReduction=2},'persistent Blood cost does not double-reduce');eq(d.cost,2,'persistent costs already include reduction')
 d=get(s,{cardId='strike',upgraded=false,costOverride=3,combatCost=2,turnCost=1,costForTurn=0},'explicit zero without free masking');eq(d.cost,0,'zero turn override is present');eq(d.necronomiconCostForTurn,0,'zero snapshot without free masking')
 d=get(s,{cardId='strike',upgraded=false,costOverride=0,combatCost=2,turnCost=1,costForTurn=0,freeToPlayOnce=true},'cost override chain with zero');eq(d.cost,0,'explicit zero wins');eq(d.necronomiconCostForTurn,0,'zero snapshot retained')
 d=get(s,{cardId='strike',upgraded=false,costOverride=3,turnCost=2,costForTurn=1,freeToPlayOnce=true},'free once after turn override');eq(d.cost,0,'free once after costForTurn');eq(d.necronomiconCostForTurn,0,'Necronomicon snapshots after free once')
 s.player.statuses.free_attack=1
 d=get(s,{cardId='strike',upgraded=false,costOverride=3},'Necronomicon captures before free Attack');eq(d.cost,0,'free Attack applied');eq(d.necronomiconCostForTurn,3,'Necronomicon pre-free attack snapshot')
 d=get(s,{cardId='whirlwind',upgraded=false,freeToPlayOnce=true},'legacy zero all-energy mode');eq(d.cost,0,'legacy zero X retained');eq(d.costMode,'all_energy','legacy X mode retained')
 for _,card in ipairs(require('abyss_character_profiles').prepare(D,'ironclad').cards.cards)do if card.id=='whirlwind'then s.catalog.cards.whirlwind=C.copy(card)end end
 d=get(s,{cardId='whirlwind',upgraded=false,freeToPlayOnce=true},'source X retains all-energy mode');eq(d.cost,-1,'source X sentinel retained');eq(d.costMode,'all_energy','source X mode retained');eq(d.necronomiconCostForTurn,-1,'X snapshot retained')
 s.player.statuses.corruption=1;s.experimentalMechanics=false
 d=get(s,{cardId='defend',upgraded=false,combatCost=2,turnCost=1,costForTurn=3},'native Corruption last skill cost');eq(d.cost,0,'native Corruption wins positive skill cost')
 local t=get(s,{cardId='dazed',upgraded=false},'unavailable sentinel without Medical Kit');eq(t.cost,-2,'unavailable sentinel retained')
 s.relics={'medical_kit'}
 t=get(s,{cardId='dazed',upgraded=false,exhaust=false},'Medical Kit last status adaptation');eq(t.cost,0,'Medical Kit makes status cost available');eq(t.exhaust,true,'Medical Kit exhausts')
 s.relics={'blue_candle'}
 t=get(s,{cardId='regret',upgraded=false,exhaust=false},'Blue Candle last curse adaptation');eq(t.cost,0,'Blue Candle clamps curse sentinel');eq(t.exhaust,true,'Blue Candle exhausts')
 local outside={catalog={cards=s.catalog.cards},relics={}}
 t=get(outside,{cardId='strike',upgraded=false},'nil instance cost fields outside combat');eq(t.cost,1,'nil cost fields preserve base')
 eq(t.selfRetain,true,'existing outside-combat nil-turn behavior preserved')
end)

group('copies-errors',function()
 local s=battle();local source=s.catalog.cards.strike
 local shared={enabled=false};source.audit=shared;source.auditAgain=shared;shared.parent=source;source.auditSelf=source
 local key={enabled=false};source[key]='key identity';source.auditKey=key
 local c={cardId='strike',upgraded=false,dontTriggerOnUseCard=false,exhaust=false}
 local first=get(s,c,'definition preserves graph aliases/cycles in detached result')
 eq(first==source,false,'root definition detached');eq(first.audit==shared,false,'nested definition detached')
 eq(first.audit,first.auditAgain,'nested alias retained');eq(first.audit.parent,first,'nested parent cycle retained');eq(first.auditSelf,first,'root self cycle retained')
 eq(first[key],'key identity','table key identity follows shared copy ABI');eq(first.auditKey==key,false,'value-position key table copied independently')
 eq(first.exhaust,false,'explicit false exhaust retained');eq(first.dontTriggerOnUseCard,false,'explicit false trigger flag retained')
 local second=get(s,c,'each definition query returns independent objects');eq(second==first,false,'second root independent');eq(second.audit==first.audit,false,'second nested independent')
 first.audit.enabled=true;eq(source.audit.enabled,false,'returned mutation does not affect catalog');eq(second.audit.enabled,false,'returned mutation does not affect next result')
 local errors={
  {{cardId='missing',upgraded=false,upgrades=0,searingBlowCopyUpgrades=0,dontTriggerOnUseCard='bad'},'invalid Searing Blow constructor copy'},
  {{cardId='missing',dontTriggerOnUseCard='bad'},'unknown card'},
  {{cardId='strike',dontTriggerOnUseCard='bad',damageBonus=-1},'invalid instance card trigger flag'},
  {{cardId='strike',damageBonus=-1,turnCost='bad'},'invalid card damage bonus'},
 }
 for i,row in ipairs(errors)do local ok,why=definition(s,row[1],'exception priority '..i);eq(ok,false,'invalid query rejected');assert(tostring(why):find(row[2],1,true),'[DEFINITION_PIPELINE] exception priority '..i..': '..tostring(why))end
end)
if DEFINITION_TRACE then print('CARD_DEFINITION_TRACE '..graph(records))end
print('CARD_DEFINITION_PIPELINE_PASS '..count)
