// Visual proposals only: keys are immutable gameplay definition IDs. Reuse is
// deliberate; these choices do not promise original-monster resemblance.
const groups={
 guard:{assetId:30005001,displayName:'遗迹战械',reuseGroup:'ruin-guard',reason:'现成无武器攻击与受击动画；机关/重型单位共用'},
 hydro:{assetId:30005006,displayName:'凝水团',reuseGroup:'hydro-slime',reason:'同一原生模型按体型缩放，覆盖分裂大小态'},
 geo:{assetId:30005008,displayName:'磐岩团',reuseGroup:'geo-slime',reason:'复用岩史莱姆，不重做虫/寄生兽精确外形'},
 pyro:{assetId:30005007,displayName:'炽焰团',reuseGroup:'pyro-slime',reason:'以元素与颜色区分轻型敌人'},
 hilichurl:{assetId:30007001,displayName:'丘丘侍从',reuseGroup:'hilichurl',reason:'复用已读无武器攻击，缩放/名字区分小魔职责'},
 scout:{assetId:30006009,displayName:'盗宝团众',reuseGroup:'treasure-hoarder',reason:'轻型人形共用；投掷物挂载及命中时机仍需逐项验证'},
 caster:{assetId:30006012,displayName:'净水术士',reuseGroup:'eremite-caster',reason:'人形术士共用；表现标签与状态区分职责'},
 axe:{assetId:30005002,displayName:'丘丘斗魁',reuseGroup:'axe-mitachurl',reason:'大型近战复用；武器挂载属于剩余表现工作'},
 shield:{assetId:30006005,displayName:'木盾卫士',reuseGroup:'shield-mitachurl',reason:'原生盾持有者；盾/武器挂点仍需验证'},
 frost:{assetId:30006006,displayName:'霜铳重卫',reuseGroup:'frost-fatui',reason:'重型人形共用；武器挂载仍需验证'},
 bird:{assetId:30001014,displayName:'浮流鸟',reuseGroup:'floating-bird',fallbackAssetId:30005003,reason:'目录有鸟模型但非复杂造物，AI隔离/动画调用待核；可退回已有风史莱姆'},
 fungus:{assetId:30002013,displayName:'有翼冰本真蕈',reuseGroup:'fungus',fallbackAssetId:30005005,reason:'目录有蕈兽但非复杂造物；可退回已读冰史莱姆'},
 maw:{assetId:30006017,displayName:'匿叶龙山王',reuseGroup:'yumkasaur-boss',fallbackAssetId:30005008,reason:'目录候选，未读取该模型动画；允许复用大型岩团作低成本替代'},
 plant:{assetId:30005013,displayName:'窟岩显化身',reuseGroup:'geo-wayob',fallbackAssetId:30005008,reason:'用原生元素造物替代植物/团块；动画未读，可先用岩团'},
 kenki:{assetId:30006010,displayName:'魔偶剑鬼',reuseGroup:'maguu-kenki',fallbackAssetId:30005001,reason:'目录候选，动作/武器/形态未读；可先用已有遗迹守卫'},
 grader:{assetId:30005011,displayName:'遗迹重机',reuseGroup:'ruin-grader',fallbackAssetId:30005001,reason:'目录候选，攻击动画未读；可先用已有遗迹守卫'},
 heart:{assetId:30005014,displayName:'溯流显化身',reuseGroup:'hydro-wayob',fallbackAssetId:30005006,reason:'作为终幕核心的可复用原生外观候选；动画与画面需验证'},
 orb:{assetId:null,displayName:null,reuseGroup:'keep-simple-orb-shapes',reason:'球/多面体敌人本来适合低成本shape，保留清晰轮廓和状态，不强行换人形'},
 dagger:{assetId:null,displayName:null,reuseGroup:'keep-simple-dagger-shape',reason:'召唤飞刃保留简单shape；不为短命实体引入独立骨骼与武器系统'},
 sixfire:{assetId:null,displayName:null,reuseGroup:'keep-six-orbs',reason:'六个简洁球体加官方火元素特效，比不匹配的人形模型更省维护'},
};
const assignments={
 acid_slime_l:'hydro',acid_slime_m:'hydro',acid_slime_s:'hydro',slime_boss:'hydro',
 spike_slime_l:'geo',spike_slime_m:'geo',spike_slime_s:'geo',red_louse:'pyro',green_louse:'geo',
 jaw_worm:'geo',jaw_worm_hard:'geo',shelled_parasite:'geo',darkling:'geo',
 cultist:'caster',chosen:'caster',mystic:'caster',collector:'caster',reptomancer:'caster',
 mad_gremlin:'hilichurl',sneaky_gremlin:'hilichurl',fat_gremlin:'hilichurl',shield_gremlin:'hilichurl',wizard_gremlin:'hilichurl',torch_head:'hilichurl',
 looter:'scout',mugger:'scout',blue_slaver:'scout',red_slaver:'scout',taskmaster:'scout',bandit_pointy:'scout',bandit_leader:'scout',
 bandit_bear:'axe',gremlin_nob:'axe',gremlin_leader:'axe',champ:'axe',centurion:'shield',spire_shield:'shield',spire_spear:'axe',
 guardian:'guard',lagavulin:'guard',lagavulin_awake:'guard',automaton:'guard',orb_walker:'guard',giant_head:'guard',
 awakened_one:'frost',byrd:'bird',fungi_beast:'fungus',maw:'maw',snecko:'maw',snake_plant:'plant',spire_growth:'plant',writhing_mass:'plant',
 nemesis:'kenki',time_eater:'grader',corrupt_heart:'heart',transient:'kenki',
 spheric_guardian:'orb',sentry:'orb',bronze_orb:'orb',repulsor:'orb',spiker:'orb',exploder:'orb',deca:'orb',donu:'orb',
 snake_dagger:'dagger',hexaghost:'sixfire',book_of_stabbing:'dagger',
};
export const scaleById={acid_slime_s:.4,acid_slime_m:.7,acid_slime_l:1,slime_boss:1.5,spike_slime_s:.4,spike_slime_m:.7,spike_slime_l:1,
 red_louse:.35,green_louse:.35,mad_gremlin:.65,sneaky_gremlin:.6,fat_gremlin:.75,shield_gremlin:.65,wizard_gremlin:.65,torch_head:.7};
export function proposalFor(id){const key=assignments[id];if(!key)throw Error('Unmapped registered enemy: '+id);return {...groups[key],strategy:groups[key].assetId?'native-model':'keep-shapes',scale:scaleById[id]??1};}
export const assignmentIds=Object.freeze(Object.keys(assignments));
// Phase entries never create replacement rule IDs. They describe presentation
// states of the same registered definition, including downed/revive states.
export const phases=Object.freeze([
 {enemyId:'lagavulin',states:['sleeping','awake'],source:'src/lua/abyss_enemy_ai.lua',presentation:'同定义的sleep/awake状态；事件lagavulin_awake是主表中的另一个现有定义，不改ID'},
 {enemyId:'hexaghost',states:['inactive','active'],source:'src/lua/abyss_act1_bosses.lua',presentation:'六焰核启动/活跃状态保留简单shape与官方光效；不是另一规则定义'},
 {enemyId:'transient',states:['present','fading','removed'],source:'src/lua/abyss_act3_ai.lua',presentation:'Fading到期离场和永久击杀分开，只读核心的移除结果，不用原生AI扣血驱动'},
 {enemyId:'guardian',states:['offensive','defensive'],source:'src/lua/abyss_guardian_ai.lua',presentation:'同模型；防御态用盾/姿态/官方特效，未证明存在直接变形clip'},
 {enemyId:'slime_boss',states:['whole','split'],source:'src/lua/abyss_act1_bosses.lua',presentation:'split生成acid_slime_l和spike_slime_l，二者已在67种分母中'},
 {enemyId:'acid_slime_l',states:['whole','split'],source:'data/enemies.json',presentation:'分裂到已有acid_slime_m；同模型缩放，保持真实子实体ID'},
 {enemyId:'spike_slime_l',states:['whole','split'],source:'data/enemies.json',presentation:'分裂到已有spike_slime_m；同模型缩放，保持真实子实体ID'},
 {enemyId:'byrd',states:['airborne','grounded','takeoff'],source:'src/lua/abyss_act2_ai.lua',presentation:'飞行/落地状态只读核心flight状态；鸟模型动画未读，不能当作已覆盖'},
 {enemyId:'champ',states:['normal','enraged'],source:'src/lua/abyss_act2_ai_moves.lua',presentation:'同模型加原生光效/状态标识，无需新规则定义'},
 {enemyId:'awakened_one',states:['first','half-dead','rebirth','second'],source:'src/lua/abyss_awakened_one.lua',presentation:'同规则ID/同模型；重生期间不能被普通死亡清除'},
 {enemyId:'darkling',states:['alive','half-dead','regrow','reincarnate'],source:'src/lua/abyss_darklings.lua',presentation:'同规则ID；halfDead不等于永久死亡，不能destroy后丢失槽位'},
 {enemyId:'nemesis',states:['tangible','intangible'],source:'src/lua/abyss_nemesis.lua',presentation:'同模型配透明/轮廓特效；不伪造原生无敌改变Lua规则'},
]);
