-- Source-verified Watcher card data and pure action plans. Combat owns execution.
local M={}
local MAX=2147483647
local function copy(t)
    if type(t)~="table" then return t end
    local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function integer(n) return type(n)=="number" and n==n and n%1==0 and n>=0 and n<=MAX end
local function checked(n) assert(integer(n),"invalid Watcher attack amount");return n end
local function damage(n) return {op="damage",value=n} end
local function block(n) return {op="block",value=n} end
local function previous(kind,effect) return {op="previousCardType",cardType=kind,effect=effect} end
local function generated(id,pile)
    return {op="makeTempCard",cardId=id,pile=pile,value=1,upgraded=false,randomSpot=pile=="draw" or nil}
end
local specs={
    {"consecrate","Consecrate","Consecrate","奉献","attack","common",0,{{op="damageAll",value=5}},{{op="damageAll",value=8}}},
    {"bowling_bash","BowlingBash","Bowling Bash","保龄猛击","attack","common",1,{{op="bowlingBash",value=7}},{{op="bowlingBash",value=10}}},
    {"flying_sleeves","FlyingSleeves","Flying Sleeves","飞袖","attack","common",1,{{op="damage",value=4,times=2}},{{op="damage",value=6,times=2}}},
    {"follow_up","FollowUp","Follow-Up","追击","attack","common",1,{damage(7),previous("attack",{op="energy",value=1})},{damage(11),previous("attack",{op="energy",value=1})}},
    {"crush_joints","CrushJoints","Crush Joints","碎关节","attack","common",1,{damage(8),previous("skill",{op="applyStatus",status="vulnerable",value=1})},{damage(10),previous("skill",{op="applyStatus",status="vulnerable",value=2})}},
    {"sash_whip","SashWhip","Sash Whip","绸带抽打","attack","common",1,{damage(8),previous("attack",{op="applyStatus",status="weak",value=1})},{damage(10),previous("attack",{op="applyStatus",status="weak",value=2})}},
    {"empty_mind","EmptyMind","Empty Mind","净空","skill","uncommon",1,{{op="draw",value=2},{op="changeStance",stance="Neutral"}},{{op="draw",value=3},{op="changeStance",stance="Neutral"}}},
    {"evaluate","Evaluate","Evaluate","评估","skill","common",1,{block(6),generated("insight","draw")},{block(10),generated("insight","draw")}},
    {"halt","Halt","Halt","止步","skill","common",0,{{op="halt",value=3,wrathValue=9}},{{op="halt",value=4,wrathValue=14}}},
    {"carve_reality","CarveReality","Carve Reality","雕琢现实","attack","uncommon",1,{damage(6),generated("smite","hand")},{damage(10),generated("smite","hand")}},
    {"deceive_reality","DeceiveReality","Deceive Reality","欺瞒现实","skill","uncommon",1,{block(4),generated("safety","hand")},{block(7),generated("safety","hand")}},
    {"sanctity","Sanctity","Sanctity","圣洁","skill","uncommon",1,{block(6),previous("skill",{op="draw",value=2})},{block(9),previous("skill",{op="draw",value=2})}},
    {"signature_move","SignatureMove","Signature Move","招牌技","attack","uncommon",2,{damage(30)},{damage(40)}},
    {"scrawl","Scrawl","Scrawl","潦草急就","skill","rare",1,{{op="drawToHandSize",value=10}},nil},
    {"brilliance","Brilliance","Brilliance","光辉","attack","rare",1,{damage(12)},{damage(16)}},
    {"insight","Insight","Insight","洞见","skill","special",0,{{op="draw",value=2}},{{op="draw",value=3}}},
    {"safety","Safety","Safety","安全","skill","special",1,{block(12)},{block(16)}},
    {"smite","Smite","Smite","惩罚","attack","special",1,{damage(12)},{damage(16)}},
}
local descriptions={
    consecrate={"对所有敌人造成5点伤害。","对所有敌人造成8点伤害。"},
    bowling_bash={"每有一名存活的敌人，对目标造成一次7点伤害。","每有一名存活的敌人，对目标造成一次10点伤害。"},
    flying_sleeves={"保留。造成4点伤害两次。","保留。造成6点伤害两次。"},
    follow_up={"造成7点伤害。若本场战斗上一张打出的牌是攻击，获得1点能量。","造成11点伤害。若本场战斗上一张打出的牌是攻击，获得1点能量。"},
    crush_joints={"造成8点伤害。若上一张打出的牌是技能，施加1层易伤。","造成10点伤害。若上一张打出的牌是技能，施加2层易伤。"},
    sash_whip={"造成8点伤害。若上一张打出的牌是攻击，施加1层虚弱。","造成10点伤害。若上一张打出的牌是攻击，施加2层虚弱。"},
    empty_mind={"抽2张牌。退出当前姿态。","抽3张牌。退出当前姿态。"},
    evaluate={"获得6点格挡。将一张未升级的洞见随机放入抽牌堆。","获得10点格挡。将一张未升级的洞见随机放入抽牌堆。"},
    halt={"获得3点格挡。若处于愤怒，额外获得9点格挡。两部分分别受敏捷和脆弱影响。","获得4点格挡。若处于愤怒，额外获得14点格挡。两部分分别受敏捷和脆弱影响。"},
    carve_reality={"造成6点伤害。将一张惩罚加入手牌。","造成10点伤害。将一张惩罚加入手牌。"},
    deceive_reality={"获得4点格挡。将一张安全加入手牌。","获得7点格挡。将一张安全加入手牌。"},
    sanctity={"获得6点格挡。若上一张打出的牌是技能，抽2张牌。","获得9点格挡。若上一张打出的牌是技能，抽2张牌。"},
    signature_move={"仅当手牌中没有其他攻击牌时可用。造成30点伤害。","仅当手牌中没有其他攻击牌时可用。造成40点伤害。"},
    scrawl={"抽牌直到手牌有10张。消耗。","抽牌直到手牌有10张。消耗。"},
    brilliance={"造成12点伤害。本场战斗每获得1点真言，基础伤害增加1。","造成16点伤害。本场战斗每获得1点真言，基础伤害增加1。"},
    insight={"保留。抽2张牌。消耗。","保留。抽3张牌。消耗。"},
    safety={"保留。获得12点格挡。消耗。","保留。获得16点格挡。消耗。"},
    smite={"保留。造成12点伤害。消耗。","保留。造成16点伤害。消耗。"},
}
function M.withCards(data)
    assert(type(data)=="table" and data.cards and type(data.cards.cards)=="table","missing Watcher attack data")
    local out=copy(data);local seen={}
    for _,c in ipairs(out.cards.cards) do assert(not seen[c.id],"duplicate input card");seen[c.id]=true end
    for _,s in ipairs(specs) do
        assert(not seen[s[1]],"Watcher attack card already exists: "..s[1])
        local c={id=s[1],sourceId=s[2],sts_name=s[3],name=s[4],type=s[5],rarity=s[6],cost=s[7],
            color=s[6]=="special" and "colorless" or "purple",effects=copy(s[8]),upgrade={effects=copy(s[9] or s[8])},
            text=descriptions[s[1]][1],upgradeText=descriptions[s[1]][2]}
        if c.id=="flying_sleeves" or c.rarity=="special" then c.selfRetain=true end
        if c.rarity=="special" or c.id=="scrawl" then c.exhaust=true end
        if c.id=="scrawl" then c.upgrade.cost=0 end
        if c.id=="signature_move" then c.requiresNoOtherAttack=true end
        if c.id=="empty_mind" then c.sourceTags={"EMPTY"} end
        out.cards.cards[#out.cards.cards+1]=c
    end
    return out
end

-- Call after upgrade, before Strength/Weak/stance/target damage modifiers.
function M.adaptDefinition(state,instance,definition)
    if instance.cardId~="brilliance" then return definition end
    local out=copy(definition);local n=checked(state.mantraGained or 0)
    assert(#out.effects==1 and out.effects[1].op=="damage","unsupported Brilliance effect modification")
    out.effects[1].value=checked(out.effects[1].value+0.0+n)
    return out
end

-- Construction-time snapshots. Returned effects are independent pure data.
-- Host must expand Bowling Bash here, not recount after its first damage.
function M.prepareEffect(state,effect)
    local out=copy(effect)
    if effect.op=="bowlingBash" then
        checked(effect.value);local effects={}
        for _,enemy in ipairs(assert(state.enemies)) do
            if enemy.hp>0 and not enemy.escaped and not enemy.isDying and not enemy.halfDead and not enemy.isEscaping then effects[#effects+1]=damage(effect.value) end
        end
        return effects
    elseif effect.op=="halt" then
        checked(effect.value);checked(effect.wrathValue)
        local Actors=require("abyss_actor")
        out.value=checked(Actors.blockAmount(state,state.player,effect.value))
        out.wrathValue=checked(Actors.blockAmount(state,state.player,effect.wrathValue))
        out.prepared=true
    end
    return {out}
end

-- Execution-time TOP actions, in execution order; the host pushes in reverse.
-- History includes the current card and persists across turns.
function M.planEffect(state,effect)
    local effects={}
    if effect.op=="previousCardType" then
        assert(effect.cardType=="attack" or effect.cardType=="skill","unsupported previous card type")
        local e=effect.effect
        assert(type(e)=="table" and (e.op=="draw" or e.op=="energy" or e.op=="applyStatus"),"unsupported previous card action")
        checked(e.value)
        if e.op=="applyStatus" then assert(e.status=="weak" or e.status=="vulnerable","unsupported previous card status") end
        local history=assert(state.cardsPlayedThisCombat,"missing combat card history")
        local prev=history[#history-1]
        if prev and prev.type==effect.cardType then effects[1]=copy(e) end
    elseif effect.op=="halt" then
        assert(effect.prepared==true,"unprepared Halt")
        local n=checked(effect.value)
        if state.player.stance=="Wrath" then n=checked(n+0.0+checked(effect.wrathValue)) end
        effects[1]={op="block",value=n,fixed=true}
    elseif effect.op=="drawToHandSize" then
        assert(effect.value==10,"unsupported hand-size draw")
        if #state.hand<10 then effects[1]={op="draw",value=10-#state.hand} end
    else error("unsupported Watcher action plan: "..tostring(effect.op)) end
    local actions={};for _,e in ipairs(effects) do actions[#actions+1]={kind="effect",effect=e} end;return actions
end

function M.canUse(state,instance,definition)
    if not definition.requiresNoOtherAttack then return true end
    assert(instance.cardId=="signature_move","unsupported attack-hand restriction")
    for _,other in ipairs(state.hand) do
        if other.uid~=instance.uid then
            local c=assert(state.catalog.cards[other.cardId],"unknown hand card")
            if c.type=="attack" then return false,"requires_no_other_attack" end
        end
    end
    return true
end
return M
