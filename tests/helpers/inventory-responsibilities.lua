package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,I,Run=require('abyss_combat'),require('abyss_card_actions'),require('abyss_inventory'),require('abyss_run')
local data=require('abyss_data')
local base=C.new(require('abyss_watcher_flow_cards').withCards(require('abyss_watcher_cards').withFoundationCards(data)),{deck={},enemies={'jaw_worm','jaw_worm'},seed=37,shuffleSeed='41',cardRandomSeed='43',orbSlots=3})
local group=ABYSS_INVENTORY_GROUP or 'all'
local cases=0
local function eq(a,b,label)assert(a==b,'[INVENTORY_RESPONSIBILITY] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function observe(label,value)
    if ABYSS_INVENTORY_GRAPH_WRITE then ABYSS_INVENTORY_GRAPH_WRITE(value,label,false) end
end
local function state()
    local s=C.copy(base);s.events={};s.energy=10;s.player.hp=40
    for _,enemy in ipairs(s.enemies)do enemy.hp=100;enemy.maxHp=100;enemy.block=0 end
    return s
end
local function test(name,fn)
    fn();cases=cases+1
end
local function apply(s,effects,target,run,defer)
    local loads={};local oldRequire=require
    require=function(name)loads[#loads+1]=name;return oldRequire(name)end
    local result=table.pack(pcall(I.apply,s,effects,target,run,defer))
    require=oldRequire
    observe('apply',{state=s,effects=effects,target=target,run=run,result=result,loads=loads})
    return table.unpack(result,1,result.n)
end
if group=='opening'or group=='all'then
test('opening positions retain effects aliases and exact owner order',function()
    local ids={'ring_of_the_snake','cracked_core','pure_water','lantern','vajra','anchor','mutagenic_strength','blood_vial','akabeko','data_disk','thread_and_needle','girya','du_vu_doll','pantograph','bag_of_marbles','pen_nib','red_skull','red_mask','fossilized_helix','mark_of_pain','cultist_mask'}
    local defs={};for _,id in ipairs(ids)do defs[#defs+1]={id=id,trigger='combat_start',effects={{op='energy',value=1}}}end
    local counters={a={b=true}};local context={tier='boss'}
    local result=table.pack(I.opening(defs,ids,counters,context));local opening=result[1]
    eq(opening.beforeDraw.relics,ids,'owned alias');eq(opening.beforeDraw.relicCounters,counters,'counter alias');eq(opening.beforeDraw.relicContext,context)
    eq(opening.beforeDraw[1],defs[4].effects,'turn TOP precedes battle TOP')
    eq(opening.beforeDraw[2][1].id,'pantograph','last battle TOP first')
    eq(opening.afterDraw[1],defs[1].effects,'bottom held order');eq(opening.preBattle[1],defs[2].effects);eq(opening.preDraw[1],defs[3].effects)
    observe('opening',{definitions=defs,owned=ids,counters=counters,context=context,result=result})
end)
test('opening unknowns and boss conditional preserve refusal and load calls',function()
    for _,sample in ipairs({{{'missing'},{}},{{'unsupported'},{{id='unsupported',trigger='combat_start'}}},{{'pantograph'},{{id='pantograph',trigger='passive'}}}})do
        for _,context in ipairs({false,{tier='normal'},{tier='boss'}})do
            local loads={};local old=require;require=function(name)loads[#loads+1]=name;return old(name)end
            local result=table.pack(pcall(I.opening,sample[2],sample[1],nil,context));require=old
            observe('opening-refusal',{sample=sample,context=context,result=result,loads=loads})
        end
    end
end)
test('energy definitions preserve duplicate first owner and arithmetic refusal',function()
    local defs={{id='sozu',trigger='turn_start',effects={{op='energy',value=1}}},{id='sozu',trigger='turn_start',effects={{op='energy',value=10}}},
      {id='slavers_collar',trigger='turn_start',encounterTiers={'elite','boss'},effects={{op='energy',value=1}}},{id='other',trigger='turn_start',effects={}}}
    eq(I.energyBonus(defs,{'sozu'},'normal'),1,'first definition wins')
    for _,owned in ipairs({{}, {'sozu','slavers_collar'}, {'missing'}, {'other'}})do
      for _,tier in ipairs({'normal','elite','boss'})do observe('energy',{owned=owned,tier=tier,result=table.pack(pcall(I.energyBonus,defs,owned,tier))})end
    end
    for _,value in ipairs({-1,0.5,'1',2147483648,math.huge,0/0})do
      defs[1].effects[1].value=value;local result=table.pack(I.energyBonus(defs,{'sozu'},'normal'));eq(result[1],nil);eq(result[2],'invalid_relic_energy');observe('energy-invalid',{definitions=defs,result=result})
    end
end)
end
if group=='validation'or group=='all'then
test('whole-list validation precedes every write and preserves rejection priority',function()
    local vectors={
      {{op='unknown',value=1}},{{op='energy',value=1.5}},{{op='upgradeHand',all=false}},
      {{op='gainTemporaryStrength',status='dexterity',value=1}},{{op='gainTemporaryDexterity',status='dexterity',value=0}},
      {{op='channelOrb',orb='frost',value=1}},{{op='makeMiracle',value=2}},{{op='gainStatus',status='unknown',value=1}},
      {{op='damage',value=-1}},{{op='classPotion',value=1}},
    }
    for _,tail in ipairs(vectors)do
      local s=state();local effects={{op='energy',value=2},tail[1]};local called,ok=apply(s,effects,nil,nil,true)
      eq(called,true);eq(ok,false);eq(s.energy,10,'no writes before validation')
    end
    for _,target in ipairs({0,-1,0.5,'1',false,{},math.huge,0/0})do
      local s=state();local called,ok,reason=apply(s,{{op='damage',value=1}},target,nil,true)
      eq(called,true);eq(ok,false);eq(reason,'invalid_target')
    end
end)
test('starting card UID/master reality and orb eligibility are rejected before writes',function()
    for _,uid in ipairs({0,2147483647,1.5,false})do
      local s=state();s.nextUid=uid;local called,ok,reason=apply(s,{{op='makeMiracle',value=1}},nil,nil,true)
      eq(called,true);eq(ok,false);eq(reason,'unsupported_starting_card')
    end
    local s=state();s.player.statuses.master_reality=1;local _,ok=apply(s,{{op='makeMiracle',value=1}},nil,nil,true);eq(ok,false)
    s=state();s.orbs=nil;local _,orb,reason=apply(s,{{op='channelOrb',orb='lightning',value=1}},nil,nil,true);eq(orb,false);eq(reason,'unsupported_starting_orb')
end)
end
if group=='effects'or group=='all'then
test('all ordinary effects preserve queue state identities and deferred drain',function()
    local vectors={
      {op='silentShivs',value=2},{op='silentGhost',value=1},{op='makeMiracle',value=1},{op='channelOrb',orb='lightning',value=1},{op='classPotion',kind='focus',value=2},
      {op='damage',value=7},{op='damageAll',value=3},{op='block',value=4},{op='healPercent',value=20},
      {op='increaseMaxHp',value=3},{op='discover',value=1},{op='draw',value=2},{op='randomizeHandCost',value=0},
      {op='escape',value=0},{op='playTopCards',value=3},{op='upgradeHand',all=true},
      {op='exhaustMany',value=1},{op='discardRedraw',value=1},{op='discardToHand',value=1},
      {op='gainTemporaryStrength',status='strength',value=2},{op='gainTemporaryDexterity',status='dexterity',value=2},
      {op='energy',value=2},{op='gainStatus',status='strength',value=2},{op='applyStatus',status='weak',value=1},
    }
    for _,effect in ipairs(vectors)do
      local s=state();local card=A.fresh(C,s,'strike');s.hand={card};s.anchors={card,s.player,s.enemies[1]}
      local rng=s.cardRandomRng.counter;local called,ok=apply(s,{effect},1,{relics={}},true);eq(called,true);eq(ok,true,effect.op)
      if effect.op=='draw'then eq(#s.hand,1,'draw remains queued');eq(s.cardActions[1].effect,effect,'queued effect alias')end
      if effect.op=='playTopCards'then eq(#s.cardActions,3);eq(s.cardRandomRng.counter,rng+3,'all targets chosen before drain')end
      if effect.op=='increaseMaxHp'then eq(s.player.maxHp,83);eq(s.player.hp,43,'Fruit Juice immediate healing')end
      if effect.op=='healPercent'then eq(s.player.hp,40,'Blood Potion heal remains queued')end
    end
end)
test('V4 max-health uses one owner ledger and retains zero-heal notification',function()
    for _,role in ipairs({'HT','AR'})do
      local s=state();s.originalV4={role=role,healUsed=0};s.originalV4Rules={common={battle_actual_heal_cap=10}}
      local old=require('abyss_relic_combat_hooks').hpChanged;local observed={}
      require('abyss_relic_combat_hooks').hpChanged=function(st,actor,before)observed[#observed+1]={state=st,actor=actor,before=before};return old(st,actor,before)end
      local called,ok=apply(s,{{op='increaseMaxHp',value=3}},nil,{relics={}},true)
      require('abyss_relic_combat_hooks').hpChanged=old
      eq(called,true);eq(ok,true);eq(s.player.maxHp,83);eq(s.player.hp,role=='AR'and 40 or 43)
      eq(s.originalV4.healUsed,role=='AR'and 0 or 3);eq(#observed,1,'exactly one HP callback');eq(observed[1].actor,s.player)
      observe('v4-health',{state=s,callbacks=observed})
    end
end)
test('artifact resolves otherwise-overflowing power and read timing remains dynamic',function()
    local s=state();s.enemies[1].statuses.weak=2147483647;s.enemies[1].statuses.artifact=1
    local called,ok=apply(s,{{op='applyStatus',status='weak',value=1}},1,nil,true)
    eq(called,true);eq(ok,true);eq(s.enemies[1].statuses.weak,2147483647);eq(s.enemies[1].statuses.artifact,0)
    local reads={};local values={op='energy',value=2};local effect=setmetatable({},{__index=function(_,key)reads[#reads+1]=key;return values[key]end})
    called,ok=apply(s,{effect},nil,nil,true);eq(called,true);eq(ok,true);eq(s.energy,12)
    observe('dynamic-effect',{state=s,reads=reads,effect=effect})
end)
test('potion generation and class potion use real RNG and pending actions',function()
    local run=Run.new(data,42);local s=state()
    local called,ok=apply(s,{{op='generatePotions',value=1}},nil,run,true);eq(called,true);eq(ok,true)
    for _,potion in ipairs(data.potions.potions)do
      for _,effect in ipairs(potion.effects or {})do if effect.op=='classPotion'then
        s=state();called,ok=apply(s,{effect},nil,run,true);eq(called,true);eq(ok,true);eq(s.cardActions[1].effect,effect)
      end end
    end
end)
test('miracle full-hand fallback and final drain remain at batch boundary',function()
    local s=state();for _=1,s.rules.player.maxHand do s.hand[#s.hand+1]=A.fresh(C,s,'strike')end
    local uid=s.nextUid;local called,ok=apply(s,{{op='makeMiracle',value=1},{op='energy',value=2}},nil,nil,false)
    eq(called,true);eq(ok,true);eq(s.discard[#s.discard].uid,uid);eq(s.energy,12)
    s=state();local card=A.fresh(C,s,'strike');s.draw={card};called,ok=apply(s,{{op='draw',value=1}},nil,nil,false)
    eq(called,true);eq(ok,true);eq(s.hand[1],card,'drain moves the original card')
end)
end
if group=='failure'or group=='all'then
test('late overflow preserves earlier candidate writes but never drains',function()
    for _,op in ipairs({'energy','block','gainStatus'})do
      local s=state();s.energy=2147483647;s.player.block=2147483647;s.player.statuses.strength=2147483647
      local called,ok,reason=apply(s,{{op='escape',value=0},{op=op,status='strength',value=1}},nil,nil,false)
      eq(called,true);eq(ok,false);eq(reason,'effect_overflow');eq(s.smoked,true,'partial candidate write remains')
    end
end)
test('health refusal and error identity keep prior writes and original payload',function()
    local health=require('abyss_potion_health');local old=health.apply;local failure={fault='health',nested={value=1}}
    for _,op in ipairs({'healPercent','increaseMaxHp'})do for _,throws in ipairs({false,true})do
      local s=state();health.apply=function()if throws then error(failure,0)end;return false,failure end
      local called,ok,reason=apply(s,{{op='escape',value=0},{op=op,value=1}},nil,nil,false);health.apply=old
      eq(s.smoked,true);if throws then eq(called,false);eq(ok,failure,'thrown object identity')else eq(called,true);eq(ok,false);eq(reason,failure,'refusal object identity')end
    end end
end)
test('earlier action may rewrite later validated dispatch to an ignored unknown',function()
    local s=state();local later={op='energy',value=2};local old=C.damage
    C.damage=function(...)later.op='rewritten';return old(...)end
    local called,ok=apply(s,{{op='damage',value=1},later},1,nil,true);C.damage=old
    eq(called,true);eq(ok,true);eq(s.energy,10,'post-validation unknown remains no-op')
end)
test('Run rollback restores complete graph aliases after finalization failure',function()
    local run=Run.new(data,42);run.potions={'fire_potion'};assert(Run.startCombat(run,'cultist_solo'))
    run.combat.enemies[1].hp=1;local anchor=run.combat;local before=Run.finishCombat
    Run.finishCombat=function(candidate)before(candidate);return false end
    local result=table.pack(pcall(Run.usePotion,run,1,1));Run.finishCombat=before
    eq(result[1],true);eq(result[2],false);eq(result[3],'potion_effect_failed');eq(run.combat,anchor);eq(run.potions[1],'fire_potion')
    observe('rollback',{run=run,anchor=anchor,result=result})
end)
end
local expected={opening=3,validation=2,effects=5,failure=4,all=14}
eq(cases,expected[group],'registered scenario count')
observe('complete',{cases=cases,group=group})
