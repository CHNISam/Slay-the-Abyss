-- Independent A0 facts from sts@319009d5 city monsters; see ACT2_ENEMIES.md.
local M={}
local function damage(n,times)return {op='damage',value=n,times=times}end
local function status(id,n)return {op='applyStatus',status=id,value=n}end
local function move(id,kind,effects)return {id=id,kind=kind,effects=effects}end
M.enemies={
 {id='spheric_guardian',name='磐核守卫',tier='normal',hp=20,ai={kind='act2',policy='sphere',noHpRoll=true},intents={
  move('activate','defend',{{op='block',value=25,fixed=true}}),
  move('frail_attack','attack',{damage(10),status('frail',5)}),
  move('slam','attack',{damage(10,2)}),
  move('harden','attack',{{op='block',value=15,fixed=true},damage(10)})}},
 {id='centurion',name='岩卫统领',tier='normal',hp=80,hpRange={min=76,max=80},ai={kind='act2',policy='centurion'},intents={
  move('slash','attack',{damage(12)}),
  move('protect','defend',{{op='block',value=15,target='random_ally'}}),
  move('fury','attack',{damage(6,3)})}},
 {id='mystic',name='祈岩医者',tier='normal',hp=56,hpRange={min=48,max=56},ai={kind='act2',policy='mystic'},intents={
  move('attack','attack',{damage(8),status('frail',2)}),
  move('heal','buff',{{op='enemyHealAll',value=16}}),
  move('buff','buff',{{op='enemyStrengthAll',value=2}})}},
 {id='taskmaster',name='缚役监军',tier='elite',hp=60,hpRange={min=54,max=60},ai={kind='act2',policy='taskmaster',preHpRoll=7},intents={
  move('whip','attack',{damage(7),{op='makeTempCardInDiscard',card='wound',value=1}})}},
 {id='book_of_stabbing',name='刺棘秘典',tier='elite',hp=164,hpRange={min=160,max=164},ai={kind='act2',policy='book'},intents={
  move('multi_stab','attack',{damage(6,2)}),move('big_stab','attack',{damage(21)})}},
 {id='snake_plant',name='噬岩藤',tier='normal',hp=79,hpRange={min=75,max=79},ai={kind='act2',policy='snake'},intents={
  move('chomp','attack',{damage(7,3)}),move('spores','debuff',{status('frail',2),status('weak',2)})}},
 {id='chosen',name='蚀咒使徒',tier='normal',hp=99,hpRange={min=95,max=99},ai={kind='act2',policy='chosen'},intents={
  move('poke','attack',{damage(5,2)}),move('hex','debuff',{status('hex',1)}),
  move('zap','attack',{damage(18)}),move('debilitate','attack',{damage(10),status('vulnerable',2)}),
  move('drain','debuff',{status('weak',3),{op='gainStatus',status='strength',value=3}})}},
 {id='shelled_parasite',name='岩甲寄生兽',tier='normal',hp=72,hpRange={min=68,max=72},ai={kind='act2',policy='parasite'},intents={
  move('fell','attack',{damage(18),status('frail',2)}),move('double_strike','attack',{damage(6,2)}),
  move('life_suck','attack',{{op='enemyVampireDamage',value=10}}),move('stunned','stunned',{})}},
 {id='byrd',name='巡风隼',tier='normal',hp=31,hpRange={min=25,max=31},ai={kind='act2',policy='byrd'},intents={
  move('peck','attack',{damage(1,5)}),move('swoop','attack',{damage(12)}),
  move('caw','buff',{{op='gainStatus',status='strength',value=1}}),
  move('stunned','stunned',{}),move('headbutt','attack',{damage(3)}),
  move('airborne','buff',{{op='gainStatus',status='flight',value=3}})}},
 {id='snecko',name='惑心蜥',tier='normal',hp=120,hpRange={min=114,max=120},ai={kind='act2',policy='snecko'},intents={
  move('glare','debuff',{status('confusion',1)}),move('bite','attack',{damage(15)}),
  move('tail','attack',{damage(8),status('vulnerable',2)})}},
 {id='mugger',name='荒野劫匪',tier='normal',hp=52,hpRange={min=48,max=52},ai={kind='looter',mugger=true,
  mugIntent='mug',lungeIntent='lunge',smokeIntent='smoke',escapeIntent='escape',stealAmount=15,rollRange=100,
  talkChance=0.6000000238418579,smokeChance=0.5},intents={
  move('mug','attack',{damage(10)}),move('lunge','attack',{damage(16)}),
  move('smoke','defend',{{op='block',value=11}}),move('escape','escape',{})}},
 {id='gremlin_leader',name='丘丘督军',tier='elite',hp=148,hpRange={min=140,max=148},ai={kind='act2',policy='leader'},intents={
  move('stab','attack',{damage(6,3)}),move('rally','buff',{{op='enemyRally',value=2}}),
  move('encourage','buff',{{op='enemyEncourage',value=3}})}},
 {id='torch_head',name='炬火侍从',tier='normal',hp=40,hpRange={min=38,max=40},
  ai={kind='opening_roll_attack',attackIntent='tackle',rollRange=100,preHpRoll=3},intents={move('tackle','attack',{damage(7)})}},
 {id='collector',name='聚烬领主',tier='boss',hp=282,ai={kind='act2',policy='collector'},intents={
  move('spawn','buff',{{op='enemyTorchSpawn',value=2}}),move('revive','buff',{{op='enemyTorchRevive',value=1}}),
  move('fireball','attack',{damage(18)}),
  move('buff','defend',{{op='block',value=15,fixed=true},{op='enemyStrengthAll',value=3}}),
  move('mega_debuff','debuff',{status('weak',3),status('vulnerable',3),status('frail',3)})}},
 {id='automaton',name='青铜机枢',tier='boss',hp=300,ai={kind='act2',policy='automaton'},intents={
  move('spawn_orbs','buff',{{op='enemyBronzeSpawn',value=2}}),move('flail','attack',{damage(7,2)}),
  move('boost','defend',{{op='block',value=9,fixed=true},{op='gainStatus',status='strength',value=3}}),
  move('hyper_beam','attack',{damage(45)}),move('stunned','stunned',{})}},
 {id='bronze_orb',name='青铜浮核',tier='normal',hp=58,hpRange={min=52,max=58},ai={kind='act2',policy='orb',preHpRoll=7},intents={
  move('beam','attack',{damage(8)}),move('support','defend',{{op='block',value=12,target='automaton'}}),
  move('stasis','debuff',{{op='enemyStasis',value=1}})}},
 {id='champ',name='磐岩斗魁',tier='boss',hp=420,ai={kind='act2',policy='champ'},intents={
  move('heavy_slash','attack',{damage(16)}),
  move('defensive_stance','defend',{{op='block',value=15,fixed=true},{op='gainStatus',status='metallicize',value=5}}),
  move('execute','attack',{damage(10,2)}),
  move('face_slap','attack',{damage(12),status('frail',2),status('vulnerable',2)}),
  move('gloat','buff',{{op='gainStatus',status='strength',value=2}}),
  move('taunt','debuff',{status('weak',2),status('vulnerable',2)}),
  move('anger','buff',{{op='enemyCleanse',value=1},{op='gainStatus',status='strength',value=6}})}},
}
M.statuses={
 {id='painful_stabs',name='痛苦穿刺',kind='buff',stack='none',decay='none',description='攻击使目标损失生命时，将一张伤口放入弃牌堆。'},
 {id='malleable',name='韧性',kind='buff',stack='intensity',decay='none',description='受到非致命普通攻击生命伤害后获得格挡；每次递增1，行动结束重置为3。'},
 {id='hex',name='蚀咒',kind='debuff',stack='intensity',decay='none',description='使用非攻击牌后，将相应数量的晕眩随机放入抽牌堆。'},
 {id='flight',name='飞行',kind='buff',stack='intensity',decay='none',priority=50,description='受到的攻击伤害减半；受到3次未被完全格挡的攻击后坠地。行动前补满次数。'},
 {id='confusion',name='混乱',kind='debuff',stack='none',decay='none',priority=0,description='抽牌时，将非负费用牌的费用随机改为0至3；X费与不可打出的牌不受影响。'},
 {id='minion',name='随从',kind='buff',stack='none',decay='none',description='随首领登场的仆从，不提供独立击杀成长。'},
 {id='stasis',name='扣押',kind='buff',stack='none',decay='none',description='扣押一张抽牌堆或弃牌堆的牌；击败浮核后归还，满手牌时放入弃牌堆。'},
}
local rooms={
 ['Spheric Guardian']={id='act2_sphere',enemies={'spheric_guardian'}},
 ['Centurion and Healer']={id='act2_centurion_mystic',enemies={'centurion','mystic'}},
 -- Actual MonsterHelper formations which legitimately reuse Exordium actors.
 ['Sentry and Sphere']={id='act2_sentry_sphere',enemies={'sentry','spheric_guardian'}},
 ['3 Cultists']={id='act2_cultists',enemies={'cultist','cultist','cultist'}},
 ['Slavers']={id='act2_slavers',tier='elite',enemies={'blue_slaver','taskmaster','red_slaver'}},
 ['Book of Stabbing']={id='act2_book',tier='elite',enemies={'book_of_stabbing'}},
 ['Snake Plant']={id='act2_snake_plant',enemies={'snake_plant'}},
 ['Chosen']={id='act2_chosen',enemies={'chosen'}},
 ['Cultist and Chosen']={id='act2_cultist_chosen',enemies={'cultist','chosen'}},
 ['Shell Parasite']={id='act2_parasite',enemies={'shelled_parasite'}},
 ['Shelled Parasite and Fungi']={id='act2_parasite_fungi',enemies={'shelled_parasite','fungi_beast'}},
 ['3 Byrds']={id='act2_byrds',enemies={'byrd','byrd','byrd'}},
 ['Chosen and Byrds']={id='act2_chosen_byrd',enemies={'byrd','chosen'}},
 ['Snecko']={id='act2_snecko',enemies={'snecko'}},
 ['2 Thieves']={id='act2_thieves',enemies={'looter','mugger'}},
 ['Gremlin Leader']={id='act2_leader',tier='elite',sourceEncounter='Gremlin Leader'},
 ['Champ']={id='act2_champ',tier='boss',enemies={'champ'}},
 ['Collector']={id='act2_collector',tier='boss',enemies={'collector'}},
 ['Automaton']={id='act2_automaton',tier='boss',enemies={'automaton'}},
}
function M.resolve(source,tier)
 local room=rooms[source]
 if not room then return nil,'act_content_unavailable' end
 if tier~=(room.tier or 'normal') then return nil,'encounter_tier_mismatch' end
 if room.sourceEncounter then return {id=room.id,tier=tier,source=source,sourceEncounter=room.sourceEncounter} end
 local enemies={};for i,id in ipairs(room.enemies)do enemies[i]=id end
 return {id=room.id,tier=tier,source=source,enemies=enemies}
end
return M
