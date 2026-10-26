-- Read-only text for the frozen original-character DSL. No combat mutation.
local M={}
local categories={normal='攻击·普攻',charged='攻击·重击',defense='技能·防御',
    skill='技能',command='技能·军令',burst='技能·爆发'}
local tags={normal='普攻',charged='重击',any='任意主动牌'}
local resources={bond='生命之契',fan='气氛',resolve='愿力'}
local members={usher='乌瑟勋爵',chevalmarin='海薇玛夫人',crabaletta='谢贝蕾妲小姐',singer='众水的歌者'}
local modes={ousia='荒性',pneuma='芒性'}
local roles={HT='胡桃',AR='阿蕾奇诺',FR='芙宁娜',RD='雷电将军'}
local conditions={
    bloom_target='所选存活目标有血梅香',bond0='生命之契为0',bond1='生命之契≥1',
    bond2='生命之契≥2',bond4='生命之契≥4',directive_target='所选存活目标有勒令',
    enemy_low='所选存活目标生命≤其最大生命50%',eye='雷眼有剩余次数且未到期',
    fan0='气氛为0',fan2='气氛≥2',fan3='气氛≥3',fan4='气氛≥4',fan6='气氛≥6',
    has_bloom='任一存活敌人有血梅香',has_directive='任一存活敌人有勒令',
    has_guest='至少一位宾客有剩余次数（暂停也计入）',has_mature='任一存活敌人有成熟勒令',
    has_singer='歌者有剩余次数（暂停也计入）',infused='蝶引未到期',
    low='生命≤最大生命50%',mature_target='所选存活目标的勒令已成熟',
    musou='梦想一心有剩余次数且未到期',not_bond4='生命之契<4',not_fan4='气氛<4',
    not_low='生命>最大生命50%',not_musou='梦想一心没有次数或已到期',
    ousia='处于荒性',pneuma='处于芒性',resolve0='愿力为0',resolve2='愿力≥2',
    resolve3='愿力≥3',resolve4='愿力≥4',
}
local function lookup(values,key,kind)
    return assert(values[key],'未知原创V4'..kind..'：'..tostring(key))
end
local function number(n)
    assert(type(n)=='number' and n==n and n>=0 and n<math.huge,'无效原创V4数值')
    return n%1==0 and string.format('%.0f',n) or tostring(n)
end
local function rawCard(card)
    assert(type(card)=='table','缺少原创V4卡牌')
    return card.originalV4 or card
end
local function variant(card,upgraded)
    local raw=rawCard(card)
    local up=upgraded
    if up==nil then up=card.upgraded==true or card._upgraded==true end
    if up then return raw,assert(raw.upgrade,'缺少原创V4升级牌面') end
    return raw,assert(raw.base,'缺少原创V4基础牌面')
end
local function targetText(effect)
    return lookup({one='所选存活目标',all='所有存活敌人'},effect.target,'目标')
end
local function formula(effect,resource,rounded)
    local base,coefficient=number(effect.n),effect.coefficient
    number(coefficient)
    if coefficient==0 then return base end
    local spent='本牌最近实际消费的'..(resource or '资源')
    local extra=coefficient==0.5 and '⌊'..spent..'÷2⌋'
        or number(coefficient)..'×'..spent
    return rounded and '⌊'..base..'＋'..extra..'⌋' or base..'＋'..extra
end
local renderEffects
local handlers={}
function handlers.damage(e)
    local hits=e.hits or 1
    return '对'..targetText(e)..'造成'..number(e.n)..'点伤害'
        ..(hits~=1 and '，共'..number(hits)..'段' or '')
end
function handlers.damage_spent(e,ctx)
    return '对'..targetText(e)..'造成'..formula(e,ctx.resource)..'点伤害'
end
function handlers.block(e)
    return e.n==0 and '本项格挡为0，不产生获得格挡收益' or '获得'..number(e.n)..'点格挡'
end
function handlers.block_spent(e,ctx)return '获得'..formula(e,ctx.resource)..'点格挡'end
function handlers.draw(e)return '抽'..number(e.n)..'张牌（手牌上限10）'end
function handlers.pay_hp(e)return '支付'..number(e.n)..'点生命（无视格挡，支付后须存活；全部付血先统一支付）'end
function handlers.heal(e)return '请求恢复'..number(e.n)..'点生命（共用每战12点实际治疗额度）'end
function handlers.heal_spent(e,ctx)
    return '请求恢复'..formula(e,ctx.resource,true)..'点生命（共用每战12点实际治疗额度）'
end
function handlers.infuse(e)
    return '蝶引阶段取原值与'..number(e.n)..'的较大值，最多2个结束阶段（含本回合，不重置重击次数）；'
        ..'期间普攻首命中＋2，每回合前2张重击首命中＋5并给所选存活目标挂1强度血梅香，低血时上述加成再＋1'
end
function handlers.end_infuse()return '结束蝶引，已有血梅香保留'end
function handlers.bloom(e)
    return '为'..targetText(e)..'施加血梅香：强度取原值与'..number(e.n)
        ..'的较大值，最多3；剩余次数重设2，每次己方结束造成2×强度的衍生伤害，受格挡'
end
function handlers.cash_bloom(e)
    local target=e.target==nil and '所选存活目标' or targetText(e)
    return '立即兑现'..target..'血梅香剩余伤害（2×强度×剩余次数）并清空，受格挡，不吃根加成或欢腾'
end
function handlers.bonus(e)
    return '本回合下一张带直接伤害的'..lookup(tags,e.tag,'准备标签')..'首命中额外＋'
        ..number(e.n)..'；与已有准备取大，单槽最多6，同值覆盖标签'
end
function handlers.directive(e)
    return '为'..targetText(e)..'施加勒令，下次己方回合开始成熟；已成熟的不降级，带标记敌人死亡收4契，标记仅结算一次'
end
function handlers.mature(e)return '使'..targetText(e)..'已有勒令成熟，无标记不生效'end
function handlers.absorb(e)
    return '按编队顺序吸收并移除'..targetText(e)..'勒令：未成熟收2契，成熟收6契，生命之契上限8；标记仅结算一次'
end
function handlers.spend(e,ctx)
    ctx.resource=lookup(resources,e.resource,'资源')
    return '消费'..(e.n=='all' and '当前全部' or number(e.n)..'点')..ctx.resource
end
function handlers.mode(e)
    return '切换为'..lookup(modes,e.mode,'形态')..'（同形态不触发切换，不刷新召唤次数）'
end
function handlers.toggle()return '切换荒／芒形态，不刷新召唤次数'end
function handlers.summon(e)
    local action=lookup({usher='对当前生命最高敌人造成4点衍生伤害',
        chevalmarin='对所有存活敌人各造成2点衍生伤害',crabaletta='对当前生命最低敌人造成5点衍生伤害'},e.member,'宾客')
    return '召唤／刷新'..lookup(members,e.member,'宾客')..'，次数取原值与'..number(e.n)
        ..'的较大值，最多3次，同名唯一；荒性才行动，此次召唤不立即行动；每次'..action
        ..'（平局依编队顺序），若行动前生命>最大生命50%，支付1生命且本批首命中＋1'
end
function handlers.singer(e)
    return '歌者次数取原值与'..number(e.n)..'的较大值，最多3次；芒性才行动，每次请求恢复2点生命（共享战斗治疗额度）'
end
function handlers.trigger(e)
    local member=e.member=='all' and '当前形态的召唤物（荒性依乌瑟、海薇玛、谢贝蕾妲顺序；芒性为歌者）'
        or lookup(members,e.member,'召唤物')
    return '令'..member..'立即行动一次并消耗真实次数；形态不符、无次数或无存活敌人时无效'
end
function handlers.revelry(e)
    return '以本牌实际消费气氛建立'..number(e.n)..'批欢腾（最多3批），持续2个结束阶段，整包替换旧值；'
        ..'每批首命中额外＋min(4,⌊实际消费气氛÷3⌋)，本牌后续直接伤害也消耗一批，群体不按目标重复加成'
end
function handlers.resolve(e)return '获得'..number(e.n)..'愿力（所有来源共用每回合增长2、总量6上限）'end
function handlers.eye(e)
    return '雷眼次数取原值与'..number(e.n)..'的较大值，最多3次，持续2个结束阶段；'
        ..'之后主动牌实际造成直接生命伤害时追击2点，每牌最多一次，不追击新建自身的命中，不递归'
end
function handlers.eye_pulse()return '若雷眼有效且所选目标存活，消耗1次造成2点衍生伤害，不递归'end
function handlers.musou(e)
    return '梦想一心次数取原值与'..number(e.n)..'的较大值，最多3次，持续2个结束阶段；'
        ..'普攻首命中＋3，实际直接扣血可为下回合增加1能量，每回合最多返能1次，刷新不重置计数'
end
function handlers.next_energy(e)return '下回合额外获得'..number(e.n)..'能量（各来源合计最多2，不是本回合）'end
function handlers.next_draw(e)return '下回合额外抽'..number(e.n)..'张牌（各来源合计最多2）'end
function handlers.next_block(e)return '下回合清除旧格挡后获得'..number(e.n)..'格挡（累计最多12，不二次受敏捷／脆弱修正）'end
function handlers.cleanse()return '清除自身虚弱与脆弱，仅此两项'end
function handlers.counter(e)
    return '反击取原值与'..number(e.n)..'的较大值，最多8；下次真实敌方攻击行动结束且自己存活时回击一次并清除，非攻击不触发，轮末清除'
end
function handlers.soften(e)
    return '削势增加'..number(e.n)..'，累计最多6；抵扣下次真实敌方攻击行动总伤害，多段依序抵扣，非攻击不消耗，轮末清除'
end
function handlers.when(e,ctx)
    local condition=lookup(conditions,e.condition,'条件')
    ctx.hasWhen=true
    -- Conditional spends cannot change the unconditional text context.
    return '若【'..condition..'】：'..renderEffects(e.effects,{resource=ctx.resource})
end
renderEffects=function(effects,ctx)
    assert(type(effects)=='table','缺少原创V4效果列表')
    local parts={}
    for _,effect in ipairs(effects) do
        assert(type(effect)=='table','无效原创V4效果')
        local handler=lookup(handlers,effect.op,'操作')
        parts[#parts+1]=handler(effect,ctx)
    end
    return table.concat(parts,'；')
end

-- Text derives from DSL, never from names or the optional handoff prose.
function M.describe(card,upgraded)
    local raw,definition=variant(card,upgraded)
    local parts={lookup(categories,raw.category,'类别')..'。'}
    local requirements={}
    for _,condition in ipairs(raw.requirements or {}) do
        requirements[#requirements+1]=lookup(conditions,condition,'前置条件')
    end
    if #requirements>0 then parts[#parts+1]='前提：'..table.concat(requirements,'且')..'。' end
    local context={}
    parts[#parts+1]=renderEffects(definition.effects,context)..'。'
    if context.hasWhen then parts[#parts+1]='效果条件均读取付血后、根消费前的同一快照。' end
    if definition.exhaust then parts[#parts+1]='消耗：仅本场离开循环，下场恢复，不从永久牌组删除。' end
    return table.concat(parts)
end

-- Static interaction only. The core adds conditional Hu Tao bloom targeting.
function M.target(card)
    local raw=rawCard(card)
    local enemy,all=false,false
    for _,condition in ipairs(raw.requirements or {}) do
        lookup(conditions,condition,'前置条件')
        if condition:match('_target$') or condition=='enemy_low' then enemy=true end
    end
    local function walk(effects)
        for _,e in ipairs(effects) do
            lookup(handlers,e.op,'操作')
            if e.target~=nil then
                targetText(e)
                if e.target=='one' then enemy=true else all=true end
            end
            if e.op=='eye_pulse' or e.op=='cash_bloom' and e.target==nil then enemy=true end
            if e.op=='when' then
                lookup(conditions,e.condition,'条件')
                if e.condition:match('_target$') or e.condition=='enemy_low' then enemy=true end
                walk(e.effects)
            end
        end
    end
    walk(assert(raw.base,'缺少原创V4基础牌面').effects)
    walk(assert(raw.upgrade,'缺少原创V4升级牌面').effects)
    return enemy and 'enemy' or all and 'all' or 'self'
end

local function count(value)
    return number(value or 0)
end
local function phase(label,value)
    value=value or {}
    return label..' '..count(value.uses)..'次／'..count(value.ends)..'阶段'
end
function M.summary(state)
    assert(type(state)=='table','缺少原创V4战斗状态')
    local v=state.originalV4
    if not v then return '' end
    local parts={lookup(roles,v.role,'角色')}
    if v.role=='HT' then
        parts[#parts+1]='蝶引 '..count(v.infuse)..'阶段；本回合重击 '..count(v.chargedUsed)..'/2'
    elseif v.role=='AR' then
        parts[#parts+1]='生命之契 '..count(v.bond)..'/8'
    elseif v.role=='FR' then
        parts[#parts+1]=lookup(modes,v.mode or 'ousia','形态')..'；气氛 '..count(v.fan)..'/12；本回合增长 '..count(v.fanGained)..'/4'
        local guests=v.guests or {}
        for _,id in ipairs({'usher','chevalmarin','crabaletta'}) do
            parts[#parts+1]=members[id]..' '..count(guests[id])..'次'..(v.mode=='pneuma' and '（暂停）' or '')
        end
        parts[#parts+1]='歌者 '..count(v.singer)..'次'..(v.mode~='pneuma' and '（暂停）' or '')
        parts[#parts+1]=phase('欢腾',v.revelry)..'；首命中＋'..count(v.revelry and v.revelry.bonus)
    elseif v.role=='RD' then
        parts[#parts+1]='愿力 '..count(v.resolve)..'/6；本回合增长 '..count(v.resolveGained)..'/2'
        parts[#parts+1]=phase('雷眼',v.eye)
        parts[#parts+1]=phase('梦想一心',v.musou)..'；本回合返能 '..count(v.musouRefunded)..'/1'
    end
    for i,enemy in ipairs(state.enemies or {}) do
        if (enemy.hp or 0)>0 and not enemy.escaped then
            local name=enemy.name or '敌人'..number(i)
            if enemy.v4Bloom then
                parts[#parts+1]=name..' 血梅香 强度'..count(enemy.v4Bloom.strength)..'／'..count(enemy.v4Bloom.ticks)..'次'
            end
            if enemy.v4Directive then parts[#parts+1]=name..' 勒令'..(enemy.v4Directive.mature and '已成熟' or '待成熟') end
        end
    end
    parts[#parts+1]='本战已治疗 '..count(v.healUsed)..'/12'
    parts[#parts+1]='下回合 能量＋'..count(v.nextEnergy)..'／抽牌＋'..count(v.nextDraw)..'／格挡＋'..count(v.nextBlock)
    if v.bonus and (v.bonus.n or 0)>0 then
        parts[#parts+1]='准备 '..lookup(tags,v.bonus.tag,'准备标签')..'首命中＋'..count(v.bonus.n)
    end
    if (v.counter or 0)>0 then parts[#parts+1]='反击 '..count(v.counter) end
    if (v.soften or 0)>0 then parts[#parts+1]='削势 '..count(v.soften) end
    return table.concat(parts,'\n')
end
-- Cards keep costs visible; the existing detail panel carries full rules.
function M.brief(card,upgraded,preview)
    M.describe(card,upgraded)
    local raw,value=variant(card,upgraded)
    local critical,actions={},{}
    local compact={bond='契量',fan='气氛',resolve='愿力'}
    for _,condition in ipairs(raw.requirements)do
        local resource,n=condition:match('^(%a+)(%d+)$')
        critical[#critical+1]='需'..assert(compact[resource])..n
    end
    local paid=0
    for _,effect in ipairs(value.effects)do
        if effect.op=='pay_hp'then paid=paid+effect.n
        elseif effect.op=='spend'then critical[#critical+1]=effect.n=='all' and ('耗尽'..compact[effect.resource]) or (compact[effect.resource]..'-'..effect.n)end
    end
    if paid>0 then critical[#critical+1]='付血'..number(paid)end
    if value.exhaust then critical[#critical+1]='本场消耗'end
    local seen={}
    local function add(text)if text and not seen[text]then actions[#actions+1]=text;seen[text]=true end end
    if preview and preview.originalV4 and #preview>0 then
        local damage,block=0,0
        for _,entry in ipairs(preview)do if entry.op=='block'then block=block+entry.low else damage=damage+(entry.actual or 0)end end
        if damage>0 then add('本次扣血'..number(damage))end
        if block>0 then add('本次格挡'..number(block))end
    end
    for _,e in ipairs(value.effects)do
        local op,n=e.op,e.n
        if op=='damage'then add((e.target=='all' and '全体伤害' or '伤害')..number(n)..((e.hits or 1)>1 and ('×'..e.hits) or ''))
        elseif op=='damage_spent'then add(e.coefficient==0 and ('伤害'..number(n)) or '消耗增伤')
        elseif op=='block' and n>0 then add('格挡'..number(n))
        elseif op=='heal'then add('治疗'..number(n))
        elseif op=='heal_spent'then add('消耗治疗')
        elseif op=='infuse'then add('蝶引'..number(n)..'阶段')
        elseif op=='summon'then add('部署宾客')
        elseif op=='singer'then add('歌者'..number(n)..'次')
        elseif op=='directive'then add('施加勒令')
        elseif op=='absorb'then add('吸收勒令')
        elseif op=='bloom'then add('血梅香'..number(n)..'层')
        elseif op=='cash_bloom'then add('兑现血梅香')
        elseif op=='eye'then add('雷眼'..number(n)..'次')
        elseif op=='musou'then add('一心'..number(n)..'次')
        elseif op=='revelry'then add('欢腾'..number(n)..'批')
        elseif op=='mode' or op=='toggle'then add('切换荒芒')
        elseif op=='draw'then add('抽牌'..number(n))
        elseif op=='next_energy'then add('下回合能量+'..number(n))
        elseif op=='next_draw'then add('下回合抽牌+'..number(n))
        elseif op=='next_block'then add('下回合格挡'..number(n))
        elseif op=='bonus'then add('准备加成'..number(n))
        elseif op=='mature'then add('勒令成熟')
        elseif op=='cleanse'then add('净化虚弱脆弱')
        elseif op=='trigger'then add('召唤物行动')
        elseif op=='eye_pulse'then add('雷眼追击')
        elseif op=='block_spent'then add('消耗护盾')
        elseif op=='end_infuse'then add('结束蝶引')
        elseif op=='when'then add('附条件效果')
        elseif op=='soften'then add('削势'..number(n))
        elseif op=='counter'then add('反击'..number(n))
        elseif op=='resolve'then add('愿力+'..number(n))
        end
    end
    assert(#critical<=4,'original card costs exceed readable brief')
    for _,text in ipairs(actions)do if #critical>=4 then break end;critical[#critical+1]=text end
    critical[#critical+1]='长按查看全文'
    return table.concat(critical,'\n')
end
return M
