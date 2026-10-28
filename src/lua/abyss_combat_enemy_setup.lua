-- Constructor-only enemy ownership. No player, opening AI, deck or relic work.
local Copy=require('abyss_copy').copy
local Actors=require('abyss_actor')
local Effects=require('abyss_effects')
local EnemyAI=require('abyss_enemy_ai')
local Random=require('abyss_sts_random')
local Formation=require('abyss_encounter_formation')
local M={}
local function index(entries)
 local result={};for _,entry in ipairs(entries)do result[entry.id]=entry end;return result
end
local function registerList(catalog,kind,list,label)
 for _,definition in ipairs(list)do
  assert(not catalog[kind][definition.id],'duplicate '..label)
  catalog[kind][definition.id]=Copy(definition)
 end
end
function M.register(catalog)
 require('abyss_act4_enemies').register(catalog)
 require('abyss_act1_bosses').register(catalog,Copy)
 require('abyss_act3_bosses').register(catalog,Copy)
 require('abyss_reptomancer').register(catalog,Copy)
 require('abyss_darklings').register(catalog,Copy)
 for _,entry in ipairs({{require('abyss_act2_enemies'),'Act2'},{require('abyss_act3_enemies'),'Act3'}})do
  registerList(catalog,'enemies',entry[1].enemies,entry[2]..' enemy')
  registerList(catalog,'statuses',entry[1].statuses,entry[2]..' status')
 end
end
local function policy(enemy,kind,detail)
 return enemy.ai and enemy.ai.kind==kind and (detail==nil or enemy.ai.policy==detail)
end
local function splitPolicy(enemy)
 return policy(enemy,'spike_slime_l')or policy(enemy,'acid_slime_l')or policy(enemy,'act1_boss','slime_boss')
end
local function specialMove(enemy,intent)
 local kind,ai=intent.kind,enemy.ai
 local ownerKind=ai and ai.kind
 local supported=kind=='escape'and ownerKind=='looter'
  or kind=='charge'and ownerKind=='charge_then_attack'
  or kind=='split'and splitPolicy(enemy)
 assert(supported and ai[kind..'Intent']==intent.id,kind..' intent requires matching AI')
 assert(type(intent.effects)=='table'and next(intent.effects)==nil,kind..' intent has effects')
end
local function unknownInactive(enemy,intent)
 if policy(enemy,'awakened_one')and intent.id=='rebirth'then return 'Rebirth has effects'end
 if policy(enemy,'act3','exploder')and intent.id=='wait'then return 'Exploder wait has effects'end
 if policy(enemy,'act1_boss')then return 'inactive enemy intent has effects'end
end
local function inactiveMove(enemy,intent)
 if policy(enemy,'darkling')and (intent.id=='regrow'or intent.id=='reincarnate')then return 'Darkling inactive move has effects'end
 if intent.kind=='unknown'then return unknownInactive(enemy,intent)end
 if intent.kind=='sleep'or intent.kind=='stunned'then return 'inactive enemy intent has effects'end
end
local function validateIntent(enemy,intent)
 if require('abyss_act4_enemies').validateIntent(enemy,intent)then return end
 if intent.kind=='charge'or intent.kind=='split'or intent.kind=='escape'then return specialMove(enemy,intent)end
 local inactive=inactiveMove(enemy,intent)
 if inactive then assert(type(intent.effects)=='table'and next(intent.effects)==nil,inactive)
 else assert(Effects.supported(intent.effects),'unsupported enemy intent')end
end
local function sampleHp(state,enemy,explicitHp,hpRandom)
 if not explicitHp and enemy.ai and enemy.ai.preHpRoll then hpRandom(state,enemy.ai.preHpRoll)end
 if explicitHp then enemy.hp=explicitHp
 elseif enemy.hpRange then enemy.hp=enemy.hpRange.min+hpRandom(state,enemy.hpRange.max-enemy.hpRange.min+1)-1
 elseif state.monsterHpRng and not(enemy.ai and enemy.ai.noHpRoll)then hpRandom(state,1)end
end
function M.make(state,id,serial,explicitHp,hpRandom)
 local enemy=Copy(assert(state.catalog.enemies[id],'unknown enemy: '..tostring(id)))
 if policy(enemy,'act3','transient')then require('abyss_act3_enemies').bindSharedStatuses(state.catalog.statuses,Copy)end
 sampleHp(state,enemy,explicitHp,hpRandom)
 EnemyAI.prepare(state,enemy,hpRandom)
 for _,intent in ipairs(enemy.intents)do validateIntent(enemy,intent)end
 enemy.definitionId,enemy.id,enemy.maxHp=id,id..'_'..serial,enemy.hp
 enemy.block,enemy.statuses,enemy.intentIndex=0,{},1
 Actors.bindStatuses(enemy,state.catalog.statuses)
 return enemy
end
local function sourceSpec(options)
 if options.sourceEncounter~=nil then
  assert(Formation.supports(options.sourceEncounter),'unknown source formation')
  assert(options.enemies==nil,'source formation cannot mix with explicit enemies')
  assert(type(options.encounterBoundary)=='table','source formation needs explicit boundaries')
 end
end
function M.group(state,options,construct)
 sourceSpec(options)
 if options.sourceEncounter~=nil then
  local callbacks,constructors=options.encounterBoundary,0
  state.enemies=Formation.assemble(options.sourceEncounter,{
   misc=callbacks.misc,visualFloat=callbacks.visualFloat,construct=function(id,x,y)
    constructors=constructors+1
    local actor=construct(state,id,constructors);actor.sourcePosition={x=x,y=y};return actor
   end})
  state.sourceEncounter=options.sourceEncounter
  for i,enemy in ipairs(state.enemies)do enemy.id=enemy.definitionId..'_'..i end
  state.nextEnemyId=#state.enemies+1
 else
  local ids=options.enemies or {'cultist'};assert(#ids>0,'empty encounter')
  for i,id in ipairs(ids)do state.enemies[#state.enemies+1]=construct(state,id,i);state.nextEnemyId=i+1 end
 end
end
local function constructorCatalog(data)
 local prepared=require('abyss_colorless_cards').withCards(data)
 local catalog={cards=index(Copy(prepared.cards.cards)),enemies=index(Copy(prepared.enemies.enemies)),
  statuses=index(Copy(prepared.statuses.statuses)),potions=index(Copy(prepared.potions and prepared.potions.potions or {}))}
 M.register(catalog);return catalog
end
local function keys(catalog)
 local result={}
 for _,kind in ipairs({'cards','enemies','statuses'})do
  result[kind]={};for id in pairs(catalog[kind])do result[kind][id]=true end
 end
 return result
end
local function additions(catalog,before)
 local result={}
 for kind,ids in pairs(before)do
  result[kind]={};for id,definition in pairs(catalog[kind])do if not ids[id]then result[kind][id]=Copy(definition)end end
 end
 return result
end
function M.prepare(data,options,construct)
 assert(type(options)=='table'and type(options.roomSeed)=='string','preparation needs raw room seed')
 assert(options.preparedEncounter==nil,'cannot prepare an already prepared encounter')
 assert(options.sourceEncounter~=nil or options.enemies~=nil,'preparation needs explicit encounter identity')
 sourceSpec(options)
 local streams=assert(options.roomStreams,'preparation needs source room streams')
 local state={catalog=constructorCatalog(data),monsterHpRng=Random.cloneState(streams.monsterHpRng),
  enemies={},nextEnemyId=1,roomSeed=options.roomSeed}
 local before=keys(state.catalog)
 M.group(state,options,construct)
 local ids={};for _,actor in ipairs(state.enemies)do ids[#ids+1]=actor.definitionId end
 return {version=1,roomSeed=options.roomSeed,sourceEncounter=options.sourceEncounter,enemyIds=Copy(options.enemies),
  actorIds=ids,actors=state.enemies,monsterHpRng=Random.snapshot(state.monsterHpRng),catalogAdditions=additions(state.catalog,before)}
end
local function validatePrepared(prepared,options)
 assert(type(prepared)=='table'and prepared.version==1,'invalid prepared encounter')
 assert(prepared.roomSeed==options.roomSeed,'prepared encounter room seed mismatch')
 assert(options.enemies==nil and options.sourceEncounter==nil,'prepared encounter cannot mix with enemies or source formation')
 if prepared.sourceEncounter~=nil then
  assert(Formation.supports(prepared.sourceEncounter),'prepared encounter source missing')
  assert(prepared.enemyIds==nil,'prepared formation cannot mix with explicit enemies')
 else
  assert(type(prepared.enemyIds)=='table','prepared explicit enemy identities missing')
 end
 assert(type(prepared.actors)=='table'and #prepared.actors>0,'empty prepared encounter')
 assert(type(prepared.actorIds)=='table'and #prepared.actorIds==#prepared.actors,'prepared actor identities missing')
end
local function adoptAdditions(catalog,preparedAdditions)
 for _,kind in ipairs({'cards','enemies','statuses'})do
  for id,definition in pairs(preparedAdditions[kind]or {})do
   assert(not catalog[kind][id],'prepared constructor definition conflicts with current catalog')
   catalog[kind][id]=Copy(definition)
  end
 end
end
local function validateActor(state,actor,actorIndex,prepared)
 assert(state.catalog.enemies[actor.definitionId],'prepared enemy definition missing')
 assert(actor.definitionId==prepared.actorIds[actorIndex],'prepared actor identity mismatch')
 assert(actor.id==actor.definitionId..'_'..actorIndex and actor.hp==actor.maxHp and actor.hp>0,'invalid prepared enemy identity or HP')
 assert(actor.block==0 and actor.intentIndex==1 and type(actor.statuses)=='table'and next(actor.statuses)==nil,'prepared actor already initialized')
 if prepared.enemyIds then assert(actor.definitionId==prepared.enemyIds[actorIndex],'prepared actor source mismatch')end
 Actors.bindStatuses(actor,state.catalog.statuses)
end
function M.adopt(state,options)
 local prepared=options.preparedEncounter;validatePrepared(prepared,options)
 assert(state.roomSeed==prepared.roomSeed,'prepared encounter requires source room streams')
 adoptAdditions(state.catalog,assert(prepared.catalogAdditions,'prepared constructor definitions missing'))
 state.monsterHpRng=Random.restore(prepared.monsterHpRng)
 state.enemies=Copy(prepared.actors)
 for i,actor in ipairs(state.enemies)do validateActor(state,actor,i,prepared)end
 state.sourceEncounter=prepared.sourceEncounter;state.nextEnemyId=#state.enemies+1
end
return M
