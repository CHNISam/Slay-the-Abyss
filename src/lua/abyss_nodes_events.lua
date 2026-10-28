-- Event display and ordered commands installed on the original Nodes service.
local Run = require("abyss_run")

local EventRandom = require("abyss_sts_random")

local LivingWall = require('abyss_living_wall')
local Fountain = require('abyss_fountain')

local Act1Events = require('abyss_act1_events')
local Act2Events = require('abyss_act2_events')
local Act3Events = require('abyss_act3_events')

local Neow=require('abyss_neow')

local Common=require('abyss_nodes_common')
local find=Common.find

local upgradeable,upgradeCards=Common.upgradeable,Common.upgradeCards
local healingPreview=Common.healingPreview
local pending,complete=Common.pending,Common.complete

return function(M)
    local legacyOptions={
        living_wall=function(run,_e,option,rows,upgrades,_deckOk)
            option('forget','遗忘','移除一张卡牌',true,#LivingWall.purgeCards(run)>0 and 'living_forget' or nil)
            option('change','改变','将一张卡牌变换为随机的新卡牌',true,#LivingWall.purgeCards(run)>0 and 'living_change' or nil)
            option('grow','成长','升级一张卡牌',upgrades>0,#LivingWall.purgeCards(run)>0 and 'living_grow' or nil)
            return rows
        end,
        fountain=function(_run,_e,option,_rows,_upgrades,_deckOk)
            option('cleanse','净化','移除牌组中所有可清除的诅咒。')
        end,
        cleric=function(run,_e,option,_rows,_upgrades,deckOk)
            local r=run.data.rules.events.cleric
            local heal=healingPreview(run,math.floor(run.maxHp*r.healPercent/100))
            option('heal','治疗','支付 '..r.healCost..' 金币，回复 '..heal..' 点生命',run.gold>=r.healCost)
            option('purify','净化','支付 '..r.removeCost..' 金币，移除一张卡牌',run.gold>=r.removeCost and deckOk,'purify')
        end,
        purifier=function(_run,_e,option,_rows,_upgrades,deckOk)
            option('pray','祈祷','免费移除一张卡牌',deckOk,'purify')
        end,
        upgrade_shrine=function(_run,_e,option,_rows,upgrades,_deckOk)
            option('upgrade','升级',upgrades>0 and '免费升级一张卡牌' or '牌组没有可升级的卡牌',upgrades>0,'event_upgrade')
        end,
        golden_shrine=function(run,_e,option,_rows,_upgrades,_deckOk)
            local r=run.data.rules.events.golden_shrine
            local curse=find(run.data.cards.cards,r.curse)
            option('pray','领受馈赠','获得 '..r.gold..' 金币')
            option('desecrate','取走供物','获得 '..r.curseGold..' 金币，并将诅咒「'..(curse and curse.name or 'Regret')..'」加入牌组')
        end,
        goop=function(run,e,option,rows,_upgrades,_deckOk)
            local r=run.data.rules.events.goop
            option('gather','拾取金币','受到 '..r.damage..' 点伤害，获得 '..r.gold..' 金币')
            option('leave','离开','失去 '..e.goldLoss..' 金币');return rows
        end,
        shining_light=function(run,e,option,_rows,upgrades,_deckOk)
            option('accept','触碰光芒',upgrades>0 and ('受到 '..e.damage..' 点伤害，随机升级最多 '..run.data.rules.events.shining_light.upgradeCount..' 张卡牌') or '牌组没有可升级的卡牌',upgrades>0)
        end,
        golden_wing=function(run,e,option,rows,_upgrades,deckOk)
            local r=run.data.rules.events.golden_wing
            if e.stage=='purge' then
                option('purge','移除卡牌','已支付 '..r.damage..' 点生命；选择一张卡牌移除',deckOk,'wing_purge');return rows
            end
            option('sacrifice','献出生命','受到 '..r.damage..' 点伤害，然后选择移除一张卡牌')
            option('take_gold','击碎雕像','获得 '..r.goldMin..'–'..r.goldMax..' 金币；需要基础伤害至少 '..r.attackThreshold..' 的攻击牌',e.canAttack)
        end,
    }

    function M.eventOptions(run,flow)
        local id,e=flow.event.id,flow.event
        if id=='neow'then return Neow.options(run,e)end
        if Act1Events.ids[id] then return Act1Events.options(run,e,upgradeCards) end
        if Act2Events.ids[id] then return Act2Events.options(run,e) end
        if Act3Events.ids[id] then return Act3Events.options(run,e) end
        local rows={}
        local function option(choice,title,description,enabled,picker)
            rows[#rows+1]={choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
        end
        local upgrades=#upgradeCards(run)
        local deckOk=#LivingWall.purgeCards(run)>0
        local options=legacyOptions[id]
        if options then
            local result=options(run,e,option,rows,upgrades,deckOk)
            if result then return result end
        end
        option('leave','离开','什么也不会发生。')
        return rows
    end

    local function damage(run,amount) local ok,why=Run.eventDamage(run,amount);assert(ok,why) end

    local function invalidCurseIdentity(curse)
        return not curse or curse.id~='regret' or curse.type~='curse' or curse.rarity~='curse'
                or curse.cost~=-2 or type(curse.effects)~='table' or next(curse.effects)~=nil

    end

    local function invalidCurse(curse)
        return invalidCurseIdentity(curse) or curse.upgrade~=nil or curse.condition~=nil or curse.costMode~=nil
                or curse.ethereal or curse.exhaust or curse.innate or curse.repeatable
    end

    local legacyChoices={
        {matches=function(id,choice,_flow)return choice == "heal" and id == "cleric" end,
         apply=function(run,_flow,_uid,rules)
            if run.gold < rules.healCost then return false, "insufficient_gold" end
            run.gold = run.gold - rules.healCost
            Run.heal(run,math.floor(run.maxHp * rules.healPercent / 100))
         end},
        {matches=function(id,choice,_flow)return (choice == "purify" and id == "cleric") or (choice == "pray" and id == "purifier") end,
         apply=function(run,_flow,uid,rules)
            local instance = find(run.deck, uid, "uid")
            if not instance then return false, "invalid_card" end
            if not find(LivingWall.purgeCards(run),uid,'uid') then return false,'card_not_purgeable' end
            if run.gold < rules.removeCost then return false, "insufficient_gold" end
            local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
            run.gold = run.gold - rules.removeCost
         end},
        {matches=function(id,choice,_flow)return choice=='pray' and id=='golden_shrine' end,
         apply=function(run,_flow,_uid,rules)
            Run.gainGold(run,rules.gold)
         end},
        {matches=function(id,choice,_flow)return choice=='desecrate' and id=='golden_shrine' end,
         apply=function(run,flow,_uid,rules)
            local curse=find(run.data.cards.cards,rules.curse)
            -- Preflight the sole supported curse ABI and permanent identity before paying gold.
            if invalidCurse(curse) then
                return false,'event_content_unavailable'
            end
            local offer,why=Run.prepareCard(run,curse.id);if not offer then return false,why end
            Run.gainGold(run,rules.curseGold)
            local ok,obtained=Run.commitCard(run,offer);if not ok then return false,obtained end
            flow.event.obtainedCardUid=type(obtained)=='number' and obtained or nil
            flow.event.cursePrevented=obtained=='curse_blocked' or nil
         end},
        {matches=function(id,choice,_flow)return choice=='gather' and id=='goop' end,
         apply=function(run,_flow,_uid,rules)
            damage(run,rules.damage);Run.gainGold(run,rules.gold)
         end},
        {matches=function(id,choice,_flow)return choice=='leave' and id=='goop' end,
         apply=function(run,flow,_uid,_rules)
            run.gold=math.max(0,run.gold-flow.event.goldLoss)
         end},
        {matches=function(id,choice,_flow)return choice=='upgrade' and id=='upgrade_shrine' end,
         apply=function(run,flow,uid,_rules)
            local instance=find(run.deck,uid,'uid')
            if not instance then return false,'invalid_card' end
            if not upgradeable(run,instance) then return false,'card_not_upgradeable' end
            instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
            instance.upgraded=true;flow.event.upgradedUids={uid}
         end},
        {matches=function(id,choice,_flow)return choice=='accept' and id=='shining_light' end,
         apply=function(run,flow,_uid,rules)
            local cards=upgradeCards(run)
            if #cards==0 then return false,'card_not_upgradeable' end
            local rng=EventRandom.cloneState(run.miscRng)
            EventRandom.shuffle(rng,cards)
            damage(run,flow.event.damage)
            flow.event.upgradedUids={}
            for i=1,math.min(rules.upgradeCount,#cards) do
                local instance=find(run.deck,cards[i].uid,'uid')
                instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
                instance.upgraded=true
                flow.event.upgradedUids[#flow.event.upgradedUids+1]=cards[i].uid
            end
            run.miscRng=rng
         end},
        {matches=function(id,choice,_flow)return choice=='sacrifice' and id=='golden_wing' end,
         apply=function(run,flow,_uid,rules)
            damage(run,rules.damage);flow.event.stage='purge'
            -- An empty purge group cannot keep the event waiting for a nonexistent UID.
            if run.hp>0 and #LivingWall.purgeCards(run)>0 then return true,'choose_purge' end
         end},
        {matches=function(id,choice,_flow)return choice=='take_gold' and id=='golden_wing' end,
         apply=function(run,flow,_uid,rules)
            if not flow.event.canAttack then return false,'event_condition_unmet' end
            local rng=EventRandom.cloneState(run.miscRng)
            local gold=EventRandom.randomIntBetween(rng,rules.goldMin,rules.goldMax)
            Run.gainGold(run,gold);run.miscRng=rng
         end},
        {matches=function(id,choice,flow)return choice=='purge' and id=='golden_wing' and flow.event.stage=='purge' end,
         apply=function(run,_flow,uid,_rules)
            local instance=find(run.deck,uid,'uid')
            if not instance then return false,'invalid_card' end
            if not find(LivingWall.purgeCards(run),uid,'uid') then return false,'card_not_purgeable' end
            local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
         end},
    }

    local function chooseLegacy(run,flow,choice,uid,rules)
        for _,command in ipairs(legacyChoices)do
            if command.matches(flow.event.id,choice,flow)then return command.apply(run,flow,uid,rules)end
        end
        if choice~='leave'then return false,'invalid_event_choice'end
    end

    local function chooseLivingWall(run,flow,choice,uid)
        local ok,status=LivingWall.choose(run,flow,choice,uid,upgradeable,upgradeCards)
        if not ok or status=='choose_card' then return ok,status end
        flow.eventChoice=choice
        return complete(run)
    end

    local function chooseAct1(run,flow,choice,uid)
        local ok,status=Act1Events.choose(run,flow,choice,uid,upgradeable,upgradeCards)
        if ok and status=='event_combat'then return Run.startEventCombat(run)end
        if ok and run.hp==0 then
            run.nodeFlow.eventChoice=choice
            complete(run);run.phase='defeat';return true,'defeat'
        end
        if not ok or status~='complete' then return ok,status end
        run.nodeFlow.eventChoice=choice
        return complete(run)
    end

    local function chooseAct3(run,flow,choice,uid)
        local ok,status=Act3Events.choose(run,flow,choice,uid)
        if ok and status=='event_combat'then return Run.startEventCombat(run)end
        if ok and run.hp==0 then
            flow.eventChoice=choice;complete(run);run.phase='defeat';return true,'defeat'
        end
        if not ok or status~='complete'then return ok,status end
        flow.eventChoice=choice;return complete(run)
    end

    local function chooseAct2(run,flow,choice,uid)
        local ok,status=Act2Events.choose(run,flow,choice,uid,upgradeable)
        if ok and run.hp==0 then
            flow.eventChoice=choice;complete(run);run.phase='defeat';return true,'defeat'
        end
        if not ok or status~='complete' then return ok,status end
        flow.eventChoice=choice
        return complete(run)
    end

    local function chooseNeow(run,flow,choice,uid)
        local ok,status=Neow.choose(run,flow,choice,uid)
        if not ok or status~='complete'then return ok,status end
        flow.eventChoice=choice;run.neowStatus='complete'
        return complete(run)
    end

    local function chooseFountain(run,flow,choice)
        local ok,why=Fountain.cleanse(run,flow)
        if not ok then return false,why end
        flow.eventChoice=choice
        return complete(run)
    end

    local function chooseEvent(run, choice, uid)
        local flow, reason = pending(run, "event"); if not flow then return false, reason end
        local id = flow.event.id
        if id=='neow' then return chooseNeow(run,flow,choice,uid)end
        local rules = run.data.rules.events[id] or {}
        if Act2Events.ids[id] then return chooseAct2(run,flow,choice,uid)end
        if Act3Events.ids[id] then return chooseAct3(run,flow,choice,uid)end
        if Act1Events.ids[id] then return chooseAct1(run,flow,choice,uid)end
        if id=='living_wall' then return chooseLivingWall(run,flow,choice,uid)end
        if id=='fountain' and choice=='cleanse' then return chooseFountain(run,flow,choice)end
        if id=='golden_wing' and flow.event.stage=='purge' and choice~='purge' then return false,'invalid_event_choice' end
        local accepted,status=chooseLegacy(run,flow,choice,uid,rules)
        if accepted~=nil then return accepted,status end
        flow.eventChoice = choice
        local ok,result=complete(run)
        if run.hp==0 then run.phase='defeat' end
        return ok,result
    end

    function M.chooseEvent(run,choice,uid)
        return Run.transaction(run,function(staged)return chooseEvent(staged,choice,uid)end)
    end

    function M.upgradeEvent(run,uid) return M.chooseEvent(run,'upgrade',uid) end
    function M.chooseAct2EventCard(run,uid)
        local flow,reason=pending(run,'event');if not flow then return false,reason end
        if not Act2Events.ids[flow.event.id] or flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
        return M.chooseEvent(run,flow.event.choice,uid)
    end
    function M.chooseAct1EventCard(run,uid)
        local flow,reason=pending(run,'event');if not flow then return false,reason end
        if not Act1Events.ids[flow.event.id] or flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
        return M.chooseEvent(run,flow.event.choice,uid)
    end
    function M.chooseLivingWallCard(run,uid)
        local flow,reason=pending(run,'event');if not flow then return false,reason end
        if flow.event.id~='living_wall' or flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
        return M.chooseEvent(run,flow.event.choice,uid)
    end
    function M.purgeWing(run,uid) return M.chooseEvent(run,'purge',uid) end

    function M.purifyEvent(run, uid)
        local flow = run.nodeFlow
        return M.chooseEvent(run, flow and flow.event and flow.event.id == "purifier" and "pray" or "purify", uid)
    end

end
