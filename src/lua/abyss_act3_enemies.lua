-- Audited A0 slice only. Keep every other source encounter explicitly unavailable.
local M={}
M.enemies={{id='orb_walker',sourceId='Orb Walker',name='Orb Walker',tier='normal',hp=96,
 hpRange={min=90,max=96},ai={kind='act3',policy='orb_walker',preHpRoll=7},intents={
  {id='laser',kind='attack',effects={{op='damage',value=10},{op='enemyBurnBoth'}}},
  {id='claw',kind='attack',effects={{op='damage',value=15}}},
 }}}
M.statuses={{id='generic_strength_up',sourceId='Generic Strength Up Power',name='成长',
 kind='buff',stack='intensity',decay='none',description='每轮结束时，获得等同层数的力量。'}}
function M.resolve(source,tier)
 if source~='Orb Walker'then return nil,'act_content_unavailable'end
 if tier~='normal'then return nil,'encounter_tier_mismatch'end
 return {id='act3_orb_walker',tier=tier,source=source,enemies={'orb_walker'}}
end
return M
