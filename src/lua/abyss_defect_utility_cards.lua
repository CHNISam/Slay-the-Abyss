-- Independent card data, verified against the pinned 319009 community source.
-- Action-time values (orb count, turn history, X energy) belong to Combat's queue.
local M={}
local Actors=require('abyss_actor')
local MAX=2147483647
local function integer(value)
    return type(value)=='number' and value==math.floor(value) and value>=0 and value<=MAX
end
local function copy(x)
    if type(x)~='table' then return x end
    local out={};for k,v in pairs(x) do out[k]=copy(v) end;return out
end
local function e(op,value,extra)
    local out=extra or {};out.op=op;out.value=value;return out
end
local function channel(kind) return e('channelOrb',1,{orb=kind}) end
local function generated(id) return e('makeTempCardInDiscard',1,{card=id}) end
local cards={
    {id='barrage',sourceId='Barrage',name='弹幕连击',type='attack',rarity='common',cost=1,
        effects={e('barrageDamage',4)},upgrade={effects={e('barrageDamage',6)}},
        text='每有一个已填充的充能球，便对目标造成 4 点伤害。',upgradeText='每有一个已填充的充能球，便对目标造成 6 点伤害。'},
    {id='compile_driver',sourceId='Compile Driver',name='编译冲击',type='attack',rarity='common',cost=1,
        effects={e('damage',7),e('compileDriverDraw',1)},upgrade={effects={e('damage',10),e('compileDriverDraw',1)}},
        text='造成 7 点伤害。每有一种不同类型的充能球，抽 1 张牌。',upgradeText='造成 10 点伤害。每有一种不同类型的充能球，抽 1 张牌。'},
    {id='go_for_the_eyes',sourceId='Go for the Eyes',name='眼部攻击',type='attack',rarity='common',cost=0,
        effects={e('damage',3),e('weakIfAttacking',1)},upgrade={effects={e('damage',4),e('weakIfAttacking',2)}},
        text='造成 3 点伤害。若目标正准备攻击，施加 1 回合虚弱。',upgradeText='造成 4 点伤害。若目标正准备攻击，施加 2 回合虚弱。'},
    {id='boot_sequence',sourceId='BootSequence',name='启动流程',type='skill',rarity='uncommon',cost=0,innate=true,exhaust=true,
        effects={e('block',10)},upgrade={effects={e('block',13)}},
        text='先天。获得 10 点格挡。消耗。',upgradeText='先天。获得 13 点格挡。消耗。'},
    {id='charge_battery',sourceId='Conserve Battery',name='充电',type='skill',rarity='common',cost=1,
        effects={e('block',7),e('nextEnergy',1,{status='energized_blue'})},upgrade={effects={e('block',10),e('nextEnergy',1,{status='energized_blue'})}},
        text='获得 7 点格挡。下回合额外获得 1 点能量。',upgradeText='获得 10 点格挡。下回合额外获得 1 点能量。'},
    {id='glacier',sourceId='Glacier',name='冰川',type='skill',rarity='uncommon',cost=2,
        effects={e('block',7),channel('frost'),channel('frost')},upgrade={effects={e('block',10),channel('frost'),channel('frost')}},
        text='获得 7 点格挡。生成 2 个冰霜充能球。',upgradeText='获得 10 点格挡。生成 2 个冰霜充能球。'},
    {id='overclock',sourceId='Steam Power',name='超频',type='skill',rarity='uncommon',cost=0,
        effects={e('draw',2),generated('burn')},upgrade={effects={e('draw',3),generated('burn')}},
        text='抽 2 张牌。将 1 张灼伤放入弃牌堆。',upgradeText='抽 3 张牌。将 1 张灼伤放入弃牌堆。'},
    {id='turbo',sourceId='Turbo',name='加速',type='skill',rarity='common',cost=0,
        effects={e('energy',2),generated('void')},upgrade={effects={e('energy',3),generated('void')}},
        text='获得 2 点能量。将 1 张虚空放入弃牌堆。',upgradeText='获得 3 点能量。将 1 张虚空放入弃牌堆。'},
    {id='core_surge',sourceId='Core Surge',name='核心电涌',type='attack',rarity='rare',cost=1,exhaust=true,
        effects={e('damage',11),e('gainStatus',1,{status='artifact'})},upgrade={effects={e('damage',15),e('gainStatus',1,{status='artifact'})}},
        text='造成 11 点伤害。获得 1 层人工制品。消耗。',upgradeText='造成 15 点伤害。获得 1 层人工制品。消耗。'},
    {id='rainbow',sourceId='Rainbow',name='彩虹',type='skill',rarity='rare',cost=2,exhaust=true,
        effects={channel('lightning'),channel('frost'),channel('dark')},upgrade={exhaust=false},
        text='依次生成闪电、冰霜和黑暗充能球各 1 个。消耗。',upgradeText='依次生成闪电、冰霜和黑暗充能球各 1 个。'},
    {id='hyperbeam',sourceId='Hyperbeam',name='超能光束',type='attack',rarity='rare',cost=2,
        effects={e('damageAll',26),e('gainFocus',-3)},upgrade={effects={e('damageAll',34),e('gainFocus',-3)}},
        text='对所有敌人造成 26 点伤害。失去 3 点集中。',upgradeText='对所有敌人造成 34 点伤害。失去 3 点集中。'},
    {id='reinforced_body',sourceId='Reinforced Body',name='强化机体',type='skill',rarity='uncommon',cost=-1,costMode='all_energy',experimental=true,
        effects={e('xBlock',7)},upgrade={effects={e('xBlock',9)}},
        text='获得 7 点格挡，重复 X 次。',upgradeText='获得 9 点格挡，重复 X 次。'},
    {id='double_energy',sourceId='Double Energy',name='双倍能量',type='skill',rarity='uncommon',cost=1,exhaust=true,
        effects={e('doubleEnergy',1)},upgrade={cost=0},
        text='将当前剩余能量翻倍。消耗。',upgradeText='将当前剩余能量翻倍。消耗。'},
    {id='ftl',sourceId='FTL',name='超越光速',type='attack',rarity='uncommon',cost=0,
        effects={e('ftlDamage',5,{threshold=3})},upgrade={effects={e('ftlDamage',6,{threshold=4})}},
        text='造成 5 点伤害。若本回合此前打出的牌少于 3 张，抽 1 张牌。',upgradeText='造成 6 点伤害。若本回合此前打出的牌少于 4 张，抽 1 张牌。'},
}
local statuses={
    {id='void',sourceId='Void',name='虚空',type='status',rarity='common',cost=-2,ethereal=true,effects={},
        text='不能打出。抽到时失去 1 点能量。虚无。'},
    {id='burn',sourceId='Burn',name='灼伤',type='status',rarity='common',cost=-2,effects={},burnDamage=2,
        upgrade={burnDamage=4},text='不能打出。回合结束时受到 2 点伤害。',upgradeText='不能打出。回合结束时受到 4 点伤害。'},
}
function M.withCards(data)
    assert(type(data)=='table' and data.cards and type(data.cards.cards)=='table','missing card data')
    local result=copy(data);local present,retained={},{}
    for _,card in ipairs(result.cards.cards) do
        assert(not present[card.id],'duplicate utility source card: '..card.id)
        present[card.id]=true
        -- Production's Burn may use a different end-turn schema. This opt-in
        -- preparation replaces only its detached copy with the audited template
        -- below; every other repeated registration remains an error.
        if card.id=='burn' then
            assert(card.type=='status' and card.cost==-2 and type(card.effects)=='table'
                and next(card.effects)==nil,'incompatible utility Burn definition')
        else retained[#retained+1]=card end
    end
    result.cards.cards=retained;present.burn=nil
    for _,group in ipairs({cards,statuses}) do
        for _,card in ipairs(group) do
            assert(not present[card.id],'utility card collision: '..card.id)
            result.cards.cards[#result.cards.cards+1]=copy(card);present[card.id]=true
        end
    end
    local defs=result.statuses.statuses
    for _,status in ipairs(defs) do assert(status.id~='energized_blue','utility status collision') end
    defs[#defs+1]={id='energized_blue',name='充电',kind='buff',stack='intensity',decay='none',
        description='下次回合能量恢复时获得对应层数的额外能量，然后移除此状态。'}
    return result
end
-- Pure preparation: freeze card-modified damage/block before action resolution.
-- Reactions remain NORMAL damage; a frozen amount is not fixed orb damage.
function M.prepareEffect(state,effect,target)
    assert(type(effect)=='table','missing utility effect')
    local out=copy(effect)
    if effect.op=='barrageDamage' or effect.op=='ftlDamage' then
        assert(integer(effect.value) and target,'invalid utility attack')
        out.normalAmount=Actors.attackAmount(state,state.player,target,effect.value)
        assert(integer(out.normalAmount),'utility attack overflow')
        if effect.op=='ftlDamage' then assert(integer(effect.threshold),'invalid FTL threshold') end
    elseif effect.op=='xBlock' then
        assert(integer(effect.value),'invalid X block')
        out.blockAmount=Actors.blockAmount(state,state.player,effect.value)
        assert(integer(out.blockAmount),'utility block overflow')
    end
    return out
end
-- Pure queue plan. Arrays contain effect records in execution order. The host
-- reverses top while pushing to TOP, and appends bottom in its listed order.
-- consumeAllEnergy is an instruction to the host, never a mutation here.
function M.planEffect(state,effect,context)
    context=context or {}
    local op=effect.op
    local plan={top={},bottom={},consumeAllEnergy=false}
    if op=='barrageDamage' then
        assert(state.orbs and integer(effect.normalAmount),'unprepared Barrage')
        assert(integer(effect.value),'invalid Barrage base')
        for _,ball in ipairs(state.orbs.balls) do
            assert(ball.kind=='lightning' or ball.kind=='frost' or ball.kind=='dark' or ball.kind=='plasma','invalid filled orb')
            plan.top[#plan.top+1]=e('damage',effect.value,{normalAmount=effect.normalAmount})
        end
    elseif op=='compileDriverDraw' then
        assert(state.orbs and effect.value==1,'invalid Compile Driver')
        local seen,count={},0
        for _,ball in ipairs(state.orbs.balls) do
            assert(ball.kind=='lightning' or ball.kind=='frost' or ball.kind=='dark' or ball.kind=='plasma','invalid filled orb')
            if not seen[ball.kind] then seen[ball.kind]=true;count=count+1 end
        end
        if count>0 then plan.top[1]=e('draw',count) end
    elseif op=='weakIfAttacking' then
        assert(integer(effect.value),'invalid eye attack debuff')
        local target=assert(context.target,'eye attack target missing')
        local intent=target.intents and target.intents[target.intentIndex]
        assert(intent and type(intent.effects)=='table','missing target intent')
        local attacking=false
        for _,entry in ipairs(intent.effects) do
            if entry.op=='damage' or entry.op=='damageAll' then
                assert(integer(entry.value),'invalid intent base damage')
                attacking=true
            end
        end
        if attacking then plan.top[1]=e('applyStatus',effect.value,{status='weak'}) end
    elseif op=='doubleEnergy' then
        assert(effect.value==1 and integer(state.energy),'invalid double energy')
        -- Global source 999 energy cap is owned by the host energy operation.
        -- Avoid wrapping arithmetic here: this is an addition amount, not a sum.
        if state.energy>0 then plan.top[1]=e('energy',state.energy) end
    elseif op=='xBlock' then
        assert(integer(effect.blockAmount),'unprepared X block')
        local amount=context.energyOnUse
        if amount==nil or amount==-1 then amount=state.energy end
        assert(integer(amount),'invalid X energy snapshot')
        assert(context.freeToPlayOnce==nil or type(context.freeToPlayOnce)=='boolean','invalid X free flag')
        assert(context.chemicalX==nil or context.chemicalX==false or context.chemicalX==0,'Chemical X not supported')
        if amount>0 then
            plan.bottom[1]=e('xBlockRounds',effect.blockAmount,{remaining=amount,fixed=true})
            plan.consumeAllEnergy=context.freeToPlayOnce~=true
        end
    elseif op=='ftlDamage' then
        assert(integer(effect.value) and integer(effect.normalAmount) and integer(effect.threshold),'unprepared FTL')
        assert(integer(context.cardsPlayedBefore),'missing FTL turn history')
        if context.cardsPlayedBefore<effect.threshold then plan.top[1]=e('draw',1) end
        plan.bottom[1]=e('damage',effect.value,{normalAmount=effect.normalAmount})
    else return nil end
    return plan
end
return M
