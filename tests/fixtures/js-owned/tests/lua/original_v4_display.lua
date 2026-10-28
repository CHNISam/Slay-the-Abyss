package.path='src/lua/?.lua;'..package.path
local D=require('abyss_original_v4_display')
local cases=0
local function test(name,fn)fn();cases=cases+1;print('ok '..cases..' '..name)end
local function has(text,fragment)assert(text:find(fragment,1,true),'missing '..fragment..' in '..text)end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function copy(v)if type(v)~='table' then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function same(a,b)
 if type(a)~='table' or type(b)~='table' then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k,v in pairs(b)do if not same(v,a[k])then return false end end
 return true
end
local function card(category,effects,upgraded,requirements)
 return {category=category,requirements=requirements or {},base={cost=1,effects=effects,exhaust=false},
  upgrade={cost=1,effects=upgraded or copy(effects),exhaust=false}}
end

test('HT2-003 freezes HP cost and two-stage window, upgrading only block',function()
 local c=card('skill',{{op='pay_hp',n=3},{op='infuse',n=2},{op='block',n=3}},
  {{op='pay_hp',n=3},{op='infuse',n=2},{op='block',n=6}})
 local before=copy(c)
 local text=D.describe(c)
 has(text,'支付3点生命');has(text,'最多2个结束阶段');has(text,'含本回合');has(text,'前2张重击')
 has(text,'获得3点格挡');has(D.describe(c,true),'获得6点格挡');eq(D.target(c),'self')
 assert(same(c,before),'display mutated source')
end)
test('HT2-004 uses one low-HP snapshot and battle-only exhaust',function()
 local c=card('burst',{{op='damage',n=10,hits=1,target='all'},
  {op='when',condition='low',effects={{op='heal',n=6}}},
  {op='when',condition='not_low',effects={{op='heal',n=3}}}})
 c.base.exhaust=true
 local text=D.describe(c)
 has(text,'技能·爆发');has(text,'所有存活敌人造成10点伤害')
 has(text,'生命≤最大生命50%');has(text,'生命>最大生命50%');has(text,'每战12点实际治疗额度')
 has(text,'付血后、根消费前的同一快照')
 has(text,'下场恢复，不从永久牌组删除');eq(D.target(c),'all')
end)
test('AR2-004 spends after absorbing and keeps zero damage coefficient',function()
 local c=card('burst',{{op='absorb',target='all'},{op='spend',n='all',resource='bond'},
  {op='damage_spent',n=10,coefficient=0,target='all'},
  {op='heal_spent',n=2,coefficient=0.5}})
 local text=D.describe(c)
 has(text,'未成熟收2契，成熟收6契');has(text,'消费当前全部生命之契')
 has(text,'所有存活敌人造成10点伤害');has(text,'⌊本牌最近实际消费的生命之契÷2⌋')
 assert(not text:find('0×',1,true),'zero coefficient invented scaling')
 eq(D.target(c),'all')
end)
test('FR2-003 refreshes unique guests without adding charges',function()
 local c=card('skill',{{op='mode',mode='ousia'},{op='summon',n=2,member='usher'},
  {op='summon',n=2,member='chevalmarin'},{op='summon',n=2,member='crabaletta'}})
 local text=D.describe(c)
 has(text,'乌瑟勋爵');has(text,'海薇玛夫人');has(text,'谢贝蕾妲小姐')
 has(text,'最多3次，同名唯一');has(text,'不立即行动');has(text,'当前生命最高敌人')
 has(text,'本批首命中＋1');eq(D.target(c),'self')
end)
test('FR2-004 requires fan and counts its own batch',function()
 local c=card('burst',{{op='spend',n='all',resource='fan'},{op='revelry',n=3},
  {op='damage',n=8,hits=1,target='all'}},nil,{'fan4'})
 local text=D.describe(c)
 has(text,'前提：气氛≥4');has(text,'消费当前全部气氛');has(text,'本牌后续直接伤害也消耗一批')
 has(text,'群体不按目标重复加成');eq(D.target(c),'all')
end)
test('RD2-003 damage skill remains a command and never doubles the tax',function()
 local c=card('command',{{op='damage',n=3,hits=1,target='one'},{op='eye',n=3}},
  {{op='damage',n=6,hits=1,target='one'},{op='eye',n=3}})
 local text=D.describe(c)
 has(text,'技能·军令');has(text,'造成3点伤害');has(text,'不追击新建自身的命中，不递归')
 has(D.describe(c,true),'造成6点伤害');eq(D.target(c),'enemy')
 local defense=card('command',{{op='block',n=0}})
 has(D.describe(defense),'本项格挡为0，不产生获得格挡收益')
end)
test('RD2-004 actual-spend formula and next-turn refund are explicit',function()
 local c=card('burst',{{op='spend',n='all',resource='resolve'},
  {op='damage_spent',n=10,coefficient=2,target='one'},{op='musou',n=3}},nil,{'resolve3'})
 local text=D.describe(c)
 has(text,'前提：愿力≥3');has(text,'10＋2×本牌最近实际消费的愿力')
 has(text,'下回合增加1能量');has(text,'每回合最多返能1次');eq(D.target(c),'enemy')
end)
test('raw wrapper, explicit upgrade and text tampering never change DSL',function()
 local c=card('normal',{{op='damage',n=6,target='one'}},{{op='damage',n=9,target='one'}})
 c.base_text='造成999点伤害';c.upgrade_text='伪造说明';c.name='技能名字不能决定规则'
 local adapted={originalV4=c,upgraded=true}
 has(D.describe(adapted),'攻击·普攻');has(D.describe(adapted),'造成9点伤害')
 has(D.describe(adapted,false),'造成6点伤害');eq(D.target(adapted),'enemy')
end)
test('all 34 frozen operations have meaningful Chinese text',function()
 local ops={
  {op='absorb',target='all'},{op='block',n=4},{op='block_spent',n=4,coefficient=1},
  {op='bloom',n=2,target='one'},{op='bonus',n=4,tag='charged'},{op='cash_bloom',target='all'},
  {op='cleanse'},{op='counter',n=6},{op='damage',n=4,hits=2,target='one'},
  {op='damage_spent',n=10,coefficient=2,target='all'},{op='directive',target='one'},
  {op='draw',n=2},{op='end_infuse'},{op='eye',n=2},{op='eye_pulse'},
  {op='heal',n=3},{op='heal_spent',n=2,coefficient=0.5},{op='infuse',n=2},
  {op='mature',target='all'},{op='mode',mode='pneuma'},{op='musou',n=3},
  {op='next_block',n=5},{op='next_draw',n=1},{op='next_energy',n=1},{op='pay_hp',n=2},
  {op='resolve',n=2},{op='revelry',n=3},{op='singer',n=2},{op='soften',n=3},
  {op='spend',n=2,resource='fan'},{op='summon',n=2,member='usher'},
  {op='toggle'},{op='trigger',member='all'},{op='when',condition='low',effects={{op='block',n=3}}},
 }
 eq(#ops,34)
 for _,effect in ipairs(ops)do
  local text=D.describe(card('skill',{effect}))
  assert(#text>12 and text:find('[\128-\255]'),'empty operation '..effect.op)
 end
 has(D.describe(card('skill',{{op='cleanse'}})),'虚弱与脆弱，仅此两项')
 has(D.describe(card('skill',{{op='damage',n=4,hits=2,target='one'}})),'共2段')
end)
test('all 32 frozen conditions render in requirements and when',function()
 local cs={'bloom_target','bond0','bond1','bond2','bond4','directive_target','enemy_low','eye',
  'fan0','fan2','fan3','fan4','fan6','has_bloom','has_directive','has_guest','has_mature','has_singer',
  'infused','low','mature_target','musou','not_bond4','not_fan4','not_low','not_musou',
  'ousia','pneuma','resolve0','resolve2','resolve3','resolve4'}
 eq(#cs,32)
 for _,condition in ipairs(cs)do
  local c=card('skill',{{op='when',condition=condition,effects={{op='block',n=2}}}},nil,{condition})
  has(D.describe(c),'前提：');has(D.describe(c),'若【')
 end
end)
test('target scans nested conditions and both complete versions',function()
 local c=card('skill',{{op='block',n=3}},{{op='when',condition='bond2',effects={{op='damage',n=4,target='all'}}}})
 eq(D.target(c),'all')
 c.upgrade.effects[1].condition='mature_target';eq(D.target(c),'enemy')
 eq(D.target(card('skill',{{op='eye_pulse'}})),'enemy')
 local cash=card('skill',{{op='cash_bloom'},{op='block',n=6}})
 eq(D.target(cash),'enemy');has(D.describe(cash),'兑现所选存活目标血梅香')
 eq(D.target(card('skill',{{op='block',n=3}},nil,{'enemy_low'})),'enemy')
end)
test('unknown DSL is rejected instead of silently disappearing',function()
 local invalid={
  card('unknown',{{op='block',n=3}}),card('skill',{{op='surprise'}}),
  card('skill',{{op='when',condition='invented',effects={}}}),
  card('skill',{{op='bonus',n=2,tag='invented'}}),card('skill',{{op='mode',mode='invented'}}),
  card('skill',{{op='spend',n=2,resource='invented'}}),card('skill',{{op='summon',n=2,member='invented'}}),
  card('skill',{{op='block',n=3}},nil,{'invented'}),card('skill',{{op='damage',n=3,target='invented'}}),
 }
 for _,c in ipairs(invalid)do local ok=pcall(D.describe,c);assert(not ok,'unknown DSL accepted')end
 assert(not pcall(D.target,card('skill',{{op='surprise'}})))
 assert(not pcall(D.target,card('skill',{{op='block',n=3}},nil,{'invented'})))
 local missing=card('skill',{{op='block',n=3}});missing.upgrade=nil
 assert(not pcall(D.describe,missing,true),'missing upgrade silently fell back to base')
end)
test('summary exposes all role resources, stages, charges and shared healing',function()
 local state={originalV4={role='HT',infuse=1,chargedUsed=2,healUsed=9,nextEnergy=1,nextDraw=2,nextBlock=7,
  bonus={n=4,tag='normal'},counter=3,soften=2},enemies={
   {hp=11,name='甲',v4Bloom={strength=2,ticks=1}},{hp=0,name='已死',v4Bloom={strength=3,ticks=2}}}}
 local before=copy(state)
 local text=D.summary(state)
 has(text,'蝶引 1阶段');has(text,'重击 2/2');has(text,'甲 血梅香 强度2／1次')
 assert(not text:find('已死',1,true));has(text,'本战已治疗 9/12')
 has(text,'能量＋1／抽牌＋2／格挡＋7');has(text,'准备 普攻首命中＋4');has(text,'反击 3');has(text,'削势 2')
 assert(same(state,before),'summary mutated state')
 state.originalV4={role='AR',bond=7,healUsed=12};state.enemies={{hp=10,v4Directive={mature=true}}}
 text=D.summary(state);has(text,'生命之契 7/8');has(text,'勒令已成熟');has(text,'已治疗 12/12')
 state.originalV4={role='FR',mode='pneuma',fan=8,fanGained=3,guests={usher=2,chevalmarin=1,crabaletta=3},
  singer=2,revelry={uses=2,ends=1,bonus=2}}
 text=D.summary(state);has(text,'芒性；气氛 8/12');has(text,'增长 3/4')
 has(text,'乌瑟勋爵 2次（暂停）');has(text,'歌者 2次');has(text,'欢腾 2次／1阶段；首命中＋2')
 state.originalV4={role='RD',resolve=5,resolveGained=2,eye={uses=1,ends=1},
  musou={uses=2,ends=2},musouRefunded=1}
 text=D.summary(state);has(text,'愿力 5/6');has(text,'雷眼 1次／1阶段')
 has(text,'梦想一心 2次／2阶段；本回合返能 1/1');eq(D.summary({}),'')
end)
print('LUA_ORIGINAL_V4_DISPLAY_PASS '..cases)
