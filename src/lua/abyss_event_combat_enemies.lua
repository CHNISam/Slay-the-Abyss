-- A0 event-only constructors/SetMove policies; sts 319009d5, no Java copied.
-- Awake Lagavulin is NOT the ordinary sleeping elite constructor.
local M={}
local function damage(n,times)return {op='damage',value=n,times=times}end
local function status(id,n)return {op='applyStatus',status=id,value=n}end
local function move(id,kind,effects)return {id=id,kind=kind,effects=effects}end
M.enemies={
 {id='bandit_pointy',name='尖刺盗匪',tier='normal',hp=30,ai={kind='event_combat',policy='pointy'},intents={
  move('pointy_special','attack',{damage(5,2)})}},
 {id='bandit_leader',name='蒙面首领',tier='normal',hp=39,hpRange={min=35,max=39},ai={kind='event_combat',policy='romeo'},intents={
  move('mock','unknown',{}),move('agonizing_slash','attack',{damage(10),status('weak',2)}),move('cross_slash','attack',{damage(15)})}},
 {id='bandit_bear',name='巨熊盗匪',tier='normal',hp=42,hpRange={min=38,max=42},ai={kind='event_combat',policy='bear'},intents={
  move('bear_hug','debuff',{status('dexterity',-2)}),move('lunge','attack',{damage(9),{op='block',value=9}}),move('maul','attack',{damage(18)})}},
 {id='lagavulin_awake',name='苏醒的深渊潜伏者',tier='elite',hp=111,hpRange={min=109,max=111},ai={kind='event_combat',policy='lagavulin_awake'},intents={
  move('siphon','debuff',{status('dexterity',-1),status('strength',-1)}),move('attack','attack',{damage(18)})}},
}
function M.register(catalog,copy)
 for _,definition in ipairs(M.enemies)do
  assert(not catalog.enemies[definition.id],'duplicate event enemy')
  catalog.enemies[definition.id]=copy(definition)
 end
end
function M.owns(enemy)return enemy.ai and enemy.ai.kind=='event_combat'end
local function select(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('unknown event enemy intent '..tostring(id))
end
function M.initialize(state,enemy,random)
 random(state,100) -- inherited AbstractMonster.init/rollMove, even fixed getMove
 enemy.eventAttacks=0
 select(enemy,enemy.intents[1].id)
end
function M.advance(state,enemy,random)
 local policy,id=enemy.ai.policy,enemy.intents[enemy.intentIndex].id
 if policy=='lagavulin_awake'then
  random(state,100) -- every turn enqueues RollMove, unlike the bandits
  if id=='siphon'then enemy.eventAttacks=0;select(enemy,'attack')
  else enemy.eventAttacks=enemy.eventAttacks+1;select(enemy,enemy.eventAttacks==2 and'siphon'or'attack')end
 elseif policy=='bear'then select(enemy,id=='lunge'and'maul'or'lunge')
 elseif policy=='romeo'then select(enemy,id=='agonizing_slash'and'cross_slash'or'agonizing_slash')
 else assert(policy=='pointy','unsupported event enemy AI');select(enemy,'pointy_special')end
end
function M.afterAction(state,enemy,random)return M.advance(state,enemy,random)end
return M
