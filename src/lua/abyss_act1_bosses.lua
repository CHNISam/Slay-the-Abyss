-- Independent A0 behavior from sts@319009d5 Exordium bosses and
-- BurnIncreaseAction. Combat owns construction, damage, splits and queued rolls.
local Events=require('abyss_events')
local M={}
local function move(id,kind,effects)return {id=id,kind=kind,effects=effects}end
local function damage(value,times)return {op='damage',value=value,times=times}end
M.enemies={
 {id='hexaghost',name='六焰幽核',tier='boss',hp=250,ai={kind='act1_boss',policy='hexaghost'},intents={
  move('activate','unknown',{}),move('divider','attack',{damage(1,6)}),
  move('sear','attack',{damage(6),{op='makeTempCardInDiscard',card='burn',value=1}}),
  move('tackle','attack',{damage(5,2)}),
  move('inflame','defend',{{op='block',value=12,fixed=true},{op='gainStatus',status='strength',value=2}}),
  move('inferno','attack',{damage(2,6)})}},
 {id='slime_boss',name='巨型凝胶君王',tier='boss',hp=140,ai={kind='act1_boss',policy='slime_boss',
  splitHpDivisor=2,splitIntent='split',splitCount=2,splitEnemies={'spike_slime_l','acid_slime_l'},
  splitPositions={{x=-385,y=20},{x=120,y=-8}}},intents={
  move('sticky','debuff',{{op='makeTempCardInDiscard',card='slimed',value=3}}),
  move('prepare','unknown',{}),move('slam','attack',{damage(35)}),move('split','split',{})}},
}
function M.register(catalog,copy)
 for _,enemy in ipairs(M.enemies)do
  assert(not catalog.enemies[enemy.id],'duplicate Act1 Boss')
  catalog.enemies[enemy.id]=copy(enemy)
 end
 -- The older native catalog stores Burn's end-turn damage directly. The
 -- full-class catalog uses burnDamage; preserve each existing lifecycle ABI.
 local burn=catalog.cards.burn
 if not burn then return end -- Custom isolated catalogs retain their old boundary.
 assert(burn.endTurnDamage==2 or burn.burnDamage==2,'incompatible Burn definition')
 burn.upgrade=burn.upgrade or {}
 if burn.endTurnDamage then burn.upgrade.endTurnDamage=4 end
 burn.burnDamage=2;burn.upgrade.burnDamage=4
 burn.upgradeText='无法打出。回合结束时受到4点伤害。'
end
local function select(e,id)
 for i,intent in ipairs(e.intents)do if intent.id==id then e.intentIndex=i;return end end
 error('unknown Act1 Boss intent: '..tostring(id))
end
local cycle={'sear','tackle','sear','inflame','tackle','sear','inferno'}
function M.initialize(state,e,random)
 random(state,100) -- inherited AbstractMonster.init -> rollMove, even if fixed.
 if e.ai.policy=='hexaghost'then
  e.hexOrbs,e.hexBurnUpgraded=0,false
  select(e,'activate')
 else select(e,'sticky')end
end
function M.beforeAction(state,e,intent)
 e.act1ExecutingIntent=intent.id
 if e.ai.policy~='hexaghost'then return end
 if intent.id=='activate'then
  -- takeTurn captures current health now, not when Divider is later executed.
  for _,nextIntent in ipairs(e.intents)do
   if nextIntent.id=='divider'then nextIntent.effects[1].value=math.floor(state.player.hp/12)+1 end
  end
 elseif intent.id=='sear'then intent.effects[2].upgraded=e.hexBurnUpgraded==true
 elseif intent.id=='inferno'then e.hexBurnUpgraded=true end
end
function M.afterAction(state,e,random,intent)
 if e.ai.policy=='slime_boss'then
  -- These are immediate setMove transitions, never RollMoveAction. A damage
  -- interrupt during Slam queues SetMove(split) after its earlier setMove.
  if e.splitTriggered or intent.id=='split'then select(e,'split')
  else select(e,({sticky='prepare',prepare='slam',slam='sticky'})[intent.id])end
  return
 end
 if intent.id=='activate'then e.hexOrbs=6;select(e,'divider');return end
 if intent.id=='divider' or intent.id=='inferno'then e.hexOrbs=0
 else e.hexOrbs=e.hexOrbs+1 end
 random(state,100) -- each ordinary turn queues a roll although getMove ignores it.
 select(e,assert(cycle[e.hexOrbs+1],'invalid Hexaghost orb count'))
end
function M.hpLost(state,e,before,damageCall)
 if e.ai.policy~='slime_boss' or not (damageCall or e.hp<before)
  or e.hp<=0 or e.splitTriggered or e.hp>e.maxHp/2 then return end
 e.splitTriggered=true;select(e,'split')
 Events.emit(state,'enemy_interrupt',{enemy=e.id,id='split'})
end
function M.afterEffects(state,e)
 if e.ai.policy~='hexaghost' or e.act1ExecutingIntent~='inferno' or state.player.hp<=0 then return end
 e.act1ExecutingIntent=nil -- one queued BurnIncrease, never later callback batches.
 -- BurnIncreaseAction upgrades discard then draw. Hand/exhaust are excluded.
 for _,pile in ipairs({state.discard,state.draw})do
  for _,card in ipairs(pile)do
   if card.cardId=='burn' and not card.upgraded then card.upgraded=true;card.upgrades=1 end
  end
 end
 local uid=state.nextUid
 assert(type(uid)=='number' and uid>0 and uid%1==0 and uid+3.0<math.huge,'invalid Burn UID')
 for n=0,2 do assert(uid+n+1.0>uid+n,'Burn UID cannot advance')end
 for n=0,2 do state.discard[#state.discard+1]={uid=uid+n+0.0,cardId='burn',upgraded=true,upgrades=1}end
 state.nextUid=uid+3.0
 Events.emit(state,'cards_created',{source=e.id,cardId='burn',amount=3,pile='discard'})
end
function M.resolve(source,tier)
 if tier~='boss'then return nil,'encounter_tier_mismatch'end
 local ids={['The Guardian']='guardian',['Hexaghost']='hexaghost',['Slime Boss']='slime_boss'}
 local id=ids[source]
 if not id then return nil,'unknown_source_encounter'end
 return {id='boss_'..id,tier='boss',source=source,enemies={id}}
end
return M
