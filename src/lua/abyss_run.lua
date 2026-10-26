-- Same-run deck and reward ownership. Platform/UI adapters issue these commands.
local Combat = require("abyss_combat")
local Inventory = require("abyss_inventory")
local EventRandom = require("abyss_sts_random")
local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local PotionRewards = require("abyss_potion_rewards")
local CardPool = require("abyss_card_pool")
local Capability = require("abyss_card_capability")
local GoldRewards = require("abyss_gold_rewards")
local RunSeed = require("abyss_run_seed")
local EncounterQueue = require("abyss_encounter_queue")
local RoomEncounters = require("abyss_room_encounters")
local CardRandom = require("abyss_card_random")
local RelicPool = require('abyss_relic_pool')
local RelicHooks = require('abyss_relic_hooks')
local Acts = require('abyss_acts')
local M = {}

local function find(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
end

function M.new(data, seed, options)
    local sourceData=data
    local profile,ownsData
    if options ~= nil then
        assert(type(options)=='table','invalid character options')
        assert(options.campaign==nil or type(options.campaign)=='boolean','invalid campaign option')
        assert(not options.campaign or options.experimental==true,
            'campaign requires explicit experimental mode')
        if require('abyss_original_v4_profiles').is(options.character) then
            data,profile=require('abyss_original_v4_profiles').prepare(data,options.character)
            ownsData=true
        else
            assert(options.experimental == true,
                "non-default characters require explicit experimental mode")
            if options.character~=nil then
                data,profile=require('abyss_run_card_catalog').prepareSelected(data,options.character)
                ownsData=true
            end
        end
    end
    if not (profile and profile.originalV4)then
        data=require('abyss_run_card_catalog').prepare(sourceData,data,profile and profile.id,ownsData)
        ownsData=true
    end
    data=require('abyss_colorless_cards').withCards(data)
    local eventSeed = RunSeed.normalize(seed)
    local cardOwner = CardRandom.new(eventSeed)
    -- Profile factories already detached the whole input graph. Their private
    -- result can be adopted; caller-owned/default bundles still need a copy.
    local runData=ownsData and data or Combat.copy(data)
    require('abyss_class_potions').register(runData)
    local run = { version = data.rules.version, data = runData, seed = RunSeed.legacy(eventSeed),runSeed=eventSeed,
        eventSeed = eventSeed, eventRng = EventRandom.fromSeed(eventSeed), miscRng = EventRandom.fromSeed(eventSeed),
        treasureRng = EventRandom.fromSeed(eventSeed),
        cardRng = cardOwner.cardRng,cardRarityOffset=cardOwner.cardRarityOffset,
        encounters=EncounterQueue.new(eventSeed),roomGeneration=0,
        -- Launch supports the exact source !isBossSeen(GUARDIAN) branch. It
        -- duplicates Guardian and spends no monsterRng; no all-unlocked claim.
        bossInitialization={profile='guardian-unseen',bossList={'The Guardian','The Guardian'}},
        unknown = { chances = Unknown.newPc(), pools = EventPool.new(data.rules.events.poolMode or 'restricted-six') },
        phase = "map", floor = 1, hp = data.rules.player.maxHp, maxHp = data.rules.player.maxHp,
        elapsedSeconds = 0, victories = 0,
        gold = data.rules.player.startingGold, deck = {}, nextDeckUid = 1,
        relics = Combat.copy(data.rules.player.startingRelics), potions = {} }
    local sources=run.data.cards.sourcePools
    sources.cardSourceMetadata=sources.cardSourceMetadata or {}
    for _,card in ipairs(run.data.cards.cards)do
        if not sources.cardSourceMetadata[card.id] then
            sources.cardSourceMetadata[card.id]={sourceId=card.sourceId or card.sts_name or card.id,
                rarity=card.rarity,type=card.type,healing=card.healing==true}
        end
    end
    if profile then run.character, run.characterProfile = profile.id, Combat.copy(profile) end
    if profile and profile.originalV4 then run.originalCommands={}end
    if options and options.campaign then
        run.campaign,run.act,run.keys=true,1,{ruby=false,emerald=false,sapphire=false}
        run.unknown.pools=EventPool.new('full')
    end
    for _, id in ipairs(data.cards.starter_deck.cards) do
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = id, upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    end
    if data.relicSource then run.relicPool=RelicPool.new(eventSeed,data.relicSource) end
    return run
end

-- Permanent commands share one transaction boundary across events, rewards and
-- shops. Static content is read-only; every mutable owner remains private until
-- the complete command, including its hooks, succeeds.
local transactionOwners=setmetatable({},{__mode='k'})
function M.transaction(run,command)
    -- Nested permanent commands belong to the enclosing event/shop command.
    -- A rejected nested command poisons this transaction, even if its caller
    -- accidentally ignores the returned failure. Keep enclosing flow refs live.
    local owner=transactionOwners[run]
    if owner then
        local called,ok,detail=pcall(command,run)
        if not called or not ok then
            if not owner.failed then owner.failed=true;owner.reason=called and detail or 'transaction_failed' end
            return false,called and detail or 'transaction_failed'
        end
        return true,detail
    end
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
function M.advanceAct(run)
    return M.transaction(run,function(staged)
        if staged.campaign~=true then return false,'campaign_unavailable' end
        local act=staged.act
        if act~=1 and act~=2 and act~=3 then return false,'invalid_act_transition' end
        if type(staged.encounters)~='table' or (staged.encounters.act or 1)~=act
            or staged.encounters.rawSeed~=staged.runSeed then return false,'encounter_act_mismatch' end
        local chapter=Acts.get(act)
        if staged.phase~='act_transition' or staged.pendingAct~=act+1
            or staged.floor~=chapter.last or not staged.nodeFlow or not staged.nodeFlow.complete
            or staged.nodeFlow.floor~=chapter.last then return false,'act_transition_unavailable' end
        if act<=2 and (staged.nodeFlow.roomKind~='boss_treasure' or staged.nodeFlow.result~='boss_treasure_complete') then
            return false,'boss_treasure_pending'
        end
        if act==3 and (staged.nodeFlow.roomKind~='ending' or staged.nodeFlow.result~='ending_door') then
            return false,'ending_door_required'
        end
        if act==3 and (staged.endingUnlocked~=true or type(staged.keys)~='table'
            or staged.keys.ruby~=true or staged.keys.emerald~=true or staged.keys.sapphire~=true) then
            return false,'ending_keys_required'
        end
        local counter=EventRandom.snapshot(staged.cardRng).counter
        local target=counter>0 and counter<250 and 250 or counter>250 and counter<500 and 500
            or counter>500 and counter<750 and 750 or counter
        for _=counter+1,target do EventRandom.randomBoolean(staged.cardRng) end
        local nextAct=act+1
        local queue=EncounterQueue.new(staged.runSeed,nextAct,staged.encounters.monsterRng)
        staged.bossInitialization,staged.encounters=EncounterQueue.initializeBoss(queue,staged.bossHistory)
        EventPool.nextAct(staged.unknown.pools,nextAct)
        local tinyChest=staged.unknown.chances.tinyChestCount
        staged.unknown.chances=Unknown.newPc()
        staged.unknown.chances.tinyChestCount=tinyChest
        M.heal(staged,staged.maxHp)
        staged.act,staged.phase,staged.floor=nextAct,'map',Acts.get(nextAct).first-1
        staged.nodeFlow,staged.pendingAct,staged.pendingCombatRewards,staged.rewards=nil,nil,nil,nil
        staged.combat,staged.lastResult=nil,nil
        staged.potionChanceModifier=0
        return true
    end)
end

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
        local lost=math.min(staged.hp,value)
        staged.hp=staged.hp-lost
        if lost>0 and staged.hp==0 then require('abyss_potion_fairy').outside(staged) end
        return true,lost
    end)
end
-- WindingHalls creates DamageInfo(null, amount), whose default is NORMAL.
-- Room transition cleared Powers/block; do not consult a historical battle.
-- Unimplemented permanent damage/revival hooks must refuse, not act as HP_LOSS.
function M.eventNormalDamage(run,value)
    for _,id in ipairs(run.relics or {})do
        if id=='tungsten_rod' or id=='lizard_tail' then return false,'event_damage_content_unavailable' end
    end
    -- Null owner does not dispatch Torii.onAttacked. Existing outside Fairy is shared.
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
function M.prepareCard(run,id,options)
    local definition=cardDefinition(run,id)
    if not Capability.isImplemented(definition) then return nil,'card_content_unavailable' end
    options=options or {}
    local upgrades=options.upgrades or options.upgradeCount
    if upgrades~=nil and (not amount(upgrades) or upgrades>0 and not definition.upgrade) then return nil,'invalid_card_upgrade' end
    if options.upgraded and not definition.upgrade then return nil,'card_not_upgradeable' end
    local accepted,why=RelicHooks.beforeObtainCard(run,definition)
    if not accepted and why~='curse_prevented' then return nil,why end
    return {cardId=definition.id,upgraded=options.upgraded==true,
        upgrades=upgrades,blocked=not accepted}
end
function M.commitCard(run,offer)
    return M.transaction(run,function(staged)
        if type(offer)~='table' then return false,'invalid_card_offer' end
        local definition=cardDefinition(staged,offer.cardId)
        if not Capability.isImplemented(definition) then return false,'card_content_unavailable' end
        if offer.blocked then return true,'curse_blocked' end
        local uid=staged.nextDeckUid
        if type(uid)~='number' or uid%1~=0 or uid<1 or uid>=9007199254740991.0 then return false,'invalid_deck_uid' end
        for _,card in ipairs(staged.deck) do if card.uid==uid then return false,'invalid_deck_uid' end end
        local card={uid=uid,cardId=definition.id,upgraded=offer.upgraded==true}
        local upgrades=offer.upgrades
        if upgrades~=nil then
            if not amount(upgrades) or upgrades>0 and not definition.upgrade then return false,'invalid_card_upgrade' end
            card.upgrades=upgrades;card.upgraded=upgrades>0
        end
        if card.upgraded and not definition.upgrade then return false,'card_not_upgradeable' end
        -- Relics receive the private entity before master-deck insertion.
        -- Acquisition upgrades must never mutate the shared definition.
        RelicHooks.onObtainCard(staged,card,definition)
        staged.deck[#staged.deck+1]=card;staged.nextDeckUid=uid+1.0
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
function M.obtainRelic(run,id)
    return M.transaction(run,function(staged)
        local definition=relicDefinition(staged,id)
        if not definition then return false,'relic_content_unavailable' end
        if definition.id=='circlet' then
            RelicHooks.obtainCirclet(staged);return true,definition.id
        end
        for _,owned in ipairs(staged.relics) do if owned==definition.id then return false,'relic_already_owned' end end
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
        return true,definition.id
    end)
end
function M.prepareRelic(run,options)
    options=options or {}
    if not run.relicPool then return nil,'relic_pool_unavailable' end
    local pool=RelicPool.restore(RelicPool.snapshot(run.relicPool),run.relicPool.catalog)
    local tier=options.tier or RelicPool.rollTier(pool,options.channel or 'event')
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
    local context={act=run.act or 1,floor=run.floor,room=options.room or 'event',owned=owned,deck=deck,endless=false}
    local draw=options.screenless and RelicPool.screenless or RelicPool.draw
    local id,trace,requested=draw(pool,tier,context,options.fromTail)
    local definition=relicDefinition(run,id)
    if not definition then return nil,'relic_content_unavailable' end
    return {id=definition.id,sourceId=id,requestedId=requested,tier=tier,trace=trace},pool
end

local function startEncounter(run, encounter, sourceRoom)
    if run.phase ~= "map" then return false, "not_on_map" end
    if not encounter then return false, "unknown_encounter" end
    local generation = run.combatGeneration or 0
    if type(generation) ~= "number" or generation % 1 ~= 0 or generation < 0 or generation >= 2147483647 then
        return false, "invalid_combat_generation"
    end
    if not sourceRoom and (run.floor < encounter.minFloor or run.floor > encounter.maxFloor) then return false, "wrong_floor" end
    local opening, reason = Inventory.opening(run.data.relics.relics, run.relics,
        run.relicCounters,{tier=encounter.tier})
    if not opening then return false, reason end
    local bonus
    bonus, reason = Inventory.energyBonus(run.data.relics.relics, run.relics, encounter.tier)
    if not bonus then return false, reason end
    local combatData = {}
    for key, value in pairs(run.data) do combatData[key] = value end
    combatData.rules = Combat.copy(run.data.rules)
    combatData.rules.player.energyPerTurn = combatData.rules.player.energyPerTurn + 0.0 + bonus
    if combatData.rules.player.energyPerTurn > 2147483647 then return false, "invalid_relic_energy" end
    -- Source-ordered group assembly uses the current misc stream (MonsterHelper,
    -- fixed 319009d). Keep this separate from Combat's HP/AI/shuffle stream and
    -- publish neither the choice nor its RNG state until all setup succeeds.
    local enemies, nextMiscRng = encounter.enemies
    if not sourceRoom and encounter.enemiesOnTrue then
        nextMiscRng = EventRandom.cloneState(run.miscRng)
        if EventRandom.randomBoolean(nextMiscRng) then enemies = encounter.enemiesOnTrue end
    elseif not sourceRoom and encounter.lousePool then
        nextMiscRng = EventRandom.cloneState(run.miscRng)
        enemies = {}
        for slot = 1, encounter.louseCount do
            -- Each source getLouse call is independent: true red, false green.
            -- Keep candidates for every slot; repeated colors are legal.
            enemies[slot] = encounter.lousePool[EventRandom.randomBoolean(nextMiscRng) and 1 or 2]
        end
    elseif not sourceRoom and encounter.gremlinPool then
        nextMiscRng = EventRandom.cloneState(run.miscRng)
        local pool = Combat.copy(encounter.gremlinPool)
        enemies = {}
        for slot = 1, encounter.gremlinCount do
            -- Inclusive Java bound: 7, 6, 5, 4. Remove only this occurrence;
            -- duplicates carry weight, and draw order is construction order.
            enemies[slot] = table.remove(pool, EventRandom.randomInt(nextMiscRng, #pool - 1) + 1)
        end
    end
    local battle
    local options={cardRandomSeed=RunSeed.forFloor(run.runSeed,run.floor),shuffleSeed=RunSeed.forFloor(run.runSeed,run.floor),seed=run.seed,hp=run.hp,maxHp=run.maxHp,gold=run.gold,deck=run.deck,enemies=enemies,
        masterDeck=run.deck,miscRng=nextMiscRng or run.miscRng,cardRng=run.cardRng,
        beforeOpeningDraw=function(state)
            if opening.preDraw then
                local ok, openingReason = Inventory.applyOpening(state,opening.preDraw)
                if not ok then return false, openingReason end
            end
            return Inventory.applyOpening(state,opening.beforeDraw)
        end}
    options.beforeFirstTurn=function(state)
        state.potionRng=run.shopRng and EventRandom.cloneState(run.shopRng.potion)or EventRandom.fromSeed(run.runSeed)
        state.potionCharacter=require('abyss_potion_random').character(run)
        state.potionInventory=Combat.copy(run.potions)
        state.potionCapacity=run.potionSlots or run.data.rules.player.potionSlots
        if opening.preBattle then return Inventory.applyOpening(state,opening.preBattle)end
        return true
    end
    if run.character and not run.characterProfile.originalV4 then
        options.cardRandomSeed=run.runSeed
        options.enableStances=true
        options.orbSlots=run.character=='defect' and 3 or 0
        -- Normal rooms supply the exact room stream; explicit replay battles
        -- use an explicitly named independent stream, never the legacy LCG.
        options.orbRandomSeed = run.runSeed
    end
    if sourceRoom then
        options.roomSeed,options.roomStreams=sourceRoom.seed,sourceRoom
        if encounter.sourceEncounter then
            options.enemies=nil;options.sourceEncounter=encounter.sourceEncounter
            options.encounterBoundary={
                misc={boolean=function()return EventRandom.randomBoolean(sourceRoom.miscRng)end,
                    integer=function(lo,hi)return EventRandom.randomIntBetween(sourceRoom.miscRng,lo,hi)end},
                -- Cosmetic-only independent stream; not a replay of global
                -- libGDX MathUtils animation/offset entropy. Never spends misc.
                visualFloat=function(lo,hi)return EventRandom.randomFloatBetween(sourceRoom.visualRng,lo,hi)end}
        end
    end
    battle, reason = Combat.new(combatData, options)
    if not battle then return false, reason end
    -- Queue-tail relics follow the ordinary draw, retaining their held order.
    local ok
    ok, reason = Inventory.applyOpening(battle, opening.afterDraw)
    if not ok then return false, reason end
    run.combatGeneration = generation + 1
    battle.combatGeneration=run.combatGeneration
    run.combat, run.encounterId, run.encounterTier = battle, encounter.id, encounter.tier
    run.relicCounters=Combat.copy(battle.relicCounters)
    run.encounterSource,battle.encounterSource=encounter.source,encounter.source
    if nextMiscRng then run.miscRng = nextMiscRng end
    run.phase = "combat"
    run.pendingCombatRewards = nil
    return true
end

-- Explicit-ID development/replay entry; ordinary map rooms use startRoomCombat.
-- Historical medium_slimes and fixed-color examples never enter the source pool.
function M.startCombat(run,encounterId)
    return startEncounter(run,find(run.data.enemies.encounters,encounterId))
end

function M.roomStreams(run,floor)
    local seed=RunSeed.forFloor(run.runSeed,floor)
    return {seed=seed,monsterHpRng=EventRandom.fromSeed(seed),aiRng=EventRandom.fromSeed(seed),
        shuffleRng=EventRandom.fromSeed(seed),cardRandomRng=EventRandom.fromSeed(seed),
        miscRng=EventRandom.fromSeed(seed),visualRng=EventRandom.fromSeed(seed)}
end

function M.startRoomCombat(run,tier)
    if run.phase~='map' then return false,'not_on_map' end
    local act=run.act or 1
    if act~=1 and act~=2 and act~=3 then return false,'act_content_unavailable' end
    if type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
        or run.roomGeneration<0 or run.roomGeneration>=2147483647 then return false,'invalid_room_generation' end
    if type(run.encounters)~='table' or run.encounters.rawSeed~=run.runSeed then return false,'run_seed_mismatch' end
    local chapter=Acts.get(act)
    local first,last=chapter.first,chapter.boss
    if type(run.floor)~='number' or run.floor%1~=0 or run.floor<first or run.floor>last then return false,'wrong_floor' end
    local encounter,nextQueue
    if tier=='boss' then
        if act==3 then
            if run.floor~=50 or not run.bossInitialization or type(run.bossInitialization.bossList)~='table' then
                return false,'unsupported_boss_initialization'
            end
            local resolved,reason=require('abyss_act3_enemies').resolve(run.bossInitialization.bossList[1],tier)
            if not resolved then return false,reason end
            encounter=resolved
        elseif act==2 then
            if run.floor~=33 or not run.bossInitialization or type(run.bossInitialization.bossList)~='table' then
                return false,'unsupported_boss_initialization'
            end
            encounter=require('abyss_act2_enemies').resolve(run.bossInitialization.bossList[1],tier)
            if not encounter then return false,'act_content_unavailable' end
        elseif run.floor~=16 or not run.bossInitialization or run.bossInitialization.profile~='guardian-unseen' then
            return false,'unsupported_boss_initialization'
        else
            encounter={id='boss_guardian',tier='boss',source='The Guardian',enemies={'guardian'}}
        end
    else
        local source,reason
        local valid
        valid,source,nextQueue,reason=pcall(EncounterQueue.consume,run.encounters,tier)
        if not valid then return false,'invalid_encounter_state' end
        if not source then return false,reason end
        if act==3 then encounter,reason=require('abyss_act3_enemies').resolve(source,tier)
        elseif act==2 then encounter,reason=require('abyss_act2_enemies').resolve(source,tier)
        else encounter,reason=RoomEncounters.resolve(source,tier) end
        if not encounter then return false,reason end
    end
    local staged={};for k,v in pairs(run)do staged[k]=v end
    local ready,room=pcall(M.roomStreams,run,run.floor)
    if not ready then return false,'invalid_room_seed' end
    local called,ok,reason=pcall(startEncounter,staged,encounter,room)
    if not called then return false,'combat_unavailable' end
    if not ok then return false,reason end
    staged.miscRng=room.miscRng
    for _,key in ipairs({'combat','combatGeneration','encounterId','encounterTier','encounterSource','phase','miscRng','relicCounters'})do run[key]=staged[key]end
    if nextQueue then run.encounters=nextQueue end
    run.roomGeneration=run.roomGeneration+1
    run.pendingCombatRewards=nil
    return true
end

-- Queue checkpoint boundary only, not exit/resume or a complete Run save file.
function M.snapshotEncounters(run)
    return {version=2,runSeed=run.runSeed,floor=run.floor,roomGeneration=run.roomGeneration,
        queue=EncounterQueue.snapshot(run.encounters)}
end
function M.restoreEncounters(run,snapshot)
    if run.phase~='map' or (run.nodeFlow and not run.nodeFlow.complete) then return false,'node_pending' end
    if type(snapshot)~='table' or getmetatable(snapshot)~=nil then return false,'invalid_snapshot' end
    for k in pairs(snapshot)do if k~='version' and k~='runSeed' and k~='floor' and k~='roomGeneration' and k~='queue' then return false,'invalid_snapshot' end end
    if snapshot.version~=2 then return false,'invalid_snapshot' end
    if snapshot.runSeed~=run.runSeed then return false,'run_seed_mismatch' end
    if snapshot.floor~=run.floor then return false,'floor_mismatch' end
    if type(snapshot.roomGeneration)~='number' or snapshot.roomGeneration%1~=0
        or snapshot.roomGeneration<0 or snapshot.roomGeneration>2147483647
        or snapshot.roomGeneration~=run.roomGeneration then return false,'stale_encounter_checkpoint' end
    local ok,queue=pcall(EncounterQueue.restore,snapshot.queue)
    if not ok or queue.rawSeed~=run.runSeed then return false,'invalid_snapshot' end
    if (queue.act or 1)~=(run.act or 1) then return false,'encounter_act_mismatch' end
    -- A generation tag alone cannot authorize rewinding queue consumption.
    -- This API replaces a checkpoint at the current boundary, not Run progress.
    if type(run.encounters)~='table' or type(run.encounters.normal)~='table' or type(run.encounters.elite)~='table'
        or #queue.normal~=#run.encounters.normal or #queue.elite~=#run.encounters.elite then
        return false,'encounter_progress_mismatch'
    end
    run.encounters=queue
    return true
end

local function finishCombat(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local result = Combat.outcome(run.combat)
    if not result then return false, "battle_unfinished" end
    if run.combat.cardRng then run.cardRng=EventRandom.cloneState(run.combat.cardRng)end
    run.hp, run.seed, run.gold = run.combat.player.hp, run.combat.seed, run.combat.player.gold
    run.maxHp=run.combat.player.maxHp
    run.relicCounters=Combat.copy(run.combat.relicCounters or {})
    local allEscaped = Combat.allEnemiesEscaped(run.combat)
    run.lastResult = { outcome = result, turn = run.combat.turn, encounterId = run.encounterId, allEnemiesEscaped = allEscaped, mugged = run.combat.mugged }
    if result == "defeat" then
        run.phase, run.rewards = "defeat", nil
        return true
    end
    -- Combat-end relics apply once, before the reward transaction is offered.
    for _, id in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, id)
        if relic and relic.trigger == "combat_end" then
            for _, effect in ipairs(relic.effects) do
                if effect.op == "heal" then run.hp = math.min(run.maxHp, run.hp + effect.value) end
            end
        end
    end
    local gold, goldStream, nextGoldRng
    if run.combat.roomSeed then
        gold, goldStream, nextGoldRng = GoldRewards.prepare(run.encounterTier, run, {allEscaped=allEscaped})
    else
        -- Historical explicit-ID fixtures retain their fixed reward contract;
        -- only the actual source-room path claims the source gold RNG boundary.
        gold = run.data.rules.rewards[run.encounterTier .. "Gold"]
        assert(type(gold) == "number", "unknown encounter reward tier")
        if allEscaped then gold = 0 end
    end
    gold=GoldRewards.offerAmount(gold,run)
    local choices,nextCardRng,offset,cardUpgrades=CardPool.prepareRewards(run)
    run.cardRng,run.cardRarityOffset=nextCardRng,offset
    local potion,potionRng,potionModifier=PotionRewards.prepare(run,2,{allEscaped=allEscaped})
    PotionRewards.commit(run,potionRng,potionModifier)
    run.rewards, run.phase = { cards = choices, cardUpgrades = cardUpgrades, gold = gold, goldClaimed = gold == 0, potion = potion,
        cardResolved = false, manualContinue = true }, "reward"
    local stolen = run.combat.stolenGoldReward or 0
    if stolen > 0 then
        run.rewards.stolenGold = {type="STOLEN_GOLD", amount=stolen, claimed=false}
        run.rewards.cardResolved, run.rewards.manualContinue = false, true
    end
    run.victories = run.victories + 1
    if goldStream then run[goldStream] = nextGoldRng end
    return true
end

local function applyPermanentChanges(run)
    local battle=run.combat
    for _,card in ipairs(run.deck)do
        local changed=(battle.masterDeckChanges or {})[card.uid]
        if changed then
            assert(changed.uid==card.uid and changed.cardId==card.cardId,'invalid permanent card owner')
            local result=Combat.copy(changed)
            for key in pairs(card)do card[key]=nil end
            for key,value in pairs(result)do card[key]=value end
        end
        local growth=(battle.ritualDaggerGrowth or {})[card.uid]
        if card.cardId=='ritual_dagger' and growth then card.misc=(card.misc or 15)+growth end
        if changed or growth then
            for i,snapshot in ipairs(battle.masterDeck or {})do
                if snapshot.uid==card.uid then battle.masterDeck[i]=Combat.copy(card);break end
            end
        end
    end
    battle.ritualDaggerGrowth,battle.masterDeckChanges=nil,nil
    if battle.miscRng then run.miscRng=EventRandom.cloneState(battle.miscRng)end
    if run.phase=='combat' and battle.cardRng then run.cardRng=EventRandom.cloneState(battle.cardRng)end
end
function M.finishCombat(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    if not run.combat.roomSeed then
        local ok,reason=finishCombat(run);if ok then applyPermanentChanges(run)end;return ok,reason
    end
    -- A formal reward is one transaction: invalid source RNG or a later potion
    -- failure must not publish healed HP, card/treasure progress or lastResult.
    local staged = {}
    for key, value in pairs(run) do staged[key] = value end
    staged.shopRng = run.shopRng and Combat.copy(run.shopRng)
    local ok, reason = finishCombat(staged)
    if not ok then return false, reason end
    applyPermanentChanges(staged)
    for key in pairs(run) do run[key] = staged[key] end
    for key, value in pairs(staged) do run[key] = value end
    return true
end

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

function M.play(run, uid, targetIndex, commandId)
    if commandId~=nil and run.originalCommands then
        if type(commandId)~='string' or commandId==''then return false,'invalid_command_id'end
        local prior=run.originalCommands[commandId]
        if prior then return prior.uid==uid and prior.target==targetIndex,prior.uid==uid and prior.target==targetIndex and 'already_committed' or 'command_conflict'end
    end
    if commandId and run.combat and run.combat.originalV4 then
        local replay,why=require('abyss_original_v4').replay(run.combat,commandId,uid,targetIndex)
        if replay~=nil then return replay,why end
    end
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local ok, reason = Combat.play(run.combat, uid, targetIndex, commandId)
    if ok then
        syncBattlePotions(run)
        if commandId and run.originalCommands then run.originalCommands[commandId]={uid=uid,target=targetIndex,generation=run.roomGeneration}end
        run.gold = run.combat.player.gold
        run.relicCounters=Combat.copy(run.combat.relicCounters or {})
        applyPermanentChanges(run)
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok, reason
end

-- Selection commands carry a battle generation in addition to the per-battle
-- selection token. A delayed command from an old battle cannot choose new cards.
function M.chooseDiscard(run, uids, token, generation)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    if generation ~= run.combatGeneration then return false, "stale_combat_generation" end
    local ok,reason=Combat.chooseDiscard(run.combat,uids,token)
    if ok then
        syncBattlePotions(run)
        run.gold=run.combat.player.gold
        applyPermanentChanges(run)
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok,reason
end
function M.choosePile(run,uids,token,generation)
    if run.phase~='combat' then return false,'not_in_combat' end
    if generation~=run.combatGeneration then return false,'stale_combat_generation' end
    local ok,reason=Combat.choosePile(run.combat,uids,token,generation)
    if ok then
        syncBattlePotions(run)
        run.gold=run.combat.player.gold
        applyPermanentChanges(run)
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok,reason
end

function M.chooseScry(run, uids, token, generation)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    if generation ~= run.combatGeneration then return false, "stale_combat_generation" end
    local ok, reason = Combat.chooseScry(run.combat, uids, token)
    if ok then
        syncBattlePotions(run)
        run.gold = run.combat.player.gold
        applyPermanentChanges(run)
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok, reason
end

function M.chooseHand(run,uids,token,generation)
    if run.phase~="combat" then return false,"not_in_combat" end
    if generation~=run.combatGeneration then return false,"stale_combat_generation" end
    local ok,reason=Combat.chooseHand(run.combat,uids,token)
    if ok then
        syncBattlePotions(run)
        run.gold=run.combat.player.gold
        applyPermanentChanges(run)
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok,reason
end

function M.endTurn(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local restore=require('abyss_snapshot').capture(run)
    local called,ok,reason=pcall(function()
        local accepted,detail=Combat.endTurn(run.combat)
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
    if not called then restore();error(ok,0)end
    if not ok then restore()end
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
function M.potionCapacity(run)
    return run.potionSlots or run.data.rules.player.potionSlots
end
function M.potionCount(run)
    local count = 0
    for slot = 1, M.potionCapacity(run) do
        if run.potions[slot] then count = count + 1 end
    end
    return count
end

function M.obtainPotion(run, id)
    if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
    for _, owned in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, owned)
        if relic and relic.blocksPotions then return false, "potion_blocked_by_sozu" end
    end
    for slot = 1, M.potionCapacity(run) do
        if not run.potions[slot] then
            run.potions[slot] = id
            if run.phase=='combat' and run.combat then run.combat.potionInventory=Combat.copy(run.potions) end
            return true, slot
        end
    end
    return false, "potion_slots_full"
end

local function potionEventRestricted(run)
    local event=run.nodeFlow and run.nodeFlow.event
    local legacy=not run.nodeFlow and run.node
    return event and (event.id=='we_meet_again' or event.id=='WeMeetAgain' or event.originalId=='WeMeetAgain')
        or legacy and (legacy.eventId=='WeMeetAgain' or legacy.sourceEventId=='WeMeetAgain') or false
end
-- Discard never executes a potion effect and does not require a player turn.
function M.discardPotion(run, slot)
    if run.phase=='combat'and run.combat and run.combat.pendingPotionChoice then return false,'potion_choice_pending'end
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > M.potionCapacity(run) then
        return false, "invalid_potion_slot"
    end
    local id = run.potions[slot]
    if not id then return false, "empty_potion_slot" end
    if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
    if potionEventRestricted(run)then return false,'potion_event_restricted' end
    -- Like usePotion, a destructive transaction expires old physical gestures,
    -- even if the same bottle ID is immediately acquired in the vacant slot.
    run.potions = Combat.copy(run.potions)
    run.potions[slot] = nil
    if run.phase=='combat' and run.combat then run.combat.potionInventory=Combat.copy(run.potions) end
    return true
end

local function potionCandidate(run, slot, targetIndex, afterPotionActions)
    if potionEventRestricted(run)then return nil,'potion_event_restricted' end
    if run.phase ~= 'combat' and run.potions[slot]~='blood_potion' and run.potions[slot]~='fruit_juice' and run.potions[slot]~='entropic_brew' then return nil,'not_in_combat' end
    if run.phase == 'combat' then
        if not run.combat or run.combat.phase ~= 'player' then return nil,'not_player_turn' end
        if run.combat.pendingChoice or run.combat.cardActions or run.combat.pendingPotionChoice then return nil,'card_choice_pending' end
        if run.combat.pendingDiscard then return nil, 'unsupported_potion_during_discard' end
        if run.combat.pendingScry or run.combat.pendingPlay then return nil, 'unsupported_potion_during_selection' end
    end
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > M.potionCapacity(run) then
        return nil, "invalid_potion_slot"
    end
    local id = run.potions[slot]
    if not id then return nil, "empty_potion_slot" end
    local potion = find(run.data.potions.potions, id)
    if not potion then return nil, "unknown_potion" end
    if id=='fairy_in_a_bottle' then return nil,'automatic_potion' end
    local effects=Combat.copy(potion.effects)
    if RelicHooks.owns(run,'sacred_bark') or RelicHooks.owns(run,'SacredBark') then
        for _,effect in ipairs(effects)do
            if effect.value and effect.op~='escape' and effect.op~='generatePotions' and effect.op~='randomizeHandCost' then
                effect.value=effect.value*2.0
            end
        end
    end
    if id=='smoke_bomb' and run.combat then
        for _,enemy in ipairs(run.combat.enemies) do
            local def=run.combat.catalog.enemies[enemy.definitionId]
            if def and def.tier=='boss' or (enemy.statuses.back_attack or 0)>0 then return nil,'smoke_not_allowed' end
        end
    end
    local health = id=='blood_potion' or id=='fruit_juice'
    local outsideAllowed=health or id=='entropic_brew'
    if run.phase ~= 'combat' then
        if not outsideAllowed or (run.phase~='map' and run.phase~='node' and run.phase~='reward') then return nil,'not_in_combat' end
        local candidate={hp=run.hp,maxHp=run.maxHp,outside=true}
        if id=='entropic_brew' then
            local called,ids,rng=pcall(require('abyss_potion_generation').prepare,run,false)
            if not called then return nil,'potion_effect_failed'end
            candidate.potionInventory=Combat.copy(run.potions);candidate.potionInventory[slot]=nil
            candidate.potionRandomRng=rng
            candidate.generatedPotionOffers={}
            for _,generated in ipairs(ids)do
                local available=require('abyss_potion_generation').available(run,generated)
                candidate.generatedPotionOffers[#candidate.generatedPotionOffers+1]={id=generated,unavailable=not available}
                if available then require('abyss_potion_generation').obtain(candidate.potionInventory,M.potionCapacity(run),generated,false)end
            end
        else for _,e in ipairs(effects) do
            local ok,reason=require('abyss_potion_health').apply(candidate,e.op,e.value,run.relics,false)
            if not ok then return nil,reason end
        end end
        candidate.relics=run.relics
        RelicHooks.onUsePotion(candidate)
        return candidate
    end
    local candidate = Combat.copy(run.combat)
    candidate.potionRng=run.shopRng and EventRandom.cloneState(run.shopRng.potion)or EventRandom.fromSeed(run.runSeed)
    candidate.potionInventory=Combat.copy(run.potions)
    local called, ok, reason = pcall(function()
        local applied,why=Inventory.apply(candidate,effects,targetIndex,run,true)
        if not applied then return false,why end
        -- Integration point for COMBAT onUsePotion hooks: append their actions
        -- on the staged battle, after Potion.use and before a single drain.
        RelicHooks.onUsePotion(run,candidate)
        candidate.potionInventory[slot]=nil
        if afterPotionActions then afterPotionActions(candidate) end
        require('abyss_card_actions').drain(Combat,candidate)
        return true
    end)
    if not called then return nil, "potion_effect_failed" end
    if not ok then return nil, reason end
    return candidate
end

function M.usePotion(run, slot, targetIndex, afterPotionActions)
    if afterPotionActions~=nil and type(afterPotionActions)~='function' then return false,'invalid_potion_hook' end
    local battle, reason = potionCandidate(run, slot, targetIndex,afterPotionActions)
    if not battle then return false, reason end
    if battle.outside then
        run.hp,run.maxHp=battle.hp,battle.maxHp
        if run.combat then run.combat.player.hp,run.combat.player.maxHp=run.hp,run.maxHp end
        run.potions=Combat.copy(battle.potionInventory or run.potions)
        if not battle.potionInventory then run.potions[slot]=nil end
        if battle.potionRandomRng then
            run.shopRng=run.shopRng and Combat.copy(run.shopRng) or {merchant=EventRandom.fromSeed(run.runSeed)}
            run.shopRng.potion=battle.potionRandomRng
        end
        if battle.generatedPotionOffers then run.lastPotionGeneration=Combat.copy(battle.generatedPotionOffers)end
        return true
    end
    require("abyss_events").emit(battle, "potion", { slot = slot, id = run.potions[slot], target = targetIndex })
    local outcome = Combat.outcome(battle)
    if outcome then
        battle.phase = outcome
        require("abyss_events").emit(battle, outcome, {allEnemiesEscaped=Combat.allEnemiesEscaped(battle), mugged=battle.mugged})
    end
    -- Stage the complete transaction, including rewards and their RNG, before committing.
    -- Persistent deck UIDs are owned by Run and are never regenerated from combat instances.
    local candidate = {}
    for key, value in pairs(run) do candidate[key] = value end
    candidate.combat, candidate.potions, candidate.gold = battle, Combat.copy(battle.potionInventory), battle.player.gold
    candidate.deck=(battle.ritualDaggerGrowth or battle.masterDeckChanges) and Combat.copy(run.deck) or run.deck
    candidate.hp,candidate.maxHp=battle.player.hp,battle.player.maxHp
    candidate.relicCounters=Combat.copy(battle.relicCounters)
    if battle.generatedPotionOffers then candidate.lastPotionGeneration=Combat.copy(battle.generatedPotionOffers)end
    if battle.potionRandomRng then
        candidate.shopRng=run.shopRng and Combat.copy(run.shopRng) or {merchant=EventRandom.fromSeed(run.runSeed)}
        candidate.shopRng.potion=EventRandom.cloneState(battle.potionRng or battle.potionRandomRng)
        battle.potionRandomRng=nil
    end
    if battle.potionRngChanged then
        candidate.shopRng=candidate.shopRng and Combat.copy(candidate.shopRng)or {merchant=EventRandom.fromSeed(run.runSeed)}
        candidate.shopRng.potion=EventRandom.cloneState(battle.potionRng);battle.potionRngChanged=nil
    end
    if battle.smoked then
        battle.phase='escaped'
        candidate.phase,candidate.rewards,candidate.pendingCombatRewards='map',nil,nil
        candidate.lastResult={outcome='escaped',turn=battle.turn,encounterId=run.encounterId}
    end
    if outcome then
        -- Reward preparation commits the continuous potion stream. Do not let
        -- an exception mutate a table still owned by the live run.
        candidate.shopRng = run.shopRng and Combat.copy(run.shopRng)
        local called, ok = pcall(M.finishCombat, candidate)
        if not called or not ok then return false, "potion_effect_failed" end
    end
    applyPermanentChanges(candidate)
    local root = run.combat
    for key in pairs(root) do root[key] = nil end
    for key, value in pairs(battle) do root[key] = value end
    candidate.combat = root
    for key, value in pairs(candidate) do run[key] = value end
    return true
end

-- Detached UI description. A targeted bottle is usable if at least one legal target exists;
-- usePotion still validates the selected target when the command arrives.
-- Indexed by physical slot, with nil vacancies; do not iterate/count with ipairs/#.
function M.potionView(run)
    local result = {}
    for slot = 1, M.potionCapacity(run) do
        local id = run.potions[slot]
        if id then
            local potion = find(run.data.potions.potions, id)
            local needTarget = potion and potion.targetPolicy == "enemy_one" or false
            local candidate, reason
            if needTarget and run.combat then
                for index, enemy in ipairs(run.combat.enemies) do
                    if require("abyss_actor").isActive(enemy) then
                        candidate, reason = potionCandidate(run, slot, index)
                        if candidate then break end
                    end
                end
            end
            if not candidate and not reason then candidate, reason = potionCandidate(run, slot) end
            result[slot] = { slot = slot, id = id, name = potion and potion.name or id,
                targetPolicy = potion and potion.targetPolicy,
                effects = potion and Combat.copy(potion.effects) or {}, needTarget = needTarget,
                canUse = candidate ~= nil, canDiscard=not potionEventRestricted(run), reason = reason }
        end
    end
    return result
end

return M
