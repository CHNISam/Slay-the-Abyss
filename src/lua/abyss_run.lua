-- Same-run deck and reward ownership. Platform/UI adapters issue these commands.
local Combat = require("abyss_combat")
local EventRandom = require("abyss_sts_random")
local Capability = require("abyss_card_capability")
local RelicPool = require('abyss_relic_pool')
local EmeraldRewards=require('abyss_emerald_rewards')
local RelicHooks = require('abyss_relic_hooks')
local M = {}
local preparedCharacters={ironclad=true,silent=true,defect=true,watcher=true}
local preparedOriginalRoles={HT=true,AR=true,FR=true,RD=true}

local function find(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
end

require('abyss_run_initialization').install(M,{preparedCharacters=preparedCharacters,preparedOriginalRoles=preparedOriginalRoles})
-- Permanent commands share one transaction boundary across events, rewards and
-- shops. Static content is read-only; every mutable owner remains private until
-- the complete command, including its hooks, succeeds.
local transactionOwners=setmetatable({},{__mode='k'})
local function nestedTransaction(run, command, owner)
    if owner then
        local called,ok,detail=pcall(command,run)
        if not called or not ok then
            if not owner.failed then owner.failed=true;owner.reason=called and detail or 'transaction_failed' end
            return false,called and detail or 'transaction_failed'
        end
        return true,detail
    end
end

function M.transaction(run,command)
    -- Nested permanent commands belong to the enclosing event/shop command.
    -- A rejected nested command poisons this transaction, even if its caller
    -- accidentally ignores the returned failure. Keep enclosing flow refs live.
    local owner=transactionOwners[run]
    if owner then return nestedTransaction(run,command,owner) end
    -- Copy the complete mutable graph once: pending rewards share nodeFlow.
    -- Reuse the read-only content bundle without copying it per command.
    local staged=Combat.copy(run,run.data and {[run.data]=run.data} or nil)
    owner={};transactionOwners[staged]=owner
    local called,ok,detail=pcall(command,staged)
    transactionOwners[staged]=nil
    if not called then return false,'transaction_failed' end
    if owner.failed then return false,owner.reason end
    if not ok then return false,detail end
    for key in pairs(run) do if staged[key]==nil then run[key]=nil end end
    for key,value in pairs(staged) do run[key]=value end
    return true,detail
end

-- The caller owns map replacement. This transition never creates another Run
-- or reassigns permanent card UIDs. A failed transition commits no owner.
require('abyss_run_transition').install(M)

function M.freezeMapContext(run)return EmeraldRewards.freezeMapContext(run)end
function M.mapContext(run)return EmeraldRewards.mapContext(run)end

local legacyRelics={['Burning Blood']='burning_blood',Anchor='anchor',Vajra='vajra',
 ['Bag of Preparation']='bag_of_preparation',Lantern='lantern',['Oddly Smooth Stone']='oddly_smooth_stone',
 ['Bronze Scales']='bronze_scales',['Membership Card']='membership_card',['The Courier']='courier',
 ['Smiling Mask']='smiling_mask',['Black Blood']='black_blood',SlaversCollar='slavers_collar',Sozu='sozu'}
local function relicDefinition(run,id)
    for _,relic in ipairs(run.data.relics.relics) do
        if relic.id==id or relic.sourceId==id or legacyRelics[id]==relic.id then return relic end
    end
end
local function cardDefinition(run,id)
    for _,card in ipairs(run.data.cards.cards) do if card.id==id or card.sts_name==id then return card end end
end
local function amount(n)return type(n)=='number' and n==n and n%1==0 and n>=0 and n<=2147483647 end
function M.gainGold(run,value)return RelicHooks.gainGold(run,value)end
function M.eventDamage(run,value)
    if run.phase~='node' or not amount(value) or not amount(run.hp) or not amount(run.maxHp)
        or run.hp>run.maxHp then return false,'invalid_event_damage' end
    return M.transaction(run,function(staged)
        if staged.hp<=0 then return false,'event_player_dead' end
        local lost=math.min(staged.hp,RelicHooks.onLoseHpLast(staged,value))
        staged.hp=staged.hp-lost
        if lost>0 and staged.hp==0 then
            require('abyss_player_revive').outside(staged,function(healing)return M.heal(staged,healing)end)
        end
        return true,lost
    end)
end
-- WindingHalls creates DamageInfo(null, amount), whose default is NORMAL.
-- Room transition cleared Powers/block; do not consult a historical battle.
function M.eventNormalDamage(run,value)
    -- Null owner does not dispatch Torii.onAttacked; permanent fatal reserves
    -- share the event damage boundary without consulting a retained battle.
    return M.eventDamage(run,value)
end
function M.heal(run,value)
    assert(amount(value),'invalid heal')
    for _,id in ipairs(run.relics or {})do
        if id=='mark_of_bloom' or id=='Mark of the Bloom' then return 0 end
    end
    local before=run.hp;run.hp=math.min(run.maxHp,run.hp+0.0+value);return run.hp-before
end
function M.increaseMaxHp(run,value)
    if not amount(value) or not amount(run.maxHp) or run.maxHp+0.0+value>2147483647 then return false,'invalid_max_hp' end
    run.maxHp=run.maxHp+0.0+value;return true,M.heal(run,value)
end
-- AbstractCreature.decreaseMaxHealth: no damage, healing or HP-loss hooks.
-- Active/retained combat owners need their own health synchronization contract.
function M.decreaseMaxHp(run,value)
    if run.phase=='combat' or run.combat or run.pendingCombatRewards then
        return false,'max_hp_health_context_unavailable'
    end
    if not amount(value) or not amount(run.maxHp) or run.maxHp<1
        or not amount(run.hp) or run.hp>run.maxHp then return false,'invalid_max_hp' end
    local before=run.maxHp
    run.maxHp=math.max(1,run.maxHp-0.0-value)
    run.hp=math.min(run.hp,run.maxHp)
    return true,before-run.maxHp
end
local function validateCardOptions(definition, options)
    local upgrades=options.upgrades or options.upgradeCount
    if upgrades~=nil and (not amount(upgrades) or upgrades>0 and not definition.upgrade) then return nil,'invalid_card_upgrade' end
    if options.upgraded and not definition.upgrade then return nil,'card_not_upgradeable' end
    if options.searingBlowCopyUpgrades~=nil and options.upgraded~=nil and type(options.upgraded)~='boolean'then return nil,'invalid_card_copy'end
    return true,upgrades
end

function M.prepareCard(run,id,options)
    local definition=cardDefinition(run,id)
    if not Capability.isImplemented(definition) then return nil,'card_content_unavailable' end
    options=options or {}
    local valid,upgrades=validateCardOptions(definition,options)
    if not valid then return nil,upgrades end
    local offer={cardId=definition.id,upgraded=options.upgraded==true,
        upgrades=upgrades,searingBlowCopyUpgrades=options.searingBlowCopyUpgrades}
    if not Combat.validSearingBlowCopy(offer)then return nil,'invalid_card_copy'end
    local accepted,why=RelicHooks.beforeObtainCard(run,definition)
    if not accepted and why~='curse_prevented' then return nil,why end
    offer.blocked=not accepted;return offer
end
local function applyOfferedUpgrades(card, offer, definition)
    local upgrades=offer.upgrades
    if upgrades~=nil then
        if not amount(upgrades) or upgrades>0 and not definition.upgrade then return false,'invalid_card_upgrade' end
        card.upgrades=upgrades
        if card.searingBlowCopyUpgrades==nil then card.upgraded=upgrades>0 end
    end
    if card.upgraded and not definition.upgrade then return false,'card_not_upgradeable' end
    return true
end

function M.commitCard(run,offer)
    return M.transaction(run,function(staged)
        if type(offer)~='table' then return false,'invalid_card_offer' end
        local definition=cardDefinition(staged,offer.cardId)
        if not Capability.isImplemented(definition) then return false,'card_content_unavailable' end
        if not Combat.validSearingBlowCopy(offer)then return false,'invalid_card_copy'end
        if offer.blocked then
            require('abyss_writhing_mass').externalObtain(staged)
            return true,'curse_blocked'
        end
        local uid=staged.nextDeckUid
        if type(uid)~='number' or uid%1~=0 or uid<1 or uid>=9007199254740991.0 then return false,'invalid_deck_uid' end
        for _,card in ipairs(staged.deck) do if card.uid==uid then return false,'invalid_deck_uid' end end
        local card={uid=uid,cardId=definition.id,upgraded=offer.upgraded==true,
            searingBlowCopyUpgrades=offer.searingBlowCopyUpgrades}
        local valid,why=applyOfferedUpgrades(card,offer,definition)
        if not valid then return false,why end
        -- Relics receive the private entity before master-deck insertion.
        -- Acquisition upgrades must never mutate the shared definition.
        local accepted,reason=RelicHooks.onObtainCard(staged,card,definition,{increaseMaxHp=M.increaseMaxHp})
        if accepted==false then return false,reason end
        staged.deck[#staged.deck+1]=card;staged.nextDeckUid=uid+1.0
        require('abyss_writhing_mass').externalObtain(staged,card)
        return true,uid
    end)
end
function M.obtainCard(run,id,options)
    return M.transaction(run,function(staged)
        local offer,reason=M.prepareCard(staged,id,options)
        if not offer then return false,reason end
        return M.commitCard(staged,offer)
    end)
end
function M.removeCard(run,uid)
    return M.transaction(run,function(staged)
        local card,position
        for i,c in ipairs(staged.deck) do if c.uid==uid then card,position=c,i;break end end
        if not card then return false,'invalid_card' end
        if not cardDefinition(staged,card.cardId) then return false,'card_content_unavailable' end
        table.remove(staged.deck,position)
        require('abyss_curses').onRemove(staged,card)
        return true,card
    end)
end
local function publishCombatRelic(staged, definition)
    -- These source relics have no onEquip benefit. External obtains during
    -- active combat only publish ownership to the existing battle hooks;
    -- DataDisk still waits for the next atBattleStart. Keep unrelated
    -- legacy relic-snapshot behavior unchanged.
    if staged.phase=='combat' and staged.combat and not RelicHooks.owns(staged.combat,definition.id) and
        (definition.id=='snake_skull' or definition.id=='data_disk' or definition.id=='damaru' or definition.id=='lizard_tail') then
        staged.combat.relics=staged.combat.relics or {}
        staged.combat.relics[#staged.combat.relics+1]=definition.id
        if definition.id=='lizard_tail' then require('abyss_lizard_tail').onObtain(staged.combat)end
    end
end

function M.obtainRelic(run,id)
    return M.transaction(run,function(staged)
        local definition=relicDefinition(staged,id)
        if not definition then return false,'relic_content_unavailable' end
        if definition.id=='circlet' then
            RelicHooks.obtainCirclet(staged);return true,definition.id
        end
        for _,owned in ipairs(staged.relics) do if RelicHooks.localId(owned)==definition.id then return false,'relic_already_owned' end end
        local position
        if definition.replaces then
            for i,owned in ipairs(staged.relics) do if owned==definition.replaces then position=i;break end end
            if not position then return false,'relic_condition_unmet' end
        end
        if position then staged.relics[position]=definition.id
        else staged.relics[#staged.relics+1]=definition.id end
        RelicHooks.onEquip(staged,definition.id,{
            canUpgrade=function(card)
                local def=cardDefinition(staged,card.cardId)
                return def and def.upgrade and next(def.upgrade)~=nil
                    and (not card.upgraded or def.repeatable==true)
            end,
            upgrade=function(card)
                card.upgrades=(card.upgrades or (card.upgraded and 1 or 0))+1
                card.upgraded=true;return true
            end})
    publishCombatRelic(staged, definition)
        return true,definition.id
    end)
end
local function relicContextOwners(run)
    local owned,deck={},{}
    for _,id in ipairs(run.relics) do
        local def=relicDefinition(run,id)
        local source=def and def.sourceId
        if not source then for key,value in pairs(legacyRelics) do if value==id then source=key;break end end end
        owned[#owned+1]=source or id
    end
    for _,card in ipairs(run.deck) do
        local def=cardDefinition(run,card.cardId)
        if def then deck[#deck+1]={type=def.type:upper(),rarity=def.rarity:upper()} end
    end
    return owned, deck
end

function M.prepareRelic(run,options)
    options=options or {}
    if not run.relicPool then return nil,'relic_pool_unavailable' end
    local pool=RelicPool.restore(RelicPool.snapshot(run.relicPool),run.relicPool.catalog)
    local tier=options.tier or RelicPool.rollTier(pool,options.channel or 'event')
    local owned, deck = relicContextOwners(run)
    local context={act=run.act or 1,floor=run.floor,room=options.room or 'event',owned=owned,deck=deck,endless=false}
    local draw=options.screenless and RelicPool.screenless or RelicPool.draw
    local id,trace,requested=draw(pool,tier,context,options.fromTail)
    local definition=relicDefinition(run,id)
    if not definition then return nil,'relic_content_unavailable' end
    return {id=definition.id,sourceId=id,requestedId=requested,tier=tier,trace=trace},pool
end

local rooms=require('abyss_run_rooms').install(M,{find=find})
local settlement=require('abyss_run_settlement').install(M,{find=find,amount=amount,
    endingQualified=rooms.endingQualified,endingRoom=rooms.endingRoom})
local applyPermanentChanges=settlement.applyPermanentChanges

function M.rewardOptions(run)
    if run.phase ~= "reward" or run.rewards.cardResolved then return {} end
    return Combat.copy(run.rewards.cards)
end

function M.claimCardReward(run, choice)
    if run.phase ~= "reward" or run.rewards.cardResolved then return false, "no_pending_reward" end
    if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 0 or choice > #run.rewards.cards then
        return false, "invalid_reward_choice"
    end
    local rewards,deck,relics,potions,flow,battle=run.rewards,run.deck,run.relics,run.potions,run.nodeFlow,run.combat
    local ok,detail=M.transaction(run,function(staged)
        -- A card choice never owns the independent potion reward (RewardItem).
        if choice > 0 then
            local ok,reason=M.obtainCard(staged,staged.rewards.cards[choice],
                {upgraded=staged.rewards.cardUpgrades and staged.rewards.cardUpgrades[choice]==true})
            if not ok then return false,reason end
        end
        -- PC Skip merely closes the picker; choice=0 explicitly abandons it.
        staged.rewards.cardResolved = true
        return true
    end)
    if ok then
        -- Obtaining a reward appends a card; existing inventory and room owners
        -- remain live for the restored map and its pending reward continuation.
        for i=#deck+1,#run.deck do deck[i]=run.deck[i] end
        run.deck,run.relics,run.potions,run.nodeFlow,run.combat=deck,relics,potions,flow,battle
        -- Only the card flag belongs to this command. Keep the existing reward
        -- and independent item owners; never expose them to the private stage.
        rewards.cardResolved=run.rewards.cardResolved
        run.rewards=rewards
    end
    return ok,detail
end

local function validGold(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= 2147483647
end

-- RewardItem.GOLD: the victory creates an offer; clicking it grants the money.
function M.claimRelicReward(run,index)
    return M.transaction(run,function(staged)
        local rewards=staged.phase=='reward' and staged.rewards
        if type(index)~='number' or index%1~=0 then return false,'invalid_relic_reward' end
        local item=rewards and rewards.relics and rewards.relics[index]
        if not item or item.claimed then return false,'no_pending_relic_reward' end
        if item.unavailable then return false,'relic_content_unavailable' end
        local ok,why=M.obtainRelic(staged,item.id);if not ok then return false,why end
        item.claimed=true
        return true,item.id
    end)
end

function M.claimEmeraldKey(run)
    return M.transaction(run,function(staged)return EmeraldRewards.claim(staged)end)
end
function M.canClaimEmeraldKey(run)return EmeraldRewards.canClaim(run)end

function M.claimGoldReward(run)
    local rewards = run.phase == "reward" and run.rewards
    if not rewards or rewards.goldClaimed ~= false then return false, "no_pending_gold" end
    if not validGold(rewards.gold) or rewards.gold == 0 or not validGold(run.gold)
        or run.gold + 0.0 + rewards.gold > 2147483647 then return false, "invalid_gold_reward" end
    M.gainGold(run,rewards.gold);rewards.goldClaimed = true
    return true
end

function M.claimStolenGoldReward(run)
    local rewards = run.phase == "reward" and run.rewards
    local item = type(rewards) == "table" and rewards.stolenGold
    if type(item) ~= "table" or rewards.manualContinue ~= true or item.type ~= "STOLEN_GOLD" or item.claimed ~= false then
        return false, "no_pending_stolen_gold"
    end
    if not validGold(item.amount) or item.amount == 0 or not validGold(run.gold)
        or run.gold + 0.0 + item.amount > 2147483647 then return false, "invalid_stolen_gold" end
    M.gainGold(run,item.amount);item.claimed = true
    return true
end

function M.leaveCombatRewards(run)
    if run.phase ~= "reward" or not run.rewards or run.rewards.manualContinue ~= true then
        return false, "no_pending_reward"
    end
    -- Proceed opens the map without consuming unclaimed items. They remain
    -- accessible until a successful room transition commits.
    run.pendingCombatRewards = { rewards = run.rewards, combat = run.combat, flow = run.nodeFlow }
    run.phase, run.rewards, run.combat = "map", nil, nil
    return true
end

function M.reopenCombatRewards(run)
    local pending = run.pendingCombatRewards
    if run.phase ~= "map" or not pending or pending.flow ~= run.nodeFlow then return false, "no_pending_reward" end
    run.rewards, run.combat, run.phase = pending.rewards, pending.combat, "reward"
    run.pendingCombatRewards = nil
    return true
end

function M.claimPotionReward(run)
    if run.phase~='reward' then return false,'no_pending_reward' end
    local offer=run.rewards and run.rewards.potion
    if not offer or offer.resolved then return false,'no_pending_potion_reward' end
    for _, id in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, id)
        if relic and relic.blocksPotions then
            offer.resolved, offer.result = true, 'blocked'
            return true, 'potion_blocked_by_sozu'
        end
    end
    if offer.unavailable then return false,'potion_content_unavailable' end
    local ok,slot=M.obtainPotion(run,offer.id)
    if not ok then return false,slot end
    offer.resolved,offer.result,offer.slot=true,'claimed',slot
    return true,slot
end

function M.skipPotionReward(run)
    if run.phase~='reward' then return false,'no_pending_reward' end
    local offer=run.rewards and run.rewards.potion
    if not offer or offer.resolved then return false,'no_pending_potion_reward' end
    offer.resolved,offer.result=true,'skipped'
    return true
end

local function syncBattlePotions(run)
    -- Paused card/pile/discard/scry continuations can consume a fatal reserve.
    -- Publish its permanent counter before any inventory early return.
    run.relicCounters=Combat.copy(run.combat.relicCounters or {})
    if run.combat.potionRngChanged then
        run.shopRng=run.shopRng and Combat.copy(run.shopRng)or {merchant=EventRandom.fromSeed(run.runSeed)}
        run.shopRng.potion=EventRandom.cloneState(run.combat.potionRng)
        run.combat.potionRngChanged=nil
    end
    local inventory=run.combat.potionInventory
    if not inventory then return end
    for slot=1,run.potionSlots or run.data.rules.player.potionSlots do
        if run.potions[slot]~=inventory[slot] then run.potions=Combat.copy(inventory);return end
    end
end

function M.chooseCard(run,token,uid)
    if run.phase~="combat" then return false,"not_in_combat" end
    -- Core may already have won before reward preparation fails. Keep this
    -- whole public command retryable, with all original UI/entity references.
    local restore=require('abyss_snapshot').capture(run)
    local called,ok,reason=pcall(function()
        local accepted,detail=Combat.chooseCard(run.combat,token,uid)
        if accepted then
            syncBattlePotions(run)
            run.gold=run.combat.player.gold
            run.relicCounters=Combat.copy(run.combat.relicCounters or {})
            applyPermanentChanges(run)
            if Combat.outcome(run.combat) then
                local completed,why=M.finishCombat(run)
                if not completed then return false,why end
            end
        end
        return accepted,detail
    end)
    if not called then restore();error(ok,0)end
    if not ok then restore()end
    return ok,reason
end

local function replayCommand(run, uid, targetIndex, commandId)
    if commandId~=nil and run.originalCommands then
        if type(commandId)~='string' or commandId==''then return false,'invalid_command_id'end
        local prior=run.originalCommands[commandId]
        if prior then return prior.uid==uid and prior.target==targetIndex,prior.uid==uid and prior.target==targetIndex and 'already_committed' or 'command_conflict'end
    end
    if commandId and run.combat and run.combat.originalV4 then
        local replay,why=require('abyss_original_v4').replay(run.combat,commandId,uid,targetIndex)
        if replay~=nil then return replay,why end
    end
end

function M.play(run, uid, targetIndex, commandId)
    local replay,replayReason=replayCommand(run,uid,targetIndex,commandId)
    if replay~=nil then return replay,replayReason end
    if run.phase ~= "combat" then return false, "not_in_combat" end
    -- The public command includes permanent/inventory publication and source
    -- reward preparation, not just Combat.play's smaller battle transaction.
    local snapshot=require('abyss_snapshot')
    local restore,owner=snapshot.capture(run,run.combat)
    local called,ok,reason=pcall(function()
        local accepted,why=Combat.play(run.combat,uid,targetIndex,commandId,owner)
        if accepted then
            syncBattlePotions(run)
            if commandId and run.originalCommands then run.originalCommands[commandId]={uid=uid,target=targetIndex,generation=run.roomGeneration}end
            run.gold=run.combat.player.gold
            run.relicCounters=Combat.copy(run.combat.relicCounters or {})
            applyPermanentChanges(run)
            if Combat.outcome(run.combat) then
                local completed,detail=M.finishCombat(run)
                if not completed then return false,detail end
            end
        end
        return accepted,why
    end)
    if not called then restore();snapshot.release(owner);error(ok,0)end
    if not ok then restore()end
    snapshot.release(owner)
    return ok, reason
end

-- A paused card continuation owns selection, queued tails, permanent
-- publication and finish/reward preparation, just like the public play command.
-- Combat keeps its standalone savepoint or consumes this exact Run preimage and
-- all original entity/pile references when a later step rejects or throws.
local function continueCombatChoice(run,choose,uids,token,generation)
    local snapshot=require('abyss_snapshot')
    local restore,owner=snapshot.capture(run,run.combat)
    local called,ok,reason=pcall(function()
        local accepted,detail=choose(run.combat,uids,token,generation,owner)
        if accepted then
            syncBattlePotions(run)
            run.gold=run.combat.player.gold
            applyPermanentChanges(run)
            if Combat.outcome(run.combat) then
                local completed,why=M.finishCombat(run)
                if not completed then return false,why end
            end
        end
        return accepted,detail
    end)
    if not called then restore();snapshot.release(owner);error(ok,0)end
    if not ok then restore()end
    snapshot.release(owner)
    return ok,reason
end

-- Selection commands carry a battle generation in addition to the per-battle
-- selection token. A delayed command from an old battle cannot choose new cards.
function M.chooseDiscard(run, uids, token, generation)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    if generation ~= run.combatGeneration then return false, "stale_combat_generation" end
    return continueCombatChoice(run,Combat.chooseDiscard,uids,token)
end
function M.choosePile(run,uids,token,generation)
    if run.phase~='combat' then return false,'not_in_combat' end
    if generation~=run.combatGeneration then return false,'stale_combat_generation' end
    return continueCombatChoice(run,Combat.choosePile,uids,token,generation)
end

function M.chooseScry(run, uids, token, generation)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    if generation ~= run.combatGeneration then return false, "stale_combat_generation" end
    return continueCombatChoice(run,Combat.chooseScry,uids,token)
end

function M.chooseHand(run,uids,token,generation)
    if run.phase~="combat" then return false,"not_in_combat" end
    if generation~=run.combatGeneration then return false,"stale_combat_generation" end
    return continueCombatChoice(run,Combat.chooseHand,uids,token)
end

function M.endTurn(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local snapshot=require('abyss_snapshot');local restore,owner=snapshot.capture(run,run.combat)
    local called,ok,reason=pcall(function()
        local accepted,detail=Combat.endTurn(run.combat,owner)
        if accepted then
            syncBattlePotions(run)
            run.gold = run.combat.player.gold
            run.relicCounters=Combat.copy(run.combat.relicCounters or {})
            applyPermanentChanges(run)
            if Combat.outcome(run.combat) then
                local completed,why=M.finishCombat(run)
                if not completed then return false,why end
            end
        end
        return accepted,detail
    end)
    if not called then restore();snapshot.release(owner);error(ok,0)end
    if not ok then restore()end;snapshot.release(owner)
    return ok,reason
end

function M.choosePotionStance(run,selected,token,generation,battle)
    if run.phase~='combat' then return false,'not_in_combat'end
    if battle~=run.combat or generation~=run.combatGeneration then return false,'stale_combat_generation'end
    local restore=require('abyss_snapshot').capture(run)
    local called,ok,why=pcall(function()
        local accepted,reason=Combat.choosePotionStance(battle,selected,token,generation)
        if not accepted then return false,reason end
        syncBattlePotions(run)
        run.hp,run.maxHp,run.gold=battle.player.hp,battle.player.maxHp,battle.player.gold
        run.relicCounters=Combat.copy(battle.relicCounters or {})
        applyPermanentChanges(run)
        if Combat.outcome(battle)then assert(M.finishCombat(run),'potion outcome failed')end
        return true
    end)
    if not called or not ok then restore();return false,called and why or 'potion_choice_failed'end
    return true
end

-- Inventory slots are physical positions, not a packed list. Acquiring a bottle
-- fills the leftmost vacancy; reward/shop adapters still own eligibility/payment.
require('abyss_run_potions').install(M,{find=find,applyPermanentChanges=applyPermanentChanges,
    combatEndHealing=settlement.combatEndHealing})

-- Permanent upgrades reuse the existing card definition/upgrade owner. They
-- never obtain a new card, replace its UID, or filter out bottled instances.
local function permanentUpgradeContext(run,uid)
    local instance
    for _,card in ipairs(run.deck)do
        if card.uid==uid then
            if instance then return nil,nil,'invalid_card' end
            instance=card
        end
    end
    if not instance then return nil,nil,'invalid_card' end
    local definition=cardDefinition(run,instance.cardId)
    if not definition then return nil,nil,'card_content_unavailable' end
    return {catalog={cards={[instance.cardId]=definition}}},instance
end
function M.canUpgradeCard(run,uid)
    local context,instance,why=permanentUpgradeContext(run,uid)
    if not context then return false,why end
    if not Combat.canUpgrade(context,instance)then return false,'card_not_upgradeable'end
    return true
end
function M.upgradeCard(run,uid)
    return M.transaction(run,function(staged)
        local context,instance,why=permanentUpgradeContext(staged,uid)
        if not context then return false,why end
        if not Combat.upgrade(context,instance)then return false,'card_not_upgradeable'end
        return true,instance.uid
    end)
end

return M
