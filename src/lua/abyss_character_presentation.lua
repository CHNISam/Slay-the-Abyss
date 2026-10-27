-- Detached development display adaptation; rules remain owned by Combat.
local M={}
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
local fragments=require('abyss_character_presentation_text').fragments

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
    local nativeBundle=prepared.originalV4Role or not prepared.runCardCatalog and not prepared.experimentalCharacter and prepared.cards.sourcePools~=nil
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
        elseif current and not card.colorlessNative and nativeBundle then
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
        if nativeBundle and not card.originalV4 then
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
