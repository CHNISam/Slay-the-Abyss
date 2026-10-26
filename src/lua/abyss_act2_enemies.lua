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
 ['Champ']={id='act2_champ',tier='boss',enemies={'champ'}},
}
function M.resolve(source,tier)
 local room=rooms[source]
 if not room then return nil,'act_content_unavailable' end
 if tier~=(room.tier or 'normal') then return nil,'encounter_tier_mismatch' end
 local enemies={};for i,id in ipairs(room.enemies)do enemies[i]=id end
 return {id=room.id,tier=tier,source=source,enemies=enemies}
end
return M
