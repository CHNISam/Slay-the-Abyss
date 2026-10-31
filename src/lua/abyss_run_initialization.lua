-- Initialization responsibility for the same-run API.
local Combat = require("abyss_combat")
local EventRandom = require("abyss_sts_random")
local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local RunSeed = require("abyss_run_seed")
local EncounterQueue = require("abyss_encounter_queue")
local CardRandom = require("abyss_card_random")
local RelicPool = require('abyss_relic_pool')

local M = {}

function M.install(Run, shared)
    local preparedCharacters=shared.preparedCharacters
    local preparedOriginalRoles=shared.preparedOriginalRoles
    local function prepareProfile(data, options)
        local profile,ownsData
        if options ~= nil then
            assert(type(options)=='table','invalid character options')
            assert(options.campaign==nil or type(options.campaign)=='boolean','invalid campaign option')
            assert(options.campaignProfile==nil or options.campaign==true
                and (options.campaignProfile=='competition-two-act' or options.campaignProfile=='full-source'),
                'invalid campaign profile')
            assert(not options.campaign or options.experimental==true,
                'campaign requires explicit experimental mode')
            assert(require('abyss_run_admission').accepts(data,options),'competition_character_unavailable')
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
        return data, profile, ownsData
    end

    local function prepareCatalog(sourceData, data, profile, ownsData, options)
        local ownsCatalog
        local legacyPrepared=not profile and (not options or options.character==nil) and
            (preparedCharacters[data.experimentalCharacter] and data.characterId==data.experimentalCharacter
            or preparedOriginalRoles[data.originalV4Role] and type(data.originalV4Rules)=='table')
        if not legacyPrepared and not (profile and profile.originalV4)then
            data=require('abyss_run_card_catalog').prepare(sourceData,data,profile and profile.id,ownsData)
            ownsData,ownsCatalog=true,true
        end
        return data, ownsData, ownsCatalog, legacyPrepared
    end

    local function finishCatalog(run, ownsCatalog)
        local sources=run.data.cards.sourcePools
        sources.cardSourceMetadata=sources.cardSourceMetadata or {}
        if ownsCatalog then
            require('abyss_run_card_catalog').finishMetadata(run.data)
        else
            for _,card in ipairs(run.data.cards.cards)do
                if not sources.cardSourceMetadata[card.id] then
                    sources.cardSourceMetadata[card.id]={sourceId=card.sourceId or card.sts_name or card.id,
                        rarity=card.rarity,type=card.type,healing=card.healing==true}
                end
            end
        end
    end

    local function initializeRelicPool(run, data, profile, legacyPrepared, runData, eventSeed)
        if data.relicSource then
            -- RelicLibrary.populateRelicPool appends the chosen class library to
            -- shared relics before the same five shuffles. Original V4 has no
            -- declared STS class mapping and retains its existing source contract.
            local class=profile and not profile.originalV4 and profile.id or legacyPrepared and data.characterId
            if class and class~='ironclad' and preparedCharacters[class]then
                local classCatalogs=assert(runData.classRelicSources,'missing class relic catalogs')
                runData.relicSource=assert(classCatalogs[class],'missing class relic source')
            end
            run.relicPool=RelicPool.new(eventSeed,runData.relicSource)
        end
    end

    function Run.new(data, seed, options)
        local sourceData=data
        local profile,ownsData,ownsCatalog
        data,profile,ownsData=prepareProfile(data,options)
        -- Historical Profile.prepare(data,id) -> Run.new(prepared,seed) accepts
        -- an already filtered/adapted component, without inferring a Run profile.
        local legacyPrepared
        data, ownsData, ownsCatalog, legacyPrepared = prepareCatalog(sourceData, data, profile, ownsData, options)
        data=require('abyss_colorless_cards').withCards(data,ownsCatalog)
        local eventSeed = RunSeed.normalize(seed)
        local cardOwner = CardRandom.new(eventSeed)
        -- Profile factories already detached the whole input graph. Their private
        -- result can be adopted; caller-owned/default bundles still need a copy.
        local runData=ownsData and data or Combat.copy(data)
        if legacyPrepared then
            -- These new internal markers are not legacy rules or ownership proof.
            -- Clear only the detached graph, preserving the old combat defaults.
            runData.runCardCatalog,runData.runCardCharacter=nil,nil
        end
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
            scoreStats = require("abyss_run_score").newStats(data.rules.player.maxHp),
            gold = data.rules.player.startingGold, deck = {}, nextDeckUid = 1,
            relics = Combat.copy(data.rules.player.startingRelics), potions = {} }
        finishCatalog(run, ownsCatalog)
        if profile then run.character, run.characterProfile = profile.id, Combat.copy(profile) end
        if profile and profile.originalV4 then run.originalCommands={}end
        if options and options.campaign then
            run.campaign,run.act,run.keys=true,1,{ruby=false,emerald=false,sapphire=false}
            run.campaignProfile=options.campaignProfile or 'full-source'
            run.unknown.pools=EventPool.new('full')
        end
        for _, id in ipairs(data.cards.starter_deck.cards) do
            run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = id, upgraded = false }
            run.nextDeckUid = run.nextDeckUid + 1
        end
        initializeRelicPool(run, data, profile, legacyPrepared, runData, eventSeed)
        return run
    end


end

return M
