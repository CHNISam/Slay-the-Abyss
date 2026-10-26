-- Audited A0 slice only. Keep every other source encounter explicitly unavailable.
local M={}
M.enemies={{id='orb_walker',sourceId='Orb Walker',name='Orb Walker',tier='normal',hp=96,
 hpRange={min=90,max=96},ai={kind='act3',policy='orb_walker',preHpRoll=7},intents={
  {id='laser',kind='attack',effects={{op='damage',value=10},{op='enemyBurnBoth'}}},
  {id='claw',kind='attack',effects={{op='damage',value=15}}},
 }},
 {id='repulsor',sourceId='Repulsor',name='Repulsor',tier='normal',hp=35,hpRange={min=29,max=35},
  ai={kind='act3',policy='repulsor'},intents={
   {id='attack',kind='attack',effects={{op='damage',value=11}}},
   {id='daze',kind='debuff',effects={{op='enemyDazedDraw'}}}}},
 {id='spiker',sourceId='Spiker',name='Spiker',tier='normal',hp=56,hpRange={min=42,max=56},
  ai={kind='act3',policy='spiker'},intents={
   {id='attack',kind='attack',effects={{op='damage',value=7}}},
   {id='spike',kind='buff',effects={{op='gainStatus',status='thorns',value=2}}}}},
 {id='exploder',sourceId='Exploder',name='Exploder',tier='normal',hp=30,hpRange={min=30,max=30},
  ai={kind='act3',policy='exploder'},intents={
   {id='attack',kind='attack',effects={{op='damage',value=9}}},
   {id='wait',kind='unknown',effects={}}}},
 {id='maw',sourceId='Maw',name='Maw',tier='normal',hp=300,ai={kind='act3',policy='maw',noHpRoll=true},intents={
  {id='roar',kind='debuff',effects={{op='applyStatus',status='weak',value=3},{op='applyStatus',status='frail',value=3}}},
  {id='slam',kind='attack',effects={{op='damage',value=25}}},
  {id='drool',kind='buff',effects={{op='gainStatus',status='strength',value=3}}},
  {id='nom',kind='attack',effects={{op='damage',value=5,times=1}}}}},
 {id='spire_growth',sourceId='Serpent',name='Spire Growth',tier='normal',hp=170,hpRange={min=170,max=170},
  ai={kind='act3',policy='spire_growth'},intents={
   {id='tackle',kind='attack',effects={{op='damage',value=16}}},
   {id='constrict',kind='debuff',effects={{op='applyStatus',status='constricted',value=10}}},
   {id='smash',kind='attack',effects={{op='damage',value=22}}}}},
}
M.statuses={{id='generic_strength_up',sourceId='Generic Strength Up Power',name='成长',
 kind='buff',stack='intensity',decay='none',description='每轮结束时，获得等同层数的力量。'},
 {id='explosive',sourceId='Explosive',name='自爆',kind='buff',stack='duration',decay='none',
  description='每次行动后倒计时减1；倒计时为1时行动后自毁，造成30点反伤类型伤害。'},
 {id='constricted',sourceId='Constricted',name='束缚',kind='debuff',stack='intensity',decay='none',priority=105,
  description='你的回合结束时，受到等同层数的反伤类型伤害。'}}
local formations={['3 Shapes']='act3_three_shapes',['4 Shapes']='act3_four_shapes',
 ['Sphere and 2 Shapes']='act3_sphere_two_shapes'}
function M.resolve(source,tier)
 local single=source=='Orb Walker'and 'orb_walker'or source=='Maw'and 'maw'or source=='Spire Growth'and 'spire_growth'
 if not single and not formations[source]then return nil,'act_content_unavailable'end
 if tier~='normal'then return nil,'encounter_tier_mismatch'end
 if formations[source]then return {id=formations[source],tier=tier,source=source,sourceEncounter=source}end
 return {id='act3_'..single,tier=tier,source=source,enemies={single}}
end
return M
