-- A0 Donu/Deca rules, independently implemented from sts@319009d5.
-- MonsterHelper constructs Deca first; Combat owns the shared group outcome.
local Actors=require('abyss_actor')
local M={}
local function move(id,kind,effects)return {id=id,kind=kind,effects=effects}end
M.enemies={
 {id='deca',sourceId='Deca',name='棱岩守望者',tier='boss',hp=250,
  sourcePosition={x=-350,y=30},ai={kind='act3_boss',policy='deca'},intents={
   move('beam','attack',{{op='damage',value=10,times=2},{op='makeTempCardInDiscard',card='dazed',value=2}}),
   move('square','defend',{{op='block',value=16,fixed=true,target='all_allies'}})}},
 {id='donu',sourceId='Donu',name='环岩守望者',tier='boss',hp=250,
  sourcePosition={x=100,y=20},ai={kind='act3_boss',policy='donu'},intents={
   move('circle','buff',{{op='enemyStrengthAll',value=3}}),
   move('beam','attack',{{op='damage',value=10,times=2}})}},
}
local function select(e,id)
 for i,intent in ipairs(e.intents)do if intent.id==id then e.intentIndex=i;return end end
 error('unknown Act3 Boss intent: '..tostring(id))
end
function M.register(catalog,copy)
 for _,enemy in ipairs(M.enemies)do
  assert(not catalog.enemies[enemy.id],'duplicate Act3 Boss')
  catalog.enemies[enemy.id]=copy(enemy)
 end
end
function M.initialize(state,e,random)
 random(state,100) -- inherited init -> rollMove, despite deterministic getMove.
 select(e,e.ai.policy=='deca' and 'beam' or 'circle')
end
function M.preBattle(state,e)
 Actors.applyPower(state,e,'artifact',2,e) -- three is A19, not A0.
end
function M.afterAction(state,e,random,executedIntent)
 random(state,100) -- queued RollMove survives caster death while its ally lives.
 local defending=e.ai.policy=='deca' and 'square' or 'circle'
 select(e,executedIntent.id=='beam' and defending or 'beam')
end
function M.resolve(source,tier)
 if source~='Donu and Deca'then return nil,'act_content_unavailable'end
 if tier~='boss'then return nil,'encounter_tier_mismatch'end
 return {id='act3_donu_deca',tier='boss',source=source,enemies={'deca','donu'}}
end
return M
