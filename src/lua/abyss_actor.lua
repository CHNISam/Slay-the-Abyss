-- Actor arithmetic and turn status rules; no UI or platform globals.
local M = {}
local Events = require("abyss_events")
local Act2Powers = require('abyss_act2_powers')
local Act3Powers = require('abyss_act3_powers')

-- Require lazily: card actions use Actor arithmetic, and hooks only enqueue
-- data. Combat owns draining, choices, death interruption and transactionality.
local function enqueue(state,e,source,top)
    require("abyss_card_actions").enqueue(state,e,source,nil,nil,top)
end
-- Equal-priority original Powers are stably sorted: their hooks retain the
-- order of first application. Legacy raw-status fixtures get an explicit order.
function M.powerSequence(actor,ids)
    local allowed,seen,result={},{},{}
    for _,id in ipairs(ids) do allowed[id]=true end
    for _,id in ipairs(actor.powerOrder or {}) do
        if allowed[id] and (actor.statuses[id] or 0)~=0 and not seen[id] then
            result[#result+1]=id;seen[id]=true
        end
    end
    for _,id in ipairs(ids) do if not seen[id] and (actor.statuses[id] or 0)~=0 then result[#result+1]=id end end
    return result
end
local function notifyHpLost(state,owner,actor,amount)
    if actor~=state.player or amount<=0 then return end
    -- The 238 notifier owns the single damagedThisCombat increment, actual
    -- Blood for Blood costs and provenance-sensitive Rupture trigger.
    require('abyss_hp_loss').notify(state,owner,actor,amount)
    -- Preserve the upstream 75-card instance ABI as a compatibility mirror.
    -- Combat prefers combatCost/turnCost and must not subtract this a second time.
    for _,pile in ipairs({state.hand,state.draw,state.discard}) do
        for _,card in ipairs(pile) do
            if card.cardId=="blood_for_blood" then card.costReduction=(card.costReduction or 0)+1 end
        end
    end
end
function M.hpLostFromCard(state,actor,amount) notifyHpLost(state,actor,actor,amount) end
function M.hpLostFromDamage(state,actor,amount) notifyHpLost(state,nil,actor,amount) end

function M.isActive(actor) return actor ~= nil and actor.hp > 0 and not actor.escaped end

function M.status(state, actor, id, amount, source, sourceIsMonster)
    local beforeRaw=rawget(actor.statuses,id)
    local powerOrderModule=require('abyss_power_order')
    if powerOrderModule.ids[id] then powerOrderModule.before(state,actor) end
    local before = actor.statuses[id] or 0
    M.addStatus(actor, id, amount)
    if before==0 or actor.statuses[id]==0 then
        local order={}
        for _,old in ipairs(actor.powerOrder or {}) do if old~=id then order[#order+1]=old end end
        if actor.statuses[id]~=0 then order[#order+1]=id end
        actor.powerOrder=order
    end
    powerOrderModule.applied(state,actor,id,beforeRaw)
    if before <= 0 and actor.statuses[id] > 0
        and actor.statusDefinitions[id].decay == "round_end_minus_1" then
        local monster = sourceIsMonster
        if monster == nil then monster = source ~= nil and source ~= state.player end
        actor[id .. "JustApplied"] = monster and (id ~= "vulnerable" or state.phase == "enemy") or nil
    end
    local sourceId = (source or actor).id
    if source == nil and sourceIsMonster ~= nil then sourceId = nil end
    Events.emit(state, "status", {source = sourceId, target = actor.id,
        status = id, amount = actor.statuses[id] - before})
end

local stacks = { intensity = true, duration = true, none = true }
local decays = { none = true, turn_end_minus_1 = true, round_end_minus_1 = true,
    turn_start_trigger_then_minus_1 = true, turn_end_trigger_then_minus_1 = true }
local signed = { strength = true, dexterity = true, focus = true }

local function integer(amount)
    return type(amount) == "number" and amount == amount and amount % 1 == 0
        and amount >= -2147483647 and amount <= 2147483647
end

-- Only source-verified ApplyPower categories; raw status mutation stays separate.
local debuffs = { corpse_explosion=true,wraith_form=true,no_block=true, bias=true, weak=true, vulnerable=true, frail=true, poison=true, entangled=true,
    shackled=true,choked=true,block_return=true,mark=true,energy_down=true,hex=true,confusion=true }
local function blockDebuff(state, actor, id)
    local before = actor.statuses.artifact or 0
    if before <= 0 then return false end
    actor.statuses.artifact = before - 1
    Events.emit(state, "status", {source=actor.id, target=actor.id, status="artifact",
        amount=-1, blockedStatus=id})
    return true
end

-- Shared Artifact event path for specialized Power lifecycle implementations.
function M.tryBlockDebuff(state, actor, id)
    if not M.isActive(actor) then return false end
    return blockDebuff(state, actor, id)
end

-- Pure prediction for an already validated application. Artifact's gate occurs
-- before stackPower, so a blocked application has no prospective stack overflow.
function M.artifactBlocksPower(actor, id, amount)
    return M.isActive(actor) and (actor.statuses.artifact or 0) > 0
        and (debuffs[id] == true or (signed[id] == true and amount <= 0)) or false
end

function M.applyPower(state, actor, id, amount, source, sourceIsMonster)
    if id == "focus" then return require("abyss_focus").apply(state, actor, amount, source) end
    if not M.isActive(actor) then return false end -- ApplyPower cancels for a dead target.
    assert(actor.statusDefinitions and actor.statusDefinitions[id], "unknown status: " .. tostring(id))
    assert(integer(amount) and (signed[id] or id=='wraith_form' or amount >= 0), "invalid status amount")
    -- Strength/Dexterity's incoming Power has DEBUFF type at amount <= 0,
    -- regardless of the target's existing signed total. Zero is not an early exit.
    if M.artifactBlocksPower(actor, id, amount) then blockDebuff(state, actor, id); return false end
    M.status(state, actor, id, amount, source, sourceIsMonster)
    require('abyss_colorless_cards').debuffApplied(state,actor,id,amount,source)
    if actor==state.player and (id=='demon_form' or id=='brutality' or id=='devotion' or id=='noxious_fumes') then
        state.postDrawPowerOrder=state.postDrawPowerOrder or {}
        local found=false
        for _,key in ipairs(state.postDrawPowerOrder) do if key==id then found=true end end
        if not found then state.postDrawPowerOrder[#state.postDrawPowerOrder+1]=id end
    end
    return true
end

function M.applyNoDraw(state, actor)
    -- ApplyPowerAction's duplicate NoDraw gate precedes Artifact's generic gate.
    if not M.isActive(actor) or actor.noDraw then return false end
    if blockDebuff(state, actor, "no_draw") then return false end
    actor.noDraw = true
    return true
end

function M.bindStatuses(actor, definitions)
    assert(type(definitions) == "table", "missing status definitions")
    for id, definition in pairs(definitions) do
        assert(definition.id == id and stacks[definition.stack] and decays[definition.decay], "invalid status definition")
        if definition.decay:find("trigger", 1, true) then
            assert(id == "poison" or id == "regen", "unknown status trigger")
        end
    end
    actor.statusDefinitions = definitions
end

function M.addStatus(actor, id, amount)
    local definition = assert(actor.statusDefinitions and actor.statusDefinitions[id], "unknown status: " .. tostring(id))
    assert(integer(amount) and (signed[id] or id=='wraith_form' or amount >= 0), "invalid status amount")
    local before = actor.statuses[id] or 0
    local value = before + 0.0 + amount
    assert(integer(value), "status stack overflow") -- reject before mutating
    -- Strength/Dexterity clamp after stacking, for either actor and either sign.
    if signed[id] then value = math.max(-999, math.min(999, value)) end
    if id == 'plated_armor' and before > 0 then value = math.min(999, value) end
    if definition.stack == "none" then value = value > 0 and 1 or 0 end
    actor.statuses[id] = (signed[id] or id=='wraith_form') and value or math.max(0, value)
    if (actor.statuses[id] == 0 or before <= 0) and definition.decay == "round_end_minus_1" then
        actor[id .. "JustApplied"] = nil
    end
    return actor.statuses[id]
end

local temporaryFields = { strength="temporaryStrength", dexterity="temporaryDexterity" }
local function rememberTemporaryOrder(actor, id)
    -- Equal-priority LoseStrength/LoseDexterity retain first insertion order.
    -- Replace the array so detached presentation frames never change later.
    local order = {}
    for _, prior in ipairs(actor.temporaryPowerOrder or {}) do order[#order+1] = prior end
    if not actor.temporaryPowerOrder then
        -- Old/raw Strength bookkeeping predates the second supported loss Power.
        for _, prior in ipairs({"strength", "dexterity"}) do
            if (actor[temporaryFields[prior]] or 0) > 0 then order[#order+1] = prior end
        end
    end
    for _, prior in ipairs(order) do
        if prior == id then actor.temporaryPowerOrder = order; return end
    end
    order[#order+1] = id
    actor.temporaryPowerOrder = order
    local powers = {}
    for _,prior in ipairs(actor.powerOrder or {}) do if prior ~= 'lose_'..id then powers[#powers+1]=prior end end
    powers[#powers+1]='lose_'..id
    actor.powerOrder=powers
end

local function addTemporaryStat(actor, id, amount, state)
    assert(integer(amount) and amount >= 0, "invalid temporary " .. id)
    assert(not state or amount > 0, "zero temporary " .. (id == "strength" and "Strength" or "Dexterity") .. " application unsupported")
    if state and not M.isActive(actor) then return false end
    local field = temporaryFields[id]
    local total = (actor[field] or 0) + 0.0 + amount
    -- Positive Strength/Dexterity cannot spend Artifact. If its loss is blocked,
    -- its old debt is never stacked and must not fail a nonexistent addition.
    local blockedLoss = state and (actor.statuses.artifact or 0) > 0
    if not blockedLoss then assert(integer(total), "temporary " .. id .. " overflow") end
    if state then
        -- Flex/Speed queue the gain then a separate timed-loss DEBUFF. Artifact
        -- can block that latter application while preserving the positive stat.
        M.applyPower(state, actor, id, amount, actor)
        if not blockDebuff(state, actor, "lose_" .. id) then
            rememberTemporaryOrder(actor, id)
            actor[field] = total
            state.events[#state.events].frame = Events.frame(state)
        end
    else
        -- Public two-argument helper is raw setup/bookkeeping, not ApplyPower.
        M.addStatus(actor, id, amount)
        if amount > 0 then rememberTemporaryOrder(actor, id) end
        actor[field] = total
    end
end

function M.addTemporaryStrength(actor, amount, state)
    return addTemporaryStat(actor, "strength", amount, state)
end

function M.addTemporaryDexterity(actor, amount, state)
    return addTemporaryStat(actor, "dexterity", amount, state)
end

-- UI receives values, never references to the combat state or definitions.
function M.statusView(actor)
    local ids, result = {}, {}
    for id, amount in pairs(actor.statuses) do
        -- At exactly zero net stat, the separate timed-loss Power still exists.
        if amount ~= 0 or id == "focus" or temporaryFields[id] and (actor[temporaryFields[id]] or 0) > 0 then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local definition = assert(actor.statusDefinitions[id], "unknown active status")
        result[#result + 1] = { id = id, amount = actor.statuses[id], name = definition.name,
            icon=require('abyss_colorless_cards').powerIcon(id),
            kind = id == "focus" and (actor.statuses[id] > 0 and "buff" or "debuff") or definition.kind, stack = definition.stack, decay = definition.decay,
            description = require('abyss_silent_final_cards').powerDescription(actor,id)or require('abyss_colorless_cards').powerDescription(actor,id) or definition.description,
            temporary = temporaryFields[id] and (actor[temporaryFields[id]] or 0) or 0 }
    end
    local function resource(id,name,amount,description,icon,duration,kind)
        result[#result+1]={id='original_v4_'..id,name=name,amount=amount,description=description,icon=icon or 'strength',
            kind=kind or 'buff',stack='intensity',decay='none',temporary=0,originalV4=true,duration=duration or '本场战斗'}
    end
    local v=actor.originalV4
    if v then
        if v.role=='HT' and v.infuse>0 then resource('infuse','蝶引',v.infuse,'剩余结束阶段；本回合已强化重击 '..v.chargedUsed..'/2。','strength','剩余 '..v.infuse..' 个结束阶段')
        elseif v.role=='AR' then resource('bond','生命之契',v.bond,'契量最多8；不随等待减少。','strength')
        elseif v.role=='FR' then
            resource('mode',v.mode=='ousia' and '荒性' or '芒性',1,v.mode=='ousia' and '只有宾客行动，歌者暂停。' or '只有歌者行动，宾客暂停。','regen')
            resource('fan','气氛',v.fan,'本回合已增长 '..v.fanGained..'/4；气氛最多12。','strength')
        elseif v.role=='RD' then
            resource('resolve','愿力',v.resolve,'本回合已增长 '..v.resolveGained..'/2；愿力最多6。','strength')
            if v.eye.uses>0 and v.eye.ends>0 then resource('eye','雷眼',v.eye.uses,'剩余次数；普通主动伤害实际扣血后追击。','thorns','剩余 '..v.eye.ends..' 个结束阶段')end
            if v.musou.uses>0 and v.musou.ends>0 then resource('musou','一心',v.musou.uses,'剩余强化普攻次数；本回合返能 '..v.musouRefunded..'/1。','strength','剩余 '..v.musou.ends..' 个结束阶段')end
        end
        resource('healing','治疗余量',(v.healCap or 12)-v.healUsed,'本战已实际治疗 '..v.healUsed..'/'..(v.healCap or 12)..'；切换和重召不会重置。','regen')
    end
    if actor.v4Bloom then resource('bloom','血梅香',actor.v4Bloom.strength,'每次造成强度×2固定伤害。','poison','剩余 '..actor.v4Bloom.ticks..' 次','debuff')end
    if actor.v4Directive then resource('directive',actor.v4Directive.mature and '成熟勒令' or '勒令',1,
        actor.v4Directive.mature and '吸收获得6契；死亡回收4契。' or '下次己方回合开始成熟；当前吸收获得2契。','vulnerable','被吸收或死亡时清除','debuff')end
    return result
end

-- Death powers join the current damage action's TOP reactions. They must not
-- run inside an area target loop, or survive that action killing the final foe.
local function battleEnding(state)
    if state.phase == "victory" or state.phase == "defeat" then return true end
    for _, enemy in ipairs(state.enemies) do if M.isActive(enemy) then return false end end
    return true
end

local function queueDeathPower(state, target, before, reactions)
    require('abyss_silent_final_cards').death(state,target,before)
    if before>0 and target.hp<=0 and not target.escaped then Act2Powers.died(state,target) end
    if before > 0 and target.hp <= 0 and not target.escaped and target.ai and target.ai.kind == "looter"
        and not target.stolenGoldRewarded then
        local stolen = target.stolenGold or 0
        local total = (state.stolenGoldReward or 0) + 0.0 + stolen
        assert(integer(stolen) and stolen >= 0 and integer(total), "stolen gold overflow")
        state.stolenGoldReward, target.stolenGoldRewarded = total, true
    end
    local amount = target.statuses.spore_cloud or 0
    if before > 0 and target.hp <= 0 and target ~= state.player and amount > 0 and not battleEnding(state) then
        -- ApplyPower's source is null, independently of Vulnerable's explicit
        -- monster-origin flag used for its first enemy-round decay suppression.
        reactions[#reactions + 1] = {target=state.player, status="vulnerable", amount=amount,
            sourceIsMonster=true}
    end
end

function M.resolveDamageReactions(state, reactions, retaliate)
    for i = #reactions, 1, -1 do
        local hit = reactions[i]
        if hit.effect and hit.effect.op=='defenseBlock' then
            if M.isActive(state.player) then M.block(state,state.player,hit.effect.value,true) end
        elseif hit.effect and hit.effect.op=='cardTriggerPoison' then
            require('abyss_card_triggers').resolveEnvenom(state,hit.effect)
          elseif hit.effect and hit.effect.op=='defectStatic'then
              require('abyss_defect_final_cards').static(state,hit.effect.value)
        elseif hit.status then
            if not battleEnding(state) then
                M.applyPower(state, hit.target, hit.status, hit.amount, hit.source, hit.sourceIsMonster)
            end
        else
            -- DAMAGE survives final-kill cleanup; recursive death reactions
            -- belong above the remaining actions in this local batch.
            (retaliate or M.retaliate)(state, hit.source, hit.target, hit.amount)
        end
    end
end

local function directDamage(state, source, target, amount, status, blocked, reactions)
    if (target.statuses.intangible or 0)>0 then amount=math.min(amount,1) end
    amount=require('abyss_defect_final_cards').incoming(state,target,amount)
    local before = target.hp
    local lost = math.min(target.hp, amount)
    target.hp = target.hp - lost
    local damageOwner=source
    if status=='poison' then damageOwner=nil end
    notifyHpLost(state,damageOwner,target,lost)
    Events.emit(state, status=='hp_loss'and 'hp_loss'or "status_damage", {
        source = source and source.id, target = target.id, status = status, amount = lost, blocked = blocked or 0 })
    require('abyss_relic_hooks').hpChanged(state,target,before)
    if state.originalV4 then require('abyss_original_v4').enemyDied(state,target,before) end
    queueDeathPower(state, target, before, reactions)
    return lost
end

function M.loseHp(state,target,amount)
    if not M.isActive(target)then return 0 end
    if (target.statuses.intangible or 0)>0 then amount=math.min(amount,1)end
    local reactions={};local lost=directDamage(state,nil,target,amount,'hp_loss',0,reactions)
    M.resolveDamageReactions(state,reactions)
    return lost
end

-- Judgement's InstantKill sets HP to zero before a null-source HP_LOSS(0).
-- It ignores block and damage modifiers, but still owns the death callback.
function M.instantKill(state,target)
    local before=target.hp
    target.hp=0
    Events.emit(state,'damage',{target=target.id,amount=0,blocked=0})
    require('abyss_relic_hooks').hpChanged(state,target,before)
    local reactions={};queueDeathPower(state,target,before,reactions)
    M.resolveDamageReactions(state,reactions)
end

function M.attackAmount(state, source, target, base, fixed)
    -- Force float arithmetic before modifiers: Fengari integers are 32-bit,
    -- while game Lua uses wider integers. Integer multiplication would wrap.
    local amount = base + 0.0
    if not fixed then
        amount = amount + (source.statuses.strength or 0)
        amount = amount + (source.statuses.vigor or 0)
        if (source.statuses.double_damage or 0)>0 then amount=amount*2 end
        if (source.statuses.pen_nib or 0)>0 then amount=amount*2.0 end
        if (source.statuses.weak or 0) > 0 then amount = amount * state.rules.combat.weakPercent / 100 end
        if (target.statuses.vulnerable or 0) > 0 then amount = amount * state.rules.combat.vulnerablePercent / 100 end
    end
    if state.player.stance and source then
        amount = amount * require("abyss_stances").damageMultiplier(state, source, target, fixed)
    end
    if not fixed and (target.statuses.flight or 0)>0 then amount=amount/2 end
    if (target.statuses.intangible or 0)>0 then amount=math.min(amount,1) end
    return math.max(0, math.floor(amount))
end

-- An area attack collects retaliation until all of its targets are damaged.
-- A dead attacker may still own a queued Thorns hit; dead victims cannot lose HP.
function M.retaliate(state, source, target, amount)
    if not M.isActive(target) then return 0 end
    if (target.statuses.intangible or 0)>0 then amount=math.min(amount,1) end
    local blocked = math.min(target.block, amount)
    target.block = target.block - blocked
    local reactions = {}
    local lost = directDamage(state, source, target, amount - blocked, "thorns", blocked, reactions)
    M.resolveDamageReactions(state, reactions)
    return lost
end

function M.damage(state, source, target, base, fixed, retaliation, normalAmount, attackReaction)
    if not M.isActive(target) or source ~= nil and not M.isActive(source) then return 0 end
    local before, reactions = target.hp, retaliation or {}
    -- Owner.onAttack enqueues before the target's onAttacked reactions. Keep
    -- the shared area batch in that order, so reverse TOP draining can
    -- interleave a later target's poison with an earlier target's Thorns.
    if attackReaction then reactions[#reactions+1]=attackReaction end
    local amount
    if normalAmount ~= nil then
        -- Modifier results can exceed the signed32 base/status bounds. Keep
        -- the snapshot exact in binary64 without accepting non-finite values.
        assert(not fixed and type(normalAmount)=='number' and normalAmount==normalAmount
            and normalAmount>=0 and normalAmount<=9007199254740991 and normalAmount%1==0,
            "invalid normal damage snapshot")
        amount = normalAmount
    else amount = M.attackAmount(state, source, target, base, fixed) end
    if (target.statuses.intangible or 0)>0 then amount=math.min(amount,1) end
    local absorbed = math.min(target.block, amount)
    target.block = target.block - absorbed
    local unblocked=amount-absorbed
    if source==state.player and not fixed and unblocked>0 and unblocked<5 then
        for _,id in ipairs(state.relics or {})do if id=='boot' or id=='Boot'then unblocked=5;break end end
    end
      unblocked=require('abyss_defect_final_cards').incoming(state,target,unblocked)
    local lost = math.min(target.hp, unblocked)
    Act2Powers.damaged(state,source,target,lost,fixed)
    target.hp = target.hp - lost
    notifyHpLost(state,source,target,lost)
    Events.emit(state, "damage", { source = source and source.id, target = target.id, amount = lost, blocked = absorbed })
    if not fixed and source and source ~= target and lost > 0 and (target.statuses.plated_armor or 0) > 0 then
        target.statuses.plated_armor = target.statuses.plated_armor - 1
        if target.statuses.plated_armor==0 then
            require('abyss_power_schedule').remove(state,target,'plated_armor')
            target.statuses.plated_armor=nil
        end
        Events.emit(state, 'status', {source=target.id,target=target.id,status='plated_armor',amount=-1})
    end
    require('abyss_relic_hooks').hpChanged(state,target,before)
    -- Curl Up locks on the first nonlethal NORMAL hit, but its actions go to
    -- the BOTTOM, behind every already-queued hit/effect and card disposal.
    -- Keep this FIFO separate from Angry/Thorns/Spore's reverse TOP reactions.
    local curl = target.statuses.curl_up or 0
    if source and target ~= state.player and not fixed and lost > 0 and target.hp > 0
        and curl > 0 and not target.curlUpTriggered then
        target.curlUpTriggered = true
        state.curlUpQueue = state.curlUpQueue or {}
        state.curlUpQueue[#state.curlUpQueue + 1] = {target=target, amount=curl}
    end
    -- Angry is a queued positive Strength Power after an unblocked NORMAL hit.
    -- Fixed inventory damage, poison and retaliation use non-NORMAL paths.
    -- For an area action, all targets take damage before top-of-queue reactions.
    local angry = source and not fixed and lost > 0 and (target.statuses.angry or 0) or 0
    if angry > 0 then
        reactions[#reactions + 1] = { source = target, target = target, amount = angry, status = "strength" }
    end
    -- Thorns consumes block, but has no attack modifiers or recursive retaliation.
    -- Being attacked triggers Thorns, even at zero damage, fully blocked or lethal.
    if not fixed and source then
          for _,id in ipairs(M.powerSequence(target,{'thorns','flame_barrier','block_return','static_discharge'})) do
            -- Each Power adds its own TOP DamageAction. Combining them would
            -- erase two distinct damage callbacks and reverse application order.
            if (target.statuses[id] or 0)>0 then
                  if id=='static_discharge'then
                      if target==state.player and source~=target and lost>0 then reactions[#reactions+1]={effect={op='defectStatic',value=target.statuses[id]}}end
                  elseif id=='block_return' then
                    if source~=target then reactions[#reactions+1]={effect={op='defenseBlock',value=target.statuses[id]}} end
                elseif id=='thorns' or source~=target then
                    reactions[#reactions+1]={source=target,target=source,amount=target.statuses[id]}
                end
            end
        end
    end
    -- onDeath queues after onAttacked, so its TOP Power resolves before Thorns.
    queueDeathPower(state, target, before, reactions)
    if not retaliation then M.resolveDamageReactions(state, reactions) end
    return lost
end

function M.blockFloat(state, actor, amount, fixed)
    if not fixed and (actor.statuses.no_block or 0)>0 then return 0 end
    amount = amount + 0.0
    if not fixed then
        amount = amount + (actor.statuses.dexterity or 0)
        if (actor.statuses.frail or 0) > 0 then amount = amount * state.rules.combat.frailPercent / 100 end
    end
    return math.max(0,amount)
end
function M.blockAmount(state, actor, amount, fixed)
    return math.floor(M.blockFloat(state,actor,amount,fixed))
end

function M.block(state, actor, amount, fixed,callbackAmount)
    local before = actor.block
    -- Cap the final state, not the modifier calculation or its float precision.
    local gained=M.blockAmount(state, actor, amount, fixed)
    actor.block = math.min(999, actor.block + 0.0 + gained)
    if actor==state.player then require('abyss_watcher_final_cards').gainedBlock(state,callbackAmount or M.blockFloat(state,actor,amount,fixed))end
    if state.originalV4 and actor==state.player and actor.block==before then return end
    Events.emit(state, "block", {source = actor.id, target = actor.id, amount = actor.block - before})
    if state.originalV4Preview and actor==state.player and actor.block>before then
        state.originalV4Preview[#state.originalV4Preview+1]={op='block',low=actor.block-before,high=actor.block-before}
    end
    if actor==state.player and gained>0 and (actor.statuses.juggernaut or 0)>0 then
        enqueue(state,{op="damageRandom",value=actor.statuses.juggernaut,fixed=true},actor)
    end
end

function M.resolveCurlUp(state, target, block)
    if state.player.hp <= 0 or not M.isActive(target) then return end
    M.block(state,target,block,true)
    local amount=target.statuses.curl_up or 0
    target.statuses.curl_up=0
    Events.emit(state,"status",{source=target.id,target=target.id,status="curl_up",amount=-amount})
end

-- Only the bounded Curl Up bottom tail. Combat owns the outer action boundary.
function M.flushCurlUp(state)
    Act2Powers.flush(M,state)
    local queue = state.curlUpQueue
    state.curlUpQueue = nil
    -- The original death screen stops action-manager updates immediately.
    if not queue or state.player.hp <= 0 then return end
    for _, entry in ipairs(queue) do
        local target = entry.target
        -- GainBlock/RemovePower each reject a dead owner. A later queued hit
        -- may have killed it after the initial nonlethal trigger.
        M.resolveCurlUp(state,target,entry.amount)
    end
end

local function tick(state, actor, phase)
    if not M.isActive(actor) then return end
    local ids = {}
    for id in pairs(actor.statuses) do ids[#ids + 1] = id end
    table.sort(ids) -- deterministic event ordering across Lua runtimes
    for _, id in ipairs(ids) do
        local definition = assert(actor.statusDefinitions[id], "unknown active status")
        local amount = actor.statuses[id]
        local decay = definition.decay
        local skip = phase == "round_end" and actor[id .. "JustApplied"]
        if skip then actor[id .. "JustApplied"] = nil end
        if amount > 0 and decay:sub(1, #phase) == phase and not skip then
            local reactions = {}
            local eventCount=#state.events
            if decay:find("trigger", 1, true) then
                if id == "poison" then directDamage(state, actor, actor, amount, "poison", nil, reactions)
                elseif id == "regen" then
                    if state.originalV4 and actor==state.player then require('abyss_original_v4_health').heal(state,actor,amount,nil,'regen')
                    else
                    local before=actor.hp
                    local healed = math.min(actor.maxHp - actor.hp, amount)
                    actor.hp = actor.hp + healed
                    Events.emit(state, "heal", { target = actor.id, amount = healed, status = id })
                    require('abyss_relic_hooks').hpChanged(state,actor,before)
                    end
                end
            end
            actor.statuses[id] = amount - 1
            if decay:find("trigger", 1, true) then
                -- Trigger and decay are one presentation step, including lethal poison.
                if state.originalV4 and #state.events==eventCount then
                    Events.emit(state,'status',{source=actor.id,target=actor.id,status=id,amount=-1})
                else state.events[#state.events].frame = Events.frame(state)end
            else
                Events.emit(state, "status", {source = actor.id, target = actor.id, status = id, amount = -1})
            end
            M.resolveDamageReactions(state, reactions)
            if not M.isActive(actor) then return end
        end
    end
end

function M.endRound(state, actor)
    -- Orb Walker receives Growth in pre-battle, before any later round-decay
    -- debuff. Its first round is not suppressed like Cultist Ritual.
    Act3Powers.endRound(M,state,actor)
    tick(state, actor, "round_end")
end

function M.endTurn(state, actor)
    if actor~=state.player and M.isActive(actor) then
        for _,id in ipairs(M.powerSequence(actor,{'plated_armor','metallicize'}))do
            M.block(state,actor,actor.statuses[id],true)
        end
        if (actor.statuses.malleable or 0)>0 then actor.statuses.malleable=3 end
    end
    tick(state, actor, "turn_end")
    if not M.isActive(actor) then return end
    -- EntanglePower removes itself only for isPlayer=true, rather than reducing
    -- one stack at the monster round boundary or applying another Power.
    local entangled = actor.statuses.entangled or 0
    if actor == state.player and entangled > 0 then
        actor.statuses.entangled = 0
        Events.emit(state, "status", {source = actor.id, target = actor.id, status = "entangled", amount = -entangled})
    end
    local changed = false
    local endings,seen = {},{}
    for _,id in ipairs(actor.powerOrder or {}) do
        local stat=id:match('^lose_(.+)$')
        if id=='ritual' and actor==state.player and (actor.statuses.ritual or 0)>0 then
            endings[#endings+1]='ritual';seen.ritual=true
        elseif id=='wraith_form'and actor==state.player and (actor.statuses.wraith_form or 0)<0 then
            endings[#endings+1]=id;seen[id]=true
        elseif temporaryFields[stat] and (actor[temporaryFields[stat]] or 0)>0 then
            endings[#endings+1]=stat;seen[stat]=true
        end
    end
    for _,id in ipairs(actor.temporaryPowerOrder or {"strength","dexterity"}) do
        if not seen[id] then endings[#endings+1]=id end
    end
    if actor==state.player and (actor.statuses.ritual or 0)>0 and not seen.ritual then endings[#endings+1]='ritual' end
    if actor==state.player and (actor.statuses.wraith_form or 0)<0 and not seen.wraith_form then endings[#endings+1]='wraith_form'end
    for _, id in ipairs(endings) do
        local field = temporaryFields[id]
        local temporary = field and actor[field] or 0
        if id=='ritual' then
            M.applyPower(state,actor,'strength',actor.statuses.ritual,actor)
        elseif id=='wraith_form'then
            M.applyPower(state,actor,'dexterity',actor.statuses.wraith_form,actor)
        elseif temporary ~= 0 then
            -- The owner-end negative Power is a new Artifact-eligible DEBUFF.
            M.applyPower(state, actor, id, -temporary, actor)
            actor[field] = 0
            changed = true
            state.events[#state.events].frame = Events.frame(state)
        end
    end
    actor.temporaryPowerOrder = nil
    local powers={}
    for _,id in ipairs(actor.powerOrder or {}) do if id~='lose_strength' and id~='lose_dexterity' then powers[#powers+1]=id end end
    actor.powerOrder=powers
    if changed then state.events[#state.events].frame = Events.frame(state) end
    require('abyss_colorless_cards').endOwnerTurn(state,actor)
    require('abyss_silent_final_cards').endTurn(state,actor)
end

function M.resetBlock(state, actor)
    if not M.isActive(actor) then return end
    if actor==state.player and state.keepBlockOnNextStart then
        state.keepBlockOnNextStart=nil
        return
    end
    if (actor.statuses.barricade or 0) <= 0 and actor.block ~= 0 then
        actor.block = 0
        Events.emit(state, "block_reset", {target = actor.id})
    end
end

function M.startTurnEffects(state, actor)
    if actor~=state.player and (actor.statuses.flight or 0)>0 then actor.statuses.flight=3 end
    if M.isActive(actor) then tick(state, actor, "turn_start") end
end

function M.startTurn(state, actor)
    M.resetBlock(state, actor)
    M.startTurnEffects(state, actor)
end

return M
