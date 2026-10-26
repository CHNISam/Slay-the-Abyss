-- Pinned319009 facts and pure-data plans. The core owns all effects/choices.
local M={}
local function copy(v,path)
 local kind=type(v)
 if kind~='table'then assert(kind=='nil'or kind=='string'or kind=='boolean'or kind=='number'and v==v and math.abs(v)<math.huge,'non-data final card field');return v end
 path=path or {};assert(not getmetatable(v)and not path[v],'non-plain or cyclic final card data');path[v]=true
 local t={};for k,x in pairs(v)do assert(type(k)=='string'or type(k)=='number','invalid final card key');t[k]=copy(x,path)end;path[v]=nil;return t
end
local function e(op,n,extra)local a=extra or {};a.op=op;if n~=nil then a.value=n end;return a end
local function power(id,n)return e('gainWatcherFinalPower',n or 1,{status=id})end
local function make(id,n,pile,extra)local x=extra or {};x.cardId=id;x.pile=pile or 'draw';x.upgraded=x.upgraded==true;x.randomSpot=x.pile=='draw' or nil;return e('watcherFinalGenerate',n or 1,x)end
local specs={
 {'foreign_influence','ForeignInfluence','异界之援','skill','uncommon',0,{e('watcherFinalForeignInfluence',0)},{e('watcherFinalForeignInfluence',1)},{exhaust=true}},
 {'conclude','Conclude','终结','attack','uncommon',1,{e('damageAll',12),e('watcherFinalEndTurnEarly',1)},{e('damageAll',16),e('watcherFinalEndTurnEarly',1)}},
 {'meditate','Meditate','冥想','skill','uncommon',1,{e('watcherFinalMeditate',1),e('changeStance',nil,{stance='Calm'}),e('watcherFinalEndTurnEarly',1)},
  {e('watcherFinalMeditate',2),e('changeStance',nil,{stance='Calm'}),e('watcherFinalEndTurnEarly',1)}},
 {'swivel','Swivel','旋转','skill','uncommon',2,{e('block',8),power('free_attack')},{e('block',11),power('free_attack')}},
 {'wave_of_the_hand','WaveOfTheHand','挥手','skill','uncommon',1,{power('wave_of_the_hand',1)},{power('wave_of_the_hand',2)}},
 {'foresight','Wireheading','预见','power','uncommon',1,{power('foresight',3)},{power('foresight',4)}},
 {'alpha','Alpha','阿尔法','skill','rare',1,{make('beta')},nil,{exhaust=true,upgradeFlags={innate=true}}},
 {'blasphemy','Blasphemy','渎神','skill','rare',1,{e('changeStance',nil,{stance='Divinity'}),power('end_turn_death')},nil,{exhaust=true,upgradeFlags={selfRetain=true}}},
 {'conjure_blade','ConjureBlade','化剑为犁','skill','rare',-1,{e('watcherFinalConjureBlade',0)},{e('watcherFinalConjureBlade',1)},{costMode='all_energy',exhaust=true,experimental=true}},
 {'deus_ex_machina','DeusExMachina','机械降神','skill','rare',-2,{},nil,{exhaust=true,onDrawFinal={op='watcherFinalDeusExMachina',value=2},upgradeFlags={onDrawFinal={op='watcherFinalDeusExMachina',value=3}}}},
 {'deva_form','DevaForm','天人形态','power','rare',3,{power('deva_form')},nil,{ethereal=true,upgradeFlags={ethereal=false}}},
 {'judgment','Judgement','审判','skill','rare',1,{e('watcherFinalJudgment',30)},{e('watcherFinalJudgment',40)}},
 {'lesson_learned','LessonLearned','修习','attack','rare',2,{e('watcherFinalLessonLearned',10)},{e('watcherFinalLessonLearned',13)},{exhaust=true}},
 {'master_reality','MasterReality','创造现实','power','rare',1,{power('master_reality')},nil,{upgradeFlags={cost=0}}},
 {'omniscience','Omniscience','全知','skill','rare',4,{e('watcherFinalOmniscience',2)},nil,{exhaust=true,upgradeFlags={cost=3}}},
 {'ragnarok','Ragnarok','诸神黄昏','attack','rare',3,{e('watcherFinalRagnarok',5,{times=5})},{e('watcherFinalRagnarok',6,{times=6})}},
 {'spirit_shield','SpiritShield','精神护盾','skill','rare',2,{e('watcherFinalSpiritShield',3)},{e('watcherFinalSpiritShield',4)}},
 {'wish','Wish','许愿','skill','rare',3,{e('watcherFinalWish',0)},{e('watcherFinalWish',1)},{exhaust=true,sourceTags={HEALING=true}}},
 {'establishment','Establishment','确立基础','power','rare',1,{power('establishment')},nil,{upgradeFlags={innate=true}}},
 {'vault','Vault','腾跃','skill','rare',3,{e('watcherFinalSkipEnemiesTurn',1),e('watcherFinalEndTurnEarly',1)},nil,{exhaust=true,upgradeFlags={cost=2}}},
}
local text={
 foreign_influence={'从3张随机攻击中选择1张加入手牌。消耗。','从3张随机攻击中选择1张加入手牌，本回合费用为0。消耗。'},
 conclude={'对所有敌人造成12点伤害。结束你的回合。','对所有敌人造成16点伤害。结束你的回合。'},
 meditate={'从弃牌堆取回1张牌并保留。进入平静。结束你的回合。','从弃牌堆取回2张牌并保留。进入平静。结束你的回合。'},
 swivel={'获得8点格挡。你的下一张攻击免费。','获得11点格挡。你的下一张攻击免费。'},
 wave_of_the_hand={'本回合每当你获得格挡，对所有敌人施加1层虚弱。','本回合每当你获得格挡，对所有敌人施加2层虚弱。'},
 foresight={'每回合开始时占卜3。','每回合开始时占卜4。'},
 alpha={'将1张贝塔随机放入抽牌堆。消耗。','先天。将1张贝塔随机放入抽牌堆。消耗。'},
 blasphemy={'进入神格。下回合开始时失去99999生命。消耗。','保留。进入神格。下回合开始时失去99999生命。消耗。'},
 conjure_blade={'消耗所有能量。将1张可攻击X次的终结随机放入抽牌堆。消耗。','消耗所有能量。将1张可攻击X+1次的终结随机放入抽牌堆。消耗。'},
 deus_ex_machina={'不能打出。抽到时消耗本牌，将2张奇迹加入手牌。','不能打出。抽到时消耗本牌，将3张奇迹加入手牌。'},
 deva_form={'虚无。之后每回合恢复能量时获得递增能量，首次1点，逐回合加1。','之后每回合恢复能量时获得递增能量，首次1点，逐回合加1。'},
 judgment={'若目标生命不高于30，将其生命置为0。','若目标生命不高于40，将其生命置为0。'},
 lesson_learned={'造成10点伤害。若本次击杀非仆从，随机升级永久牌组中的1张牌。消耗。','造成13点伤害。若本次击杀非仆从，随机升级永久牌组中的1张牌。消耗。'},
 master_reality={'本场战斗中新生成的非状态、非诅咒牌获得升级。','本场战斗中新生成的非状态、非诅咒牌获得升级。'},
 omniscience={'从抽牌堆选1张牌，免费打出2次，然后消耗原牌。消耗。','从抽牌堆选1张牌，免费打出2次，然后消耗原牌。消耗。'},
 ragnarok={'对随机敌人造成5点伤害，共5次。','对随机敌人造成6点伤害，共6次。'},
 spirit_shield={'每有1张其他手牌，获得3点基础格挡。','每有1张其他手牌，获得4点基础格挡。'},
 wish={'选择：获得3力量、25金币或6多层护甲。消耗。','选择：获得4力量、30金币或8多层护甲。消耗。'},
 establishment={'回合结束时，保留的手牌在本场战斗中的费用降低1。','先天。回合结束时，保留的手牌在本场战斗中的费用降低1。'},
 vault={'跳过敌方回合，结束你的回合并开始额外的玩家回合。消耗。','跳过敌方回合，结束你的回合并开始额外的玩家回合。消耗。'},
}
local powers={
 free_attack={'旋转','FreeAttackPower','buff',5,'接下来的攻击免费，每张非purge攻击消耗1层，不在回合末自动消失。'},
 wave_of_the_hand={'挥手','WaveOfTheHandPower','buff',5,'本轮每次格挡正数回调后，对所有敌人施加等同层数的虚弱；轮末移除。'},
 foresight={'预见','WireheadingPower','buff',5,'回合开始时占卜等同层数，抽牌堆空则先洗牌。'},
 end_turn_death={'渎神','EndTurnDeath','buff',5,'下个回合开始时失去99999生命；此为增益而非可用纯净移除的减益。'},
 deva_form={'天人形态','DevaForm','buff',5,'恢复能量时获得当前递增值，之后按层数提高递增值。'},
 master_reality={'创造现实','MasterRealityPower','buff',5,'生成非状态、非诅咒牌的源构造／效果入口调用升级。'},
 establishment={'确立基础','EstablishmentPower','buff',25,'回合末按源顺序安排保留手牌的战斗降费。'},
 omega={'欧米伽','OmegaPower','buff',5,'玩家回合末对全体敌人造成等同层数的无来源反伤类型伤害。'},
 plated_armor={'多层护甲','Plated Armor','buff',5,'回合末获得等同层数的固定格挡；被普通攻击实际伤害后减少1层。'},
}
M.allOps={gainWatcherFinalPower=true,watcherFinalForeignInfluence=true,watcherFinalEndTurnEarly=true,watcherFinalMeditate=true,watcherFinalGenerate=true,
 watcherFinalConjureBlade=true,watcherFinalJudgment=true,watcherFinalLessonLearned=true,watcherFinalOmniscience=true,watcherFinalRagnarok=true,watcherFinalSpiritShield=true,watcherFinalWish=true,watcherFinalSkipEnemiesTurn=true,watcherFinalExpungerHits=true}
local function derivative(id,source,name,kind,cost,effects,upgrade,desc,updesc)
 return {id=id,sourceId=source,name=name,watcherFinal=true,color='colorless',type=kind,rarity='special',cost=cost,effects=effects,upgrade=upgrade,text=desc,upgradeText=updesc or desc}
end
function M.withCards(data)
 assert(type(data)=='table'and data.cards and data.cards.cards and data.statuses and data.statuses.statuses,'missing Watcher final data')
 local out,ids,statuses=copy(data),{},{}
 for _,c in ipairs(out.cards.cards)do assert(not ids[c.id],'duplicate input card');ids[c.id]=true end
 for _,s in ipairs(out.statuses.statuses)do assert(not statuses[s.id],'duplicate input status');statuses[s.id]=true end
 local function add(c)assert(not ids[c.id],'Watcher final card already exists: '..c.id);ids[c.id]=true;out.cards.cards[#out.cards.cards+1]=c end
 for _,s in ipairs(specs)do
  local c={id=s[1],sourceId=s[2],sts_name=s[2]=='Wireheading'and 'Foresight'or s[2]=='Judgement'and 'Judgment'or s[2],name=s[3],type=s[4],rarity=s[5],cost=s[6],color='purple',watcherFinal=true,
   effects=copy(s[7]),upgrade={effects=copy(s[8]or s[7])},text=text[s[1]][1],upgradeText=text[s[1]][2]}
  for k,v in pairs(s[9]or {})do if k=='upgradeFlags'then for uk,uv in pairs(v)do c.upgrade[uk]=copy(uv)end else c[k]=copy(v)end end
  add(c)
 end
 local beta=derivative('beta','Beta','贝塔','skill',2,{make('omega')},{cost=1},'将1张欧米伽随机放入抽牌堆。消耗。');beta.exhaust=true;add(beta)
 add(derivative('omega','Omega','欧米伽','power',3,{power('omega',50)},{effects={power('omega',60)}},'回合结束时对所有敌人造成50点伤害。','回合结束时对所有敌人造成60点伤害。'))
 add(derivative('expunger','Expunger','终结','attack',1,{e('watcherFinalExpungerHits',9)},{effects={e('watcherFinalExpungerHits',15)}},'造成9点伤害，次数由生成时的X决定。','造成15点伤害，次数由生成时的X决定。'))
 local opts={
  derivative('become_almighty','BecomeAlmighty','成为神明','power',-2,{e('gainStatus',3,{status='strength'})},{effects={e('gainStatus',4,{status='strength'})}},'获得3力量。','获得4力量。'),
  derivative('fame_and_fortune','FameAndFortune','名利双收','skill',-2,{e('gainGold',25)},{effects={e('gainGold',30)}},'获得25金币。','获得30金币。'),
  derivative('live_forever','LiveForever','长生不老','power',-2,{power('plated_armor',6)},{effects={power('plated_armor',8)}},'获得6多层护甲。','获得8多层护甲。'),
 }
 for _,c in ipairs(opts)do c.optionOnly=true;add(c)end
 if not ids.miracle then
  local c=derivative('miracle','Miracle','奇迹','skill',0,{e('energy',1)},{effects={e('energy',2)}},'保留。获得1能量。消耗。','保留。获得2能量。消耗。');c.selfRetain=true;c.exhaust=true;add(c)
 end
 for _,id in ipairs({'free_attack','wave_of_the_hand','foresight','end_turn_death','deva_form','master_reality','establishment','omega','plated_armor'})do
  local s=powers[id];if not statuses[id]then
  out.statuses.statuses[#out.statuses.statuses+1]={id=id,sourceId=s[2],name=s[1],kind=s[3],priority=s[4],stack=(id=='end_turn_death'or id=='master_reality')and 'none'or 'intensity',decay='none',description=s[5]}
 end end
 return out
end

M.ops={gainWatcherFinalPower=true}
M.availablePowers={free_attack=true}
function M.supported(card)
 if card.id=='deus_ex_machina' then return false end
 for _,a in ipairs(card.effects or {})do
  if M.allOps[a.op] and not M.ops[a.op]then return false end
  if a.op=='gainWatcherFinalPower' and not M.availablePowers[a.status]then return false end
 end
 return true
end
function M.freeAttack(state,card)
 return card.type=='attack' and (state.player.statuses.free_attack or 0)>0
end
function M.used(state,card,purge)
 if not purge and not card.dontTriggerOnUseCard and M.freeAttack(state,card)then
  local n=state.player.statuses.free_attack-1
  if n==0 then
   require('abyss_power_schedule').remove(state,state.player,'free_attack')
   state.player.statuses.free_attack=nil
  else state.player.statuses.free_attack=n end
 end
end
function M.execute(_,state,effect)
 assert(effect.op=='gainWatcherFinalPower' and M.availablePowers[effect.status],'unsupported Watcher final effect')
 require('abyss_actor').applyPower(state,state.player,effect.status,effect.value,state.player)
 return true
end
return M
