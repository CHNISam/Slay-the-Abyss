-- Audited A0 slice only. Keep every other source encounter explicitly unavailable.
local M={}
M.enemies={{id='orb_walker',sourceId='Orb Walker',name='雷核步行机关',tier='normal',hp=96,
 hpRange={min=90,max=96},ai={kind='act3',policy='orb_walker',preHpRoll=7},intents={
  {id='laser',kind='attack',effects={{op='damage',value=10},{op='enemyBurnBoth'}}},
  {id='claw',kind='attack',effects={{op='damage',value=15}}},
 }},
 {id='repulsor',sourceId='Repulsor',name='斥力浮械',tier='normal',hp=35,hpRange={min=29,max=35},
  ai={kind='act3',policy='repulsor'},intents={
   {id='attack',kind='attack',effects={{op='damage',value=11}}},
   {id='daze',kind='debuff',effects={{op='enemyDazedDraw'}}}}},
 {id='spiker',sourceId='Spiker',name='尖刺浮械',tier='normal',hp=56,hpRange={min=42,max=56},
  ai={kind='act3',policy='spiker'},intents={
   {id='attack',kind='attack',effects={{op='damage',value=7}}},
   {id='spike',kind='buff',effects={{op='gainStatus',status='thorns',value=2}}}}},
 {id='exploder',sourceId='Exploder',name='自爆浮械',tier='normal',hp=30,hpRange={min=30,max=30},
  ai={kind='act3',policy='exploder'},intents={
   {id='attack',kind='attack',effects={{op='damage',value=9}}},
   {id='wait',kind='unknown',effects={}}}},
 {id='maw',sourceId='Maw',name='吞岩巨口',tier='normal',hp=300,ai={kind='act3',policy='maw',noHpRoll=true},intents={
  {id='roar',kind='debuff',effects={{op='applyStatus',status='weak',value=3},{op='applyStatus',status='frail',value=3}}},
  {id='slam',kind='attack',effects={{op='damage',value=25}}},
  {id='drool',kind='buff',effects={{op='gainStatus',status='strength',value=3}}},
  {id='nom',kind='attack',effects={{op='damage',value=5,times=1}}}}},
 {id='spire_growth',sourceId='Serpent',name='盘岩巨藤',tier='normal',hp=170,hpRange={min=170,max=170},
  ai={kind='act3',policy='spire_growth'},intents={
   {id='tackle',kind='attack',effects={{op='damage',value=16}}},
   {id='constrict',kind='debuff',effects={{op='applyStatus',status='constricted',value=10}}},
   {id='smash',kind='attack',effects={{op='damage',value=22}}}}},
 {id='transient',sourceId='Transient',name='流散之影',tier='normal',hp=999,gold=1,
  ai={kind='act3',policy='transient',noHpRoll=true},intents={
   {id='attack',kind='attack',effects={{op='damage',value=30}}}}},
 {id='jaw_worm_hard',sourceId='JawWorm',name='石颚兽',tier='normal',hp=44,hpRange={min=40,max=44},
  ai={kind='jaw_worm',hardMode=true,preBattleStrength=3,preBattleBlock=6,
   chompIntent='chomp',thrashIntent='thrash',bellowIntent='bellow',rollRange=100,
   chompCutoff=25,thrashCutoff=55,bellowAfterChomp=.5625,
   chompAfterTwoThrashes=.3569999933242798,chompAfterBellow=.41600000858306885},intents={
   {id='chomp',kind='attack',effects={{op='damage',value=11}}},
   {id='thrash',kind='attack',effects={{op='damage',value=7},{op='block',value=5}}},
   {id='bellow',kind='buff',effects={{op='gainStatus',status='strength',value=3},{op='block',value=6}}}}},
}
M.statuses={{id='generic_strength_up',sourceId='Generic Strength Up Power',name='成长',
 kind='buff',stack='intensity',decay='none',description='每轮结束时，获得等同层数的力量。'},
 {id='explosive',sourceId='Explosive',name='自爆',kind='buff',stack='duration',decay='none',
  description='每次行动后倒计时减1；倒计时为1时行动后自毁，造成30点反伤类型伤害。'},
 {id='constricted',sourceId='Constricted',name='束缚',kind='debuff',stack='intensity',decay='none',priority=105,
  description='你的回合结束时，受到等同层数的反伤类型伤害。'},
 {id='shifting',sourceId='Shifting',name='变幻',kind='buff',stack='none',decay='none',
  description='受正伤害时，按格挡后伤害暂失力量，自身回合末归还；反伤与直接失血也触发。'},
 {id='fading',sourceId='Fading',name='消逝',kind='buff',stack='duration',decay='none',
  description='每次攻击后倒计时减1；为1时攻击后自毁，仍获得正常战斗奖励。'}}
local formations={['3 Shapes']='act3_three_shapes',['4 Shapes']='act3_four_shapes',
 ['Sphere and 2 Shapes']='act3_sphere_two_shapes',['Jaw Worm Horde']='act3_jaw_worm_horde'}
function M.resolve(source,tier)
 local single=source=='Orb Walker'and 'orb_walker'or source=='Maw'and 'maw'or source=='Spire Growth'and 'spire_growth'
  or source=='Transient'and 'transient'
 if not single and not formations[source]then return nil,'act_content_unavailable'end
 if tier~='normal'then return nil,'encounter_tier_mismatch'end
 if formations[source]then return {id=formations[source],tier=tier,source=source,sourceEncounter=source}end
 return {id='act3_'..single,tier=tier,source=source,enemies={single}}
end
-- GainStrengthPower is shared with Piercing Wail. Raw Core data may not have
-- the class catalog, while prepared Runs must retain the existing definition.
function M.bindSharedStatuses(catalog,copy)
 local existing=catalog.shackled
 if existing then
  assert(existing.id=='shackled'and existing.kind=='debuff'and existing.stack=='intensity'
   and existing.decay=='none'and (existing.priority or 5)==5
   and (existing.sourceId==nil or existing.sourceId=='Shackled'),'incompatible GainStrength Power')
 else catalog.shackled=copy({id='shackled',sourceId='Shackled',name='力量恢复',kind='debuff',
  stack='intensity',decay='none',description='此生物回合结束时恢复等同层数的力量，然后移除。'})end
end
return M
