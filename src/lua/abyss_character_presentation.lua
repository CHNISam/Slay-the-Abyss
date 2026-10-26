-- Detached development display adaptation; rules remain owned by Combat.
local M={}
local Curses=require('abyss_curses')
local names={corruption='腐化',feel_no_pain='无惧疼痛',dark_embrace='黑暗之拥',sentinel='哨卫',burning_pact='燃烧契约',sneaky_strike='潜袭',eviscerate='剔骨',calculated_gamble='筹谋',loop='循环',electrodynamics='电动力学',protect='护身',perseverance='坚韧',windmill_strike='风车打击',sands_of_time='化沙',accuracy='精准',infinite_blades='无限刀刃',prostrate='伏身',worship='礼拜',devotion='供奉',deadly_poison='毒液',shiv='飞刃',blade_dance='刃舞',survivor='撤身',acrobatics='翻找',
    tactician='战术储备',reflex='灵思',footwork='步法',backflip='闪避翻滚',dagger_throw='掷刃',
    dagger_spray='双刃扫射',cloak_and_dagger='藏刃',prepared='预备',quick_slash='疾斩',catalyst='毒性催化',
    bouncing_flask='弹跳毒瓶',noxious_fumes='毒雾',neutralize='牵制',
    eruption='爆发',vigilance='警戒',empty_fist='空拳',empty_body='空身',crescendo='渐强',tranquility='静息',
    rushdown='疾袭',mental_fortress='心墙',inner_peace='静心',cut_through_fate='破命斩',third_eye='观心',
    just_lucky='巧手',nirvana='澄明',miracle='奇迹',
    bane='毒杀',slice='切割',sucker_punch='突袭',poisoned_stab='淬毒刺击',riddle_with_holes='千疮百孔',
    backstab='背刺',adrenaline='肾上腺素',deflect='偏斜',caltrops='铁蒺藜',flying_knee='飞膝',outmaneuver='抢占先机',
    dodge_and_roll='闪躲翻滚',grand_finale='华丽收场',heel_hook='足跟勾',wound='伤口',burn='灼伤',void='虚空'}
local rebuilt={clash=true,true_grit=true,warcry=true,metallicize=true,whirlwind=true,demon_form=true,reaper=true,
    corruption=true,feel_no_pain=true,dark_embrace=true,sentinel=true,burning_pact=true}
local live={damage=true,damageAll=true,block=true,whirlwind=true,reaperDamage=true,
    bowlingBash=true,barrageDamage=true,ftlDamage=true,heelHook=true,xBlock=true,nextBlock=true,halt=true,
    fiendFire=true,secondWind=true,fearNoEvil=true,wallop=true,flowDamage=true,stackBlock=true,autoShields=true,
    blizzardDamage=true,sunderDamage=true,randomEngineAttack=true,thunderStrike=true,escapePlan=true,
    finisherDamage=true,flechettesDamage=true,skewer=true,glassKnife=true}
local statuses={strength='力量',dexterity='敏捷',vulnerable='易伤',weak='虚弱',poison='中毒',barricade='壁垒',
    metallicize='金属化',demon_form='恶魔形态',noxious_fumes='毒雾',nirvana='澄明',accuracy='精准',infinite_blades='无限刀刃',
    thorns='荆棘',artifact='人工制品',blur='残影',choked='勒脖',draw_next_turn='下回合抽牌',shackled='力量恢复'}
local function copy(x,active)
    if type(x)~='table' then return x end
    assert(getmetatable(x)==nil,'presentation requires plain tables')
    active=active or {};assert(not active[x],'cyclic presentation data');active[x]=true
    local y={};for k,v in pairs(x) do y[k]=copy(v,active) end;active[x]=nil;return y
end
local function integer(n) return type(n)=='number' and n==math.floor(n) and math.abs(n)<=2147483647 end
local function number(n) assert(integer(n),'invalid display number');return string.format('%.0f',n) end
local function dense(t)
    assert(type(t)=='table' and getmetatable(t)==nil,'effects must be plain array')
    local n=0;for k in pairs(t) do assert(integer(k) and k>0,'invalid effect array');n=n+1 end
    for i=1,n do assert(t[i]~=nil,'sparse effect array') end
    return n
end
local function fragments(card,dynamic,path)
    path=path or 'effects'
    if card.condition~=nil then assert(card.condition=='only_attacks_in_hand' or card.condition=='draw_pile_empty','unknown card condition') end
    if card.costMode~=nil then assert(card.costMode=='all_energy','unknown cost mode') end
    if card.requiresNoOtherAttack~=nil then assert(type(card.requiresNoOtherAttack)=='boolean' and (not card.requiresNoOtherAttack or card.id=='signature_move'),'unknown attack-hand condition') end
    local n=dense(card.effects)
    if n==0 then
        if card.id=='dazed' then return '不能打出。虚无：回合结束时仍在手中则消耗。'
        elseif card.id=='slimed' then return '消耗：打出后移出本场战斗。'
        elseif card.id=='regret' then return '不能打出。回合结束时，失去与手牌张数相同的生命。'
        elseif card.id=='tactician' then return '不能打出。被主动弃掉时，获得 '..(card._upgraded and '2' or '1')..' 点能量。'
        elseif card.id=='reflex' then return '不能打出。被主动弃掉时，抽 '..(card._upgraded and '3' or '2')..' 张牌。'
        elseif card.id=='wound' then return '不能打出。'
        elseif card.id=='burn' then
            local damage=card.burnDamage
            if damage==nil then damage=card.endTurnDamage end
            return '不能打出。回合结束时受到 '..number(damage)..' 点伤害；格挡可以抵挡。'
        elseif card.id=='void' then return '不能打出。抽到时失去 1 点能量。虚无：回合结束时仍在手中则消耗。'
        elseif Curses.isImplemented(card) then
            local descriptions={
                injury='不能打出。',
                doubt='不能打出。回合结束时，获得 1 回合虚弱。',
                pain='不能打出。在手牌中时，每打出一张牌便失去 1 点生命。',
                decay='不能打出。回合结束时受到 2 点伤害；格挡可以抵挡。',
                shame='不能打出。回合结束时，获得 1 回合脆弱。',
                writhe='固有。不能打出。',
                clumsy='不能打出。虚无：回合结束时仍在手中则消耗。',
                normality='不能打出。在手牌中时，每回合最多打出 3 张牌。',
                parasite='不能打出。从牌组中永久移除时，最大生命值降低 3 点。',
            }
            return assert(descriptions[card.id],'missing supported curse description')
        end
        error('unknown empty card: '..tostring(card.id))
    end
    local out={}
    for i,e in ipairs(card.effects) do
        assert(type(e)=='table','invalid effect')
        local op=e.op
        local function value()
            number(e.value)
            return dynamic and live[op] and ('{'..path..'.'..(i-1)..'.value}') or number(e.value)
        end
        local text
        if op=='damage' or op=='damageAll' then
            text=(op=='damage' and '对目标造成 ' or '对每个敌人造成 ')..value()..' 点伤害'
            if e.times then assert(integer(e.times) and e.times>0,'invalid hit count');text=text..'，重复 '..number(e.times)..' 次' end
        elseif op=='block' then text='获得 '..value()..' 点格挡'
        elseif op=='draw' then text='抽 '..value()..' 张牌'
        elseif op=='energy' then text='获得 '..value()..' 点能量'
        elseif op=='loseHp' then text='失去 '..value()..' 点生命'
        elseif op=='applyStatus' or op=='applyStatusAll' then
            local status=assert(statuses[e.status],'unknown display status: '..tostring(e.status))
            local unit=(e.status=='weak' or e.status=='vulnerable') and ' 回合' or ' 层'
            if e.status=='choked' then assert(op=='applyStatus','unknown Choke target');text='本回合每打出一张牌，该目标失去 '..value()..' 点生命'
            else text=(op=='applyStatusAll' and '对每个敌人施加 ' or '对目标施加 ')..value()..unit..status end
        elseif op=='gainTemporaryStrength' then text='本回合获得 '..value()..' 层力量，回合结束移除'
        elseif op=='gainStatus' then
            local status=assert(statuses[e.status],'unknown gain status')
            if e.status=='metallicize' then text='每回合结束获得 '..value()..' 点固定格挡'
            elseif e.status=='demon_form' then text='从下回合起，每回合抽牌后获得 '..value()..' 层力量'
            elseif e.status=='noxious_fumes' then text='从下回合起，每回合抽牌后给所有敌人施加 '..value()..' 层中毒'
            elseif e.status=='accuracy' then text='使飞刃的基础伤害提高 '..value()..' 点'
            elseif e.status=='infinite_blades' then text='从下回合起，每回合开始生成 '..value()..' 张飞刃；满手时放入弃牌堆'
            elseif e.status=='nirvana' then text='每次占卜时获得 '..value()..' 点固定格挡'
            elseif e.status=='barricade' then number(e.value);text='回合开始时保留已有格挡'
            elseif e.status=='blur' then text='接下来 '..value()..' 次自身回合开始时保留已有格挡'
            elseif e.status=='draw_next_turn' then text='下回合正常抽牌后额外抽 '..value()..' 张牌，随后移除本状态'
            else text='获得 '..value()..' 层'..status end
        elseif op=='generateShivs' then text='生成 '..value()..' 张飞刃加入手牌；满手时放入弃牌堆'
        elseif op=='requestDiscard' then text='选择并弃掉 '..value()..' 张手牌'
        elseif op=='multiplyPoison' then text='使目标已有中毒层数变为 '..value()..' 倍'
        elseif op=='bouncingPoison' then text='随机选择存活敌人施加 3 层中毒，重复 '..value()..' 次'
        elseif op=='channelOrb' then
            local orb=assert(({lightning='闪电球',frost='冰霜球',dark='黑暗球',plasma='等离子球'})[e.orb],'unknown display orb')
            assert(e.value==1,'unsupported channel repetition')
            local previous=card.effects[i-1]
            if previous and previous.op=='channelOrb' and previous.orb==e.orb and previous.value==1 then text=''
            else
                local count=1
                for j=i+1,n do local nextEffect=card.effects[j];if nextEffect.op=='channelOrb' and nextEffect.orb==e.orb and nextEffect.value==1 then count=count+1 else break end end
                text='生成 '..number(count)..' 个'..orb
            end
        elseif op=='dualcastOrb' then assert(e.value==1,'unsupported dualcast repetition');text='将最前方的同一个充能球唤起两次，随后移除'
        elseif op=='darkImpulseOrb' then assert(e.value==1,'unsupported dark impulse repetition');text='立即触发所有黑暗球的被动增长一次'
        elseif op=='gainFocus' then text=(e.value>=0 and '获得 ' or '失去 ')..number(math.abs(e.value))..' 层集中'
        elseif op=='gainOrbSlots' or op=='loseOrbSlots' then text=(op=='gainOrbSlots' and '增加 ' or '失去 ')..value()..' 个球位'..(op=='loseOrbSlots' and '，删除末槽且不唤起' or '，最多 10 个')
        elseif op=='applyBias' then assert(e.value==1,'unsupported bias');text='获得偏差：从下回合起，每回合开始失去 1 层集中'
        elseif op=='changeStance' then text=assert(({Wrath='进入愤怒：攻击造成和受到的伤害均为两倍',Calm='进入平静：离开时获得 2 点能量',Neutral='退出当前姿态'})[e.stance],'unknown display stance')
        elseif op=='gainStancePower' then
            if e.status=='rushdown' then text='每次进入愤怒时抽 '..value()..' 张牌'
            elseif e.status=='mental_fortress' then text='每次改变姿态时获得 '..value()..' 点固定格挡'
            else error('unknown stance power') end
        elseif op=='innerPeace' then text='若已处于平静，抽 '..value()..' 张牌；否则进入平静'
        elseif op=='gainExhaustPower' then
            if e.status=='corruption' then assert(e.value==1,'unsupported Corruption amount');text='技能牌耗能变为 0，打出技能牌后消耗它'
            elseif e.status=='feel_no_pain' then text='每消耗一张牌，获得 '..value()..' 点固定格挡'
            elseif e.status=='dark_embrace' then text='每消耗一张牌，抽 '..value()..' 张牌'
            else error('unknown exhaust power') end
        elseif op=='gainEnergyIfDiscard' then
            assert(e.value==2,'unsupported discard refund');text='若本回合主动弃过牌，获得 2 点能量'
        elseif op=='calculatedGamble' then text='弃掉其余所有手牌，再抽等量牌'
        elseif op=='gainOrbPower' then
            if e.status=='loop' then text='获得 '..value()..' 层循环：从下回合起，每层每回合额外触发首球被动一次'
            elseif e.status=='electrodynamics' then assert(e.value==1,'unsupported Electro marker');text='闪电球的被动与唤起改为攻击所有存活敌人'
            else error('unknown orb power') end
        elseif op=='gainStrengthPower' then
            if e.status=='combust' then text='每回合结束失去 1 点生命，再对所有敌人造成 '..value()..' 点固定伤害；重复获得本能力也会增加每次失去的生命'
            elseif e.status=='rupture' then text='每当自己的效果使你失去生命，获得 '..value()..' 层力量'
            elseif e.status=='brutality' then text='从下回合起，每回合正常抽牌后额外抽 '..value()..' 张牌，再失去等量生命'
            elseif e.status=='berserk' then text='从下回合起，每回合恢复能量时额外获得 '..value()..' 点能量'
            else error('unknown strength power') end
        elseif op=='gainCardTriggerPower' then
            if e.status=='after_image' then text='每打出一张牌，获得 '..value()..' 点固定格挡'
            elseif e.status=='thousand_cuts' then text='每打出一张牌，在该牌清理后对所有敌人造成 '..value()..' 点固定伤害'
            elseif e.status=='envenom' then text='普通攻击每次造成未被格挡的正数伤害时，对目标施加 '..value()..' 层中毒'
            elseif e.status=='rage' then text='本回合每打出一张攻击牌，获得 '..value()..' 点固定格挡'
            elseif e.status=='heat_sinks' then text='每打出一张能力牌，抽 '..value()..' 张牌'
            elseif e.status=='storm' then text='每打出一张能力牌，生成 '..value()..' 个闪电球'
            else error('unknown card-trigger power') end
        elseif op=='spotWeakness' then text='若目标正准备攻击，获得 '..value()..' 层力量'
        elseif op=='nextEnergy' then text='下回合恢复能量时额外获得 '..value()..' 点能量'
        elseif op=='nextBlock' then text='下回合开始时获得 '..value()..' 点固定格挡'
        elseif op=='heelHook' then text='对目标造成 '..value()..' 点伤害；若目标有虚弱，获得 1 点能量并抽 1 张牌'
        elseif op=='barrageDamage' then text='每有一个已填充的充能球，对目标造成一次 '..value()..' 点伤害'
        elseif op=='compileDriverDraw' then assert(e.value==1,'unknown Compile Driver amount');text='每有一种不同类型的充能球，抽 1 张牌'
        elseif op=='weakIfAttacking' then text='若目标正准备攻击，对目标施加 '..value()..' 回合虚弱'
        elseif op=='xBlock' then text='消耗所有当前能量，每点能量获得一次 '..value()..' 点格挡'
        elseif op=='doubleEnergy' then assert(e.value==1,'unknown Double Energy amount');text='将扣除本牌费用后剩余的能量翻倍'
        elseif op=='ftlDamage' then
            assert(integer(e.threshold) and e.threshold>0,'invalid FTL threshold')
            text='若本回合此前打出的牌少于 '..number(e.threshold)..' 张，先抽 1 张牌；随后对目标造成 '..value()..' 点伤害'
        elseif op=='bowlingBash' then text='每有一名存活且未逃离的敌人，对目标造成一次 '..value()..' 点伤害'
        elseif op=='halt' then
            number(e.wrathValue)
            if dynamic then text='当前获得 '..value()..' 点格挡（若处于愤怒，已计入额外部分）'
            else text='获得 '..value()..' 点格挡；若处于愤怒，额外获得 '..number(e.wrathValue)..' 点格挡' end
            text=text..'；两部分分别受敏捷与脆弱影响'
        elseif op=='drawToHandSize' then assert(e.value==10,'unsupported hand-size draw');text='抽牌直到手牌有 10 张；受不能抽牌和可用牌数限制'
        elseif op=='previousCardType' then
            local previous=assert(({attack='攻击牌',skill='技能牌'})[e.cardType],'unknown previous card type')
            assert(type(e.effect)=='table' and (e.effect.op=='energy' or e.effect.op=='draw' or e.effect.op=='applyStatus'),'unsupported previous-card effect')
            text='若本场战斗上一张打出的牌是'..previous..'，'..fragments({id=card.id,effects={e.effect}},false):gsub('。$','')
        elseif op=='makeTempCardInHand' then
            assert(e.card=='wound','unknown generated hand card')
            text='生成 '..value()..' 张伤口加入手牌；满手时放入弃牌堆'
        elseif op=='makeTempCard' then
            local id=e.cardId or e.card
            assert(not e.cardId or not e.card or e.cardId==e.card,'conflicting generated card identity')
            local name=assert(({insight='洞见',safety='安全',smite='惩罚',through_violence='以暴制暴',wound='伤口',dazed='晕眩'})[id],'unknown generated card')
            assert(e.value==1 and (e.upgraded==false or e.upgraded==nil),'unsupported generated amount or upgrade')
            if e.pile=='draw' then
                assert((id=='insight' or id=='through_violence' or id=='wound' or id=='dazed') and e.randomSpot==true,'unsupported generated draw card')
                text='将 1 张'..((id=='wound' or id=='dazed') and '' or '未升级的')..name..'随机插入抽牌堆'
            else assert(e.pile=='hand' and (id=='safety' or id=='smite') and not e.randomSpot,'unsupported generated hand card');text='将 1 张未升级的'..name..'加入手牌；满手时放入弃牌堆' end
        elseif op=='limitBreak' then assert(e.value==0,'unsupported Limit Break marker');text='将你当前的力量翻倍'
        elseif op=='exhaustNonAttacks' then assert(e.value==0,'unsupported exhaust marker');text='消耗其余手牌中所有非攻击牌'
        elseif op=='secondWind' then text='消耗其余手牌中所有非攻击牌，每消耗 1 张获得 '..value()..' 点格挡'
        elseif op=='fiendFire' then text='消耗其余所有手牌，每消耗 1 张对目标造成 '..value()..' 点伤害'
        elseif op=='gainStatusPower' then
            if e.status=='flame_barrier' then text='直到下个自身回合开始，每次受到普通攻击时，对攻击者造成 '..value()..' 点固定反击伤害'
            elseif e.status=='evolve' then text='每当抽到一张状态牌，额外抽 '..value()..' 张牌'
            elseif e.status=='fire_breathing' then text='每当抽到一张状态牌或诅咒牌，对所有敌人造成 '..value()..' 点固定伤害'
            else error('unknown status-build Power') end
        elseif op=='growClaws' then assert(e.value==2,'unsupported Claw growth');text='本场战斗所有利爪的基础伤害增加 2，包括本牌；已消耗的其他利爪不增长'
        elseif op=='stackBlock' then
            if dynamic then text='获得 '..value()..' 点格挡（基础值等于当前弃牌堆张数'..(e.value>0 and '加 '..number(e.value) or '')..'）'
            else text='获得等同于弃牌堆张数'..(e.value>0 and '加 '..number(e.value) or '')..'的格挡' end
        elseif op=='loseSteamBlock' then assert(e.value==1,'unsupported Steam loss');text='本场战斗本牌的基础格挡降低 1'
        elseif op=='reduceStreamlineCost' then assert(e.value==1,'unsupported Streamline cost change');text='本场战斗本牌费用降低 1，最低 0'
        elseif op=='aggregateEnergy' then assert(e.value==3 or e.value==4,'unsupported Aggregate divisor');text='抽牌堆每有 '..value()..' 张牌，获得 1 点能量'
        elseif op=='autoShields' then text='若使用时没有格挡，获得 '..value()..' 点格挡'
        elseif op=='blizzardDamage' then
            assert(e.perOrb==2 or e.perOrb==3,'invalid Blizzard history multiplier')
            if dynamic then text='对每个敌人造成 '..value()..' 点伤害（基础伤害为本战生成过的冰霜球数量 × '..number(e.perOrb)..'）'
            else text='对每个敌人造成一次伤害，基础伤害为本战生成过的冰霜球数量 × '..number(e.perOrb) end
        elseif op=='chaosOrbs' then assert(e.value==1 or e.value==2,'unsupported Chaos count');text='生成 '..value()..' 个随机充能球'
        elseif op=='chillOrbs' then assert(e.value==1,'unsupported Chill factor');text='每有一名存活且未逃离的敌人，生成 1 个冰霜球'
        elseif op=='applyLockOn' then text='给目标施加 '..value()..' 回合锁定：受到的闪电和黑暗球伤害提高 50%'
        elseif op=='removeBlock' then assert(e.value==1,'unsupported remove Block marker');text='先移除目标的全部格挡'
        elseif op=='randomEngineAttack' then
            assert(integer(e.times) and e.times>0,'invalid random attack count')
            text='对随机存活敌人造成 '..value()..' 点普通伤害，分别随机选择 '..number(e.times)..' 次'
        elseif op=='sunderDamage' then text='对目标造成 '..value()..' 点伤害；若本次击杀目标，获得 3 点能量'
        elseif op=='tempestOrbs' or op=='multiCastOrb' then
            assert(e.value==0 or e.value==1,'invalid X orb upgrade')
            local x=e.value==1 and 'X+1' or 'X'
            text='消耗所有当前能量，'..(op=='tempestOrbs' and ('生成 '..x..' 个闪电球') or ('将最前方同一个充能球唤起 '..x..' 次，仅最后一次移除它'))
        elseif op=='thunderStrike' then text='本场战斗每生成过一个闪电球，对随机存活敌人造成一次 '..value()..' 点普通伤害'
        elseif op=='gainWatcherFlowPower' then
            if e.status=='battle_hymn' then text='从下回合起，每回合开始时生成 '..value()..' 张未升级惩罚加入手牌；满手时放入弃牌堆'
            elseif e.status=='energy_down' then text='从下回合起，每回合开始失去 '..value()..' 点能量'
            elseif e.status=='like_water' then text='回合结束的手牌处理之前，若处于平静，获得 '..value()..' 点固定格挡'
            elseif e.status=='study' then text='每回合结束时，将 '..value()..' 张未升级洞见随机插入抽牌堆'
            elseif e.status=='wrath_next_turn' then assert(e.value==1,'invalid next Wrath marker');text='下个自身回合开始时进入愤怒，随后移除此状态'
            elseif e.status=='draw_card_next_turn' then text='下个自身回合正常抽牌后，额外抽 '..value()..' 张牌，随后移除此状态'
            elseif e.status=='vigor' then text='下一张攻击的每次普通伤害增加 '..value()..' 点'
            elseif e.status=='collect' then text='接下来 '..value()..' 次恢复能量时，各生成 1 张奇迹+'
            else error('unknown Watcher flow Power') end
        elseif op=='applyWatcherFlowPower' then
            if e.status=='block_return' then text='给目标施加格挡返还：此后其每次受到普通攻击时，给予你 '..value()..' 点固定格挡；完全格挡也触发'
            elseif e.status=='mark' then text='给目标施加 '..value()..' 层印记'
            else error('unknown Watcher flow debuff') end
        elseif op=='fearNoEvil' then text='对目标造成 '..value()..' 点伤害；若目标正准备攻击，随后进入平静'
        elseif op=='wallop' then text='对目标造成 '..value()..' 点伤害，获得等同于本次实际扣除敌人生命的固定格挡'
        elseif op=='flowDamage' then
            text='对目标造成 '..value()..' 点伤害'
            if e.times then assert(integer(e.times) and e.times>0,'invalid flow hit count');text=text..'，重复 '..number(e.times)..' 次' end
        elseif op=='indignation' then text='若已处于愤怒，给所有敌人施加 '..value()..' 回合易伤；否则进入愤怒'
        elseif op=='collect' then assert(e.value==0 or e.value==1,'invalid Collect upgrade');text='消耗所有当前能量，接下来 '..(e.value==1 and 'X+1' or 'X')..' 次恢复能量时，各生成 1 张奇迹+'
        elseif op=='triggerMarks' then assert(e.value==1,'invalid Mark trigger');text='所有敌人失去等同于自身印记层数的生命，无视格挡'
        elseif op=='piercingWail' then text='使所有敌人暂时失去 '..value()..' 层力量，在各自回合结束时恢复'
        elseif op=='allOutDiscard' then assert(e.value==1,'invalid random discard count');text='随机主动弃掉 1 张其余手牌'
        elseif op=='concentrateDiscard' then assert(e.value==2 or e.value==3,'invalid Concentrate count');text='主动弃掉 '..value()..' 张其余手牌，然后获得 2 点能量'
        elseif op=='cripplingPoison' then text='对所有敌人先施加 '..value()..' 层中毒，再施加 2 回合虚弱'
        elseif op=='escapePlan' then text='抽 1 张牌；若本次抽到技能牌，获得 '..value()..' 点格挡'
        elseif op=='expertise' then assert(e.value==6 or e.value==7,'invalid Expertise hand size');text='抽牌直到手牌达到 '..value()..' 张'
        elseif op=='finisherDamage' then text='本回合此前每打出一张攻击牌，对目标造成一次 '..value()..' 点伤害'
        elseif op=='flechettesDamage' then text='其余手牌中每有一张技能牌，对目标造成一次 '..value()..' 点伤害'
        elseif op=='skewer' then text='消耗所有当前能量，每点能量对目标造成一次 '..value()..' 点伤害'
        elseif op=='glassKnife' then text='对目标造成 '..value()..' 点伤害两次；然后本场战斗本牌的基础伤害降低 2'
        elseif op=='malaise' then assert(e.value==0 or e.value==1,'invalid Malaise upgrade');local x=e.value==1 and 'X+1' or 'X';text='消耗所有当前能量，使目标失去 '..x..' 层力量，并施加 '..x..' 回合虚弱'
        elseif op=='unload' then assert(e.value==0,'invalid Unload marker');text='主动弃掉其余手牌中所有非攻击牌'
        elseif op=='stormOfSteel' then
            assert(e.value==0 and type(e.upgraded)=='boolean','invalid Storm of Steel upgrade')
            text='主动弃掉其余所有手牌，每弃掉 1 张，生成 1 张'..(e.upgraded and '升级飞刃' or '飞刃')..'加入手牌'
        elseif op=='gainMantra' then text='获得 '..value()..' 层真言'
        elseif op=='gainDevotion' then text='获得 '..value()..' 层供奉：从下回合起，每回合抽牌后获得等量真言；没有真言且供奉达到 10 层时，直接进入神格'
        elseif op=='scry' then text='占卜 '..value()..'：查看牌堆顶牌，选择任意张弃掉'
        elseif op=='pileChoice' then
            local modes={headbutt='从弃牌堆选1张牌放回抽牌堆顶',exhume='从消耗堆选1张非发掘牌回手',
                hologram='从弃牌堆选1张牌回手',seek='从抽牌堆选'..value()..'张牌回手'}
            assert(e.value==1 or e.mode=='seek' and e.value==2,'invalid retrieval count')
            text=assert(modes[e.mode],'unknown retrieval mode')
        elseif op=='handChoice' then
            local mode=assert(({exhaust_random='随机消耗 ',exhaust_choose='选择并消耗 ',put_on_deck='选择并放回抽牌堆顶 '})[e.mode],'unknown hand choice')
            text=mode..value()..' 张手牌'
        elseif op=='whirlwind' then text='消耗所有当前能量，每点能量对每个敌人造成 '..value()..' 点伤害'
        elseif op=='reaperDamage' then text='对每个敌人造成 '..value()..' 点伤害，并回复与实际扣除的生命等量的生命'
        elseif op=='damageEqualToBlock' then text='以当前格挡作为基础，对目标造成伤害'
        elseif op=='doubleBlock' then text='使当前格挡翻倍'
        elseif op=='noDrawThisTurn' then text='本回合不能再抽牌'
        elseif op=='addCardToDiscard' then text='将本牌的一张复制放入弃牌堆'
        elseif op=='increaseDamageThisCombat' then text='本场战斗中，本牌伤害永久增加 '..value()
        elseif op=='makeTempCardInDiscard' then
            if card.id=='overclock' or card.id=='turbo' or card.id=='immolate' then
                local name=assert(({burn='灼伤',void='虚空'})[e.card],'unknown generated utility card')
                text='在弃牌堆生成 '..value()..' 张'..name
            else text='在弃牌堆生成 '..value()..' 张临时牌' end
        elseif op=='conditional' then
            assert(path=='effects','nested conditional presentation unsupported')
            assert((e['if']=='target_vulnerable' or e['if']=='target_poison') and e['else']==nil,'unknown conditional')
            local nested={id=card.id,effects=e['then']}
            text=(e['if']=='target_poison' and '若目标有中毒，' or '若目标有易伤，')..fragments(nested,dynamic,path..'.'..(i-1)..'.then'):gsub('。$','')
        else error('unsupported presentation effect: '..tostring(op)) end
        if text~='' then out[#out+1]=text end
    end
    local prefix=''
    if card.condition then
        assert(card.condition=='only_attacks_in_hand' or card.condition=='draw_pile_empty','unknown card condition')
        prefix=card.condition=='draw_pile_empty' and '仅当抽牌堆为空时才能打出。' or '只有剩余手牌全部为攻击牌时才能打出。'
    end
    if card.requiresNoOtherAttack then assert(card.requiresNoOtherAttack==true and card.id=='signature_move','unknown attack-hand condition');prefix=prefix..'仅当手牌中没有其他攻击牌时才能打出。' end
    if card.costMode then assert(card.costMode=='all_energy','unknown cost mode') end
    local text=prefix..table.concat(out,'；')..'。'
    if card.id=='sentinel' then text=text..'本牌被消耗时，获得 '..(card._upgraded and '3' or '2')..' 点能量。'
    elseif card.id=='eviscerate' then text=text..'本回合每次主动弃牌，本牌费用降低 1，最低 0；新回合恢复基础费用。'
    elseif card.id=='perseverance' then text=text..'每次保留时，本牌本场战斗格挡增加 '..(card._upgraded and '3' or '2')..'。'
    elseif card.id=='windmill_strike' then text=text..'每次保留时，本牌本场战斗伤害增加 '..(card._upgraded and '5' or '4')..'。'
    elseif card.id=='sands_of_time' then text=text..'每次保留时，本牌本场战斗费用降低 1，最低 0。' end
    if card.id=='heavy_blade' then
        assert(card.strengthMultiplier==3 or card.strengthMultiplier==5,'invalid Heavy Blade multiplier')
        text=text..'力量对本牌的伤害加成为 '..number(card.strengthMultiplier)..' 倍。'
    elseif card.id=='perfected_strike' then
        assert(card.strikeBonus==2 or card.strikeBonus==3,'invalid Perfected Strike bonus')
        text=text..'手牌、抽牌堆和弃牌堆中每有一张带打击标签的牌，基础伤害增加 '..number(card.strikeBonus)..'。'
    elseif card.id=='brilliance' then text=text..'本场战斗每获得 1 点真言，基础伤害增加 1。' end
    if card.id=='blood_for_blood' then text=text..'本场战斗每次实际失去生命，本牌费用降低 1，最低 0。'
    elseif card.id=='flurry_of_blows' then text=text..'每次实际改变姿态后，若本牌在弃牌堆且手牌未满，将其返回手牌。'
    elseif card.id=='weave' then text=text..'占卜非空抽牌堆时，若本牌在弃牌堆且手牌未满，将其返回手牌。' end
    if card.shuffleBackIntoDrawPile then assert(card.id=='tantrum' and card.shuffleBackIntoDrawPile==true,'unknown shuffle-back flag');text=text..'打出后将原牌随机插回抽牌堆。' end
    if card.selfRetain then text=text..'保留。' end
    if card.innate then text=text..'先天：开局优先抽到。' end
    if card.exhaust then text=text..'消耗。' end
    if card.ethereal then text=text..'虚无：回合结束时仍在手中则消耗。' end
    return text
end
local function cost(card)
    assert(integer(card.cost),'invalid card cost')
    if card.costMode then assert(card.costMode=='all_energy' and card.cost==-1,'invalid X cost');return 'X' end
    return card.cost==-2 and '—' or number(card.cost)
end
-- These nine native cards are outside the explicitly prepared 66-card pool.
-- Their existing display is audited for the native ABI, not experimental ops.
local nativeOnly={
    armaments={'Armaments','SELF','skill',1,1,{{op='block',value=5},{op='upgradeHand'}},{{op='block',value=5},{op='upgradeHand',all=true}}},
    havoc={'Havoc','NONE','skill',1,0,{{op='playTop'}}},
    sword_boomerang={'Sword Boomerang','ALL_ENEMY','attack',1,1,{{op='damageRandom',value=3,times=3}},{{op='damageRandom',value=3,times=4}}},
    dual_wield={'Dual Wield','NONE','skill',1,1,{{op='dualWield',value=1}},{{op='dualWield',value=2}}},
    infernal_blade={'Infernal Blade','NONE','skill',1,0,{{op='generateAttack',value=0}},nil,{exhaust=true}},
    searing_blow={'Searing Blow','ENEMY','attack',2,2,{{op='damage',value=12}},{{op='damage',value=16}},{repeatable=true}},
    double_tap={'Double Tap','SELF','skill',1,1,{{op='gainStatus',status='double_tap',value=1}},{{op='gainStatus',status='double_tap',value=2}}},
    feed={'Feed','ENEMY','attack',1,1,{{op='feed',value=10,maxHp=3}},{{op='feed',value=12,maxHp=4}},{exhaust=true,healing=true}},
    juggernaut={'Juggernaut','SELF','power',2,2,{{op='gainStatus',status='juggernaut',value=5}},{{op='gainStatus',status='juggernaut',value=7}}},
}
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k,v in pairs(b) do if not same(v,a[k]) then return false end end
    return true
end
local function nativeDisplay(card,upgraded,current)
    local spec=nativeOnly[card.id]
    if not spec or card.target==nil or card.experimental==true then return false end
    assert(card.sourceId==spec[1] and card.target==spec[2] and card.type==spec[3]
        and card.cost==spec[4] and upgraded.cost==spec[5],'incompatible native display: '..card.id)
    assert(card.condition==nil and upgraded.condition==nil and card.costMode==nil and upgraded.costMode==nil
        and card.requiresNoOtherAttack==nil and upgraded.requiresNoOtherAttack==nil,'unknown native display condition')
    for _,key in ipairs({'exhaust','healing','repeatable','selfRetain','innate','ethereal'}) do
        local expected=spec[8] and spec[8][key]==true or false
        assert((card[key]==true)==expected and (upgraded[key]==true)==expected,'unknown native display keyword')
    end
    dense(card.effects);dense(upgraded.effects)
    assert(same(card.effects,spec[6]) and same(upgraded.effects,spec[7] or spec[6]),'unknown native presentation effect')
    assert(current and type(current.name)=='string' and current.name~='' and type(current.text)=='string' and current.text~=''
        and type(current.upgradeText)=='string' and current.upgradeText~='','missing native presentation: '..card.id)
    return true
end
function M.prepare(existing,prepared)
    assert(type(existing)=='table' and type(prepared)=='table' and prepared.cards and type(prepared.cards.cards)=='table','invalid presentation inputs')
    local out=copy(existing)
    local seen={}
    for _,card in ipairs(prepared.cards.cards) do
        assert(type(card.id)=='string' and not seen[card.id],'duplicate or invalid card id');seen[card.id]=true
        assert(card.type=='attack' or card.type=='skill' or card.type=='power' or card.type=='status' or card.type=='curse','unknown card type')
        local upgraded=copy(card);for k,v in pairs(card.upgrade or {}) do upgraded[k]=copy(v) end;upgraded._upgraded=true
        local current=out[card.id]
        if card.originalV4 then
            local describe=require('abyss_original_v4_display').describe
            current={id=card.id,name=card.name,text=describe(card,false),upgradeText=describe(card,true)}
            out[card.id]=current
        elseif prepared.originalV4Role and current then
            -- Original profiles retain the already approved native pool unchanged.
            assert(type(current.name)=='string' and type(current.text)=='string' and type(current.upgradeText)=='string','incomplete native presentation')
        elseif not nativeDisplay(card,upgraded,current) then
          local text,upgradeText=fragments(card,false),fragments(upgraded,false)
          local combat,upgradeCombat=fragments(card,true),fragments(upgraded,true)
          if not current or rebuilt[card.id] or card.id=='burn' and card.burnDamage~=nil then
            local name=current and current.name or names[card.id] or card.name
            assert(type(name)=='string' and name~='' and name:find('[\128-\255]'),'missing Chinese card name: '..card.id)
            current={id=card.id,name=name,text=text,upgradeText=upgradeText}
            if combat~=text or upgradeCombat~=upgradeText then current.combatText=combat;current.upgradeCombatText=upgradeCombat end
            out[card.id]=current
          else
            assert(type(current.name)=='string' and current.name~='' and type(current.text)=='string' and current.text~=''
                and type(current.upgradeText)=='string' and current.upgradeText~='','incomplete existing display: '..card.id)
          end
        end
        current.id=card.id
        if prepared.originalV4Role and not card.originalV4 then
            -- Native content retains its registered ABI, including all-energy
            -- cards with numeric cost 0. Do not pass it through experimental cost().
            current.cost=card.costMode=='all_energy' and 'X' or card.cost==-2 and '—' or number(card.cost)
            current.upgradeCost=upgraded.costMode=='all_energy' and 'X' or upgraded.cost==-2 and '—' or number(upgraded.cost)
        else current.cost=cost(card);current.upgradeCost=cost(upgraded) end
        current.type=card.type
    end
    return out
end
return M
