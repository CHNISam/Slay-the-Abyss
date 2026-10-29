package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Skill = require('abyss_skill_feedback')
local count = 0
local function expect(actual, expected) assert(actual == expected, tostring(actual)..' ~= '..tostring(expected)); count=count+1 end
local function family(enemyId,intentId,effects)
    return Skill.resolve('intent',{}, {enemyId=enemyId,intentId=intentId,effects=effects or {}})
end
expect(family('sentry','sentry_1'),'projectile')
expect(family('red_slaver','red_slaver_2'),'bind')
expect(family('chosen','zap'),'projectile')
expect(family('chosen','debilitate'),'heavy')
expect(family('collector','fireball'),'projectile')
expect(family('automaton','hyper_beam'),'projectile')
expect(family('bronze_orb','beam'),'projectile')
expect(family('snake_plant','spores'),'poison')
expect(family('unknown','fireball',{{op='damage'}}),'melee')
expect(family('collector','buff',{{op='block'}}),'defend')
expect(family('mystic','heal',{{op='enemyHealAll'}}),'buff')
expect(family('cultist','cultist_2',{{op='gainStatus',status='ritual'}}),'buff')
expect(family('lagavulin','lagavulin_1'),'none')
expect(Skill.resolve('status_damage',{status='poison'},{}),'poison')
expect(Skill.resolve('status_damage',{status='thorns'},{}),'dot')
expect(Skill.resolve('status',{status='entangled'},{}),'bind')
expect(Skill.resolve('block',{}, {family='projectile'}),'defend')
expect(Skill.resolve('damage',{effectType='projectile'},{}),'projectile')
expect(Skill.resolve('damage',{}, {family='projectile',weight='heavy'}),'projectile')
expect(Skill.resolve('damage',{}, {family='melee',weight='heavy'}),'heavy')
expect(Skill.resolve('status',{status='weak'}, {family='projectile'}),'bind')
expect(Skill.resolve('heal',{}, {family='melee'}),'buff')
expect(Skill.resolve('damage',{}, {family='bind'}),'melee')
local Data=require('abyss_data')
local checked=0
local primary=require('abyss_act2_enemies').enemies
local definitions={}
for _,enemy in ipairs(Data.enemies.enemies) do definitions[enemy.id]=enemy end
for _,enemy in ipairs(primary) do definitions[enemy.id]=enemy end
local ids={'cultist','jaw_worm','red_louse','green_louse','acid_slime_s','acid_slime_m','acid_slime_l',
    'spike_slime_s','spike_slime_m','spike_slime_l','looter','blue_slaver','red_slaver','fungi_beast',
    'mad_gremlin','sneaky_gremlin','fat_gremlin','wizard_gremlin','shield_gremlin','gremlin_nob','lagavulin','sentry','guardian'}
for _,enemy in ipairs(primary) do ids[#ids+1]=enemy.id end
for _,id in ipairs(ids) do
    local definition=assert(definitions[id],id)
    for _,intent in ipairs(definition.intents) do
        local result=Skill.resolve('intent',{}, {enemyId=id,intentId=intent.id,intentKind=intent.kind,effects=intent.effects})
        if intent.kind=='sleep' or intent.kind=='stunned' or intent.kind=='escape' then expect(result,'none')
        elseif intent.kind~='split' then assert(result~='none',id..'/'..intent.id..' missing presentation') end
        checked=checked+1
    end
end

local signatures = {}
for _,name in ipairs({'melee','heavy','projectile','poison','bind','buff','defend','dot'}) do
    local sx,sy,x,y,alpha,ink=Skill.sample(name,0.35,24)
    local signature=table.concat({sx,sy,x,y,alpha},':')
    assert(not signatures[signature], 'families must not share a single flash shape')
    signatures[signature]=true
    assert(sx>0 and sy>0 and alpha>=0 and alpha<=1 and type(ink)=='string')
    for _,p in ipairs({-1,0,0.1,0.5,0.9,1,2}) do
        local a,b,c,d,e=Skill.sample(name,p,24)
        assert(a==a and b==b and c==c and d==d and e==e)
        assert(e>=0 and e<=1)
    end
    local _,_,_,_,endAlpha=Skill.sample(name,1,24)
    expect(endAlpha,0)
end
local sx,sy,x,y,alpha=Skill.sample('projectile',0,24)
expect(x,0) -- Contact VFX never replays travel after damage has happened.
local x0,y0,a0=Skill.travel('projectile',0,100,20,0,0)
local x1,y1,a1=Skill.travel('projectile',1,100,20,0,0)
expect(x0,100); expect(y0,20); expect(x1,0); expect(y1,0); expect(a1,0)
local bx,by=Skill.travel('bind',0.5,100,20,0,0)
assert(bx>0 and bx<100 and by>0 and by<20)
local d={status='poison',amount=4}
local context={enemyId='sentry',intentId='sentry_1',effects={{op='damage'}},family='projectile'}
local random=math.random; math.random=function() error('presentation must not consume RNG') end
for _=1,100 do Skill.resolve('status_damage',d,context); Skill.sample('poison',0.3,24); Skill.travel('projectile',0.3,0,0,1,1) end
math.random=random
expect(d.amount,4); expect(d.status,'poison'); expect(context.family,'projectile'); expect(context.effects[1].op,'damage')
expect(Skill.cue('heavy','damage',{amount=0,blocked=3}),'block_hit')
expect(Skill.cue('projectile','damage',{amount=5}),'hit')
expect(Skill.cue('heavy','damage',{amount=15}),'hit_heavy')
expect(Skill.cue('poison','status_damage',{amount=0}),nil)
expect(Skill.cue('bind','status',{}),'status')
expect(Skill.cue('defend','block',{}),'block_gain')
print('LUA_SKILL_FEEDBACK_PASS '..count..' production intents '..checked)
