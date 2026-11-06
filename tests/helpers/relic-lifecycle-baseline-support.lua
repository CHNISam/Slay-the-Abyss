package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F={}
F.count=0;F.coverage={};RELIC_LIFECYCLE_COVERAGE=F.coverage
F.registered={};F.executed={};RELIC_LIFECYCLE_REGISTERED=F.registered;RELIC_LIFECYCLE_EXECUTED=F.executed
function F.runFixture(key,prefix,first,last)
 local fixture=assert(dofile('tests/helpers/relic-lifecycle-baseline-fixtures.lua')[key])
 local dispatcher=(key=='fatal'or key=='parasite')and 'local function test(name,fn)'or 'local function test(name,f)'
 local _,count=fixture.source:gsub(dispatcher:gsub('([^%w])','%%%1'),'')
 assert(count==1,'one exact original test dispatcher')
 local ordinal=0
 RELIC_LIFECYCLE_REGISTER_CASE=function(name)
  ordinal=ordinal+1
  local identity=fixture.path..' :: '..name;F.registered[#F.registered+1]=identity
  local selected=(not prefix or name:sub(1,#prefix)==prefix)and(not first or ordinal>=first and ordinal<=last)
  if selected then F.executed[#F.executed+1]=identity end
  return selected
 end
 local source=fixture.source:gsub(dispatcher:gsub('([^%w])','%%%1'),function(value)
  return value..'\n if not RELIC_LIFECYCLE_REGISTER_CASE(name)then return end\n'
 end)
 assert(load(source,'@'..fixture.path,'t'))()
end
function F.case(name,fn)
 F.registered[#F.registered+1]=name;F.executed[#F.executed+1]=name;return fn()
end
function F.eq(a,b,label)assert(a==b,'[RELIC_LIFECYCLE] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
function F.snapshot(label,value)
 F.count=F.count+1
 if RELIC_LIFECYCLE_TRACE then
  assert(type(RELIC_LIFECYCLE_GRAPH_WRITE)=='function','explicit trace requires complete native graph observer')
  RELIC_LIFECYCLE_GRAPH_WRITE(value,label,true)
 end
end
function F.normalized(result)
 local observed={n=result.n};for i=1,result.n do observed[i]=result[i]end
 if not result[1]and type(result[2])=='string'then observed[2]=result[2]:gsub('^.-:%d+: ','')end
 return observed
end
function F.call(root,label,fn,...)
 local args=table.pack(...);F.snapshot(label..':enter',{root=root,fn=fn,args=args})
 local result=table.pack(pcall(fn,table.unpack(args,1,args.n)))
 F.snapshot(label..':return',{root=root,fn=fn,args=args,result=F.normalized(result)})
 return table.unpack(result,1,result.n)
end
local methods={
 hooks={'onLoseHpLast','gainGold','onEquip','onUnequip','obtainCirclet','scoreAdjustment','enqueuePostDraw','upgradeRandomHand','campHealAmount','onUsePotion','onRest','beforeObtainCard','onPreviewObtainCard','previewCardReward','onObtainCard','onEnterRoom','onSpendGold','onVictory','bindBattle','preBattle','hpChanged','wasHpLost','atTurnStart','prepareTurnStart','onUseCard','afterCard','battleStart','endTurnBlock','onPlayerEndTurn'},
 uncommon={'onEquip','onEnterRoom','battleEnd','onVictory','atTurnStart','onShuffle','onUseCard','onMonsterDeath','wasHpLost','strikeBonus','vulnerablePercent','canPlayCurse','singingBowl','onChestOpen','bottleCandidates','equipBottle'},
 rare={'onMasterDeckChange','onEquip','bindBattle','battleStart','atTurnStart','postDraw','onPlayCard','onUseCard','onPlayerEndTurn','disableTop','onRefreshHand','blockPower','onVulnerableApplied','onAttacked','blockAtTurnStart','rechargeEnergy','modifyHealing','randomCardId','onExhaust','chooseGambling','applyEffect','onVictory','campOptions','lift','canWingedTravel','useWingedTravel'},
 boss={'energyBonus','drawBonus','hidesIntents','retainsHand','atTurnStart','canPlay','onPlayCard','wasHpLost','preBattle','onSpawnMonster','battleStart','select','claimRelic','claim','onEquip'},
 shop={'onEquip','chooseMirror','battleStartActions','turnStartActions','onBlockBroken','onShuffle','xBonus','medicalCard','exhaustAfterUse','onUseCard','execute','beginToolbox','chooseToolbox','drawOrderVisible'},
}
F.publicMethods={}
for namespace,names in pairs(methods)do
 local result={};for _,name in ipairs(names)do result[#result+1]=name end
 result[#result+1]='localId'
 if namespace~='boss'then result[#result+1]='owns'end
 if namespace=='uncommon'then result[#result+1]='rewardCardCount';result[#result+1]='isBottled'
 elseif namespace=='rare'then result[#result+1]='extraCardRewards';result[#result+1]='canSpawn'
 elseif namespace=='boss'then result[#result+1]='cardRewardCount'end
 F.publicMethods[namespace]=result
end
-- Replace ordinary public methods exactly as consumers can. Each invocation
-- observes real parameters before execution and complete post-call state,
-- all returns, and the original nonstring error object before rethrowing it.
for _,namespace in ipairs({'hooks','uncommon','rare','boss','shop'})do
 local module=require('abyss_'..(namespace=='hooks'and 'relic_hooks'or namespace..'_relics'))
 F[namespace]=module
 for _,name in ipairs(methods[namespace])do
  local original=assert(module[name],namespace..'.'..name)
  module[name]=function(...)
   local label=namespace..'.'..name;F.coverage[label]=(F.coverage[label]or 0)+1
   local args=table.pack(...);F.snapshot(label..':enter',{args=args})
   local result=table.pack(pcall(original,table.unpack(args,1,args.n)))
   F.snapshot(label..(result[1]and ':return'or ':throw'),{args=args,result=F.normalized(result)})
   if not result[1]then error(result[2],0)end
   return table.unpack(result,2,result.n)
  end
 end
end
F.C=require('abyss_combat');F.A=require('abyss_actor');F.R=require('abyss_run');F.Q=require('abyss_card_actions');F.D=require('abyss_data')
function F.root(owner)
 local root={owner=owner,anchors={}}
 for key,value in pairs(owner)do if type(value)=='table'or type(value)=='function'then root.anchors[key]=value end end
 return root
end
function F.unchanged(owner)
 local saved={};local function capture(value)
  if type(value)~='table'or saved[value]then return end
  local fields={};saved[value]=fields;for k,v in pairs(value)do fields[k]=v;capture(k);capture(v)end
 end;capture(owner)
 return function()for original,fields in pairs(saved)do
  for k,v in pairs(fields)do F.eq(original[k],v,'original graph field '..tostring(k))end
  for k,v in pairs(original)do F.eq(v,fields[k],'no inserted original field '..tostring(k))end
 end end
end
function F.finish(group)
 assert(F.count>0,'nonempty lifecycle group')
 print('RELIC_LIFECYCLE_PASS '..group..' checkpoints='..F.count)
end
return F
