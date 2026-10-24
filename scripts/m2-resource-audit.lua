-- Real composed Run/Nodes route: unchanged production data, no seeded inventory,
-- no Map.choose shortcuts, no floor/HP/gold writes. This is offline evidence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local C=require('abyss_combat')
local data=require('abyss_data')
local Policy=dofile('scripts/m2-autoplay-policy.lua')
local function json(value)
    if type(value)=='nil' then return 'null' end
    if type(value)=='boolean' or type(value)=='number' then return tostring(value) end
    if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
        return c=='"' and '\\"' or c=='\\' and '\\\\' or string.format('\\u%04x',string.byte(c)) end)..'"' end
    local keys,n,array={},0,true
    for k in pairs(value) do keys[#keys+1]=k;n=n+1;if type(k)~='number' then array=false end end
    local result={}
    if array and #value==n then for _,v in ipairs(value) do result[#result+1]=json(v) end
        return '['..table.concat(result,',')..']' end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do result[#result+1]=json(tostring(k))..':'..json(value[k]) end
    return '{'..table.concat(result,',')..'}'
end
local function snapshot(run,map)
    local deck,potions,seen={},{},{}
    for _,card in ipairs(run.deck) do
        assert(not seen[card.uid],'duplicate permanent UID');seen[card.uid]=true
        assert(card.uid<run.nextDeckUid,'permanent UID exceeds allocator')
        deck[#deck+1]={uid=card.uid,cardId=card.cardId,upgraded=card.upgraded}
    end
    for slot=1,run.data.rules.player.potionSlots do potions[#potions+1]={slot=slot,id=run.potions[slot] or false} end
    return {phase=run.phase,floor=run.floor,mapFloor=map.floor,hp=run.hp,maxHp=run.maxHp,gold=run.gold,
        deck=deck,nextDeckUid=run.nextDeckUid,relics=C.copy(run.relics),potions=potions,
        seed=run.seed,eventRng=C.copy(run.eventRng),miscRng=C.copy(run.miscRng),unknown=C.copy(run.unknown),
        shopRng=C.copy(run.shopRng),potionChanceModifier=run.potionChanceModifier,
        path=C.copy(map.path),nodeFlow=C.copy(run.nodeFlow),shopRemoveCount=run.shopRemoveCount}
end
local cardRank=Policy.scoreCard
local function action(run) local _,_,choice=Policy.chooseCombat(run);return choice end
local function runSeed(seed)
    local run,map=Run.new(data,seed),Map.generate(data,seed)
    local result={seed=seed,rows={},actions={},rejections={},coverage={},status='running'}
    local fresh=json(snapshot(run,map))
    local function reject(label,fn)
        local before=json(snapshot(run,map))
        local ok,reason=fn()
        assert(not ok,label..' unexpectedly succeeded')
        assert(json(snapshot(run,map))==before,label..' mutated resources or navigation')
        result.rejections[#result.rejections+1]={floor=run.floor,action=label,reason=reason}
    end
    local function transaction(label,fn)
        local before=snapshot(run,map)
        local ok,reason=fn();assert(ok,label..': '..tostring(reason))
        result.rows[#result.rows+1]={action=label,before=before,after=snapshot(run,map)}
        result.coverage[label]=(result.coverage[label] or 0)+1
    end
    local function battle()
        local turns,plays=0,0
        while run.phase=='combat' and turns<80 and plays<800 do
            local choice=action(run)
            local a={floor=run.floor,turn=run.combat.turn,playerHp=run.combat.player.hp,
                energy=run.combat.energy,encounter=run.encounterId,handCount=#run.combat.hand,
                enemyCount=#run.combat.enemies,enemies={}}
            for i,e in ipairs(run.combat.enemies) do a.enemies[i]={index=i,id=e.definitionId,hp=e.hp,block=e.block} end
            if choice then
                a.action='play';a.cardId=choice.cardId;a.cardUid=choice.uid;a.targetIndex=choice.target
                for index,c in ipairs(run.combat.hand) do if c.uid==choice.uid then a.handIndex=index;break end end
                a.ok,a.reason=Run.play(run,choice.uid,choice.target);assert(a.ok);plays=plays+1
            else a.action='end_turn';a.ok,a.reason=Run.endTurn(run);assert(a.ok);turns=turns+1 end
            a.phaseAfter=run.phase;a.hpAfter=run.combat and run.combat.player.hp or run.hp
            result.actions[#result.actions+1]=a
        end
        assert(run.phase~='combat','strategy action/turn budget exhausted')
        if run.phase=='defeat' then result.status='defeat';return false end
        reject('complete_before_reward',function() return Nodes.completeCombat(run,map) end)
        local best,rank=0,28
        for i,id in ipairs(Run.rewardOptions(run)) do local r=cardRank(run,id);if r>rank then best,rank=i,r end end
        local offer=run.rewards.potion
        if offer and not offer.resolved then
            if offer.unavailable or Run.potionCount(run)>=run.data.rules.player.potionSlots then
                transaction('skip_potion',function() return Run.skipPotionReward(run) end)
            else transaction('claim_potion',function() return Run.claimPotionReward(run) end) end
        end
        transaction('card_reward',function() return Run.claimCardReward(run,best) end)
        reject('duplicate_card_reward',function() return Run.claimCardReward(run,best) end)
        transaction('complete_combat',function() return Nodes.completeCombat(run,map) end)
        reject('duplicate_complete_combat',function() return Nodes.completeCombat(run,map) end)
        return true
    end
    while map.floor<17 do
        local available=Nodes.available(run,map)
        if #available==0 then result.status='no_legal_next_node';break end
        local chosen=Policy.chooseNode(run,map,result.coverage)
        if chosen.floor>(M2_STOP_AFTER or 17) then result.status='stopped_before_floor_'..chosen.floor;break end
        local before=snapshot(run,map)
        local ok,reason=Nodes.enter(run,map,chosen.id)
        if not ok then
            assert(json(snapshot(run,map))==json(before),'failed entry mutated run/map')
            result.status='entry_rejected';result.blocker={node=chosen,reason=reason};break
        end
        result.coverage[run.nodeFlow.type]=(result.coverage[run.nodeFlow.type] or 0)+1
        result.rows[#result.rows+1]={action='enter',node=chosen,resolvedType=run.nodeFlow.type,
            encounter=run.encounterId,before=before,after=snapshot(run,map)}
        reject('duplicate_enter',function() return Nodes.enter(run,map,chosen.id) end)
        if run.phase=='combat' then
            if not battle() then break end
        elseif run.nodeFlow.type=='camp' then
            if not result.coverage.rest or run.hp<run.maxHp*.55 then
                local hp=run.hp
                transaction('rest',function() return Nodes.rest(run) end)
                assert(run.hp==math.min(run.maxHp,hp+math.floor(run.maxHp*data.rules.camp.healPercent/100)))
                reject('duplicate_rest',function() return Nodes.rest(run) end)
            else
                local choices=Nodes.view(run,map).node.upgradeCards
                local card=choices[1]
                for _,c in ipairs(choices) do if c.cardId=='bash' or cardRank(run,c.cardId)>cardRank(run,card.cardId) then card=c end end
                if card then
                    transaction('upgrade',function() return Nodes.upgrade(run,card.uid) end)
                    reject('duplicate_upgrade',function() return Nodes.upgrade(run,card.uid) end)
                else transaction('rest',function() return Nodes.rest(run) end) end
            end
        elseif run.nodeFlow.type=='shop' then
            local view=Nodes.view(run,map).node
            local chosenOffer,rank=nil,30
            for _,offer in ipairs(view.cards) do
                if not offer.unavailable and not offer.sold and offer.price<=run.gold then
                    local r=cardRank(run,offer.id);if r>rank then chosenOffer,rank=offer,r end
                end
            end
            if chosenOffer then
                local gold,uid=run.gold,run.nextDeckUid
                transaction('buy_card',function() return Nodes.buyCard(run,chosenOffer.id) end)
                assert(run.gold==gold-chosenOffer.price and run.deck[#run.deck].uid==uid)
                if not run.nodeFlow.shopRng then reject('duplicate_buy_card',function() return Nodes.buyCard(run,chosenOffer.id) end) end
            end
            view=Nodes.view(run,map).node
            if not result.coverage.remove_card and view.removeAvailable and run.gold>=view.removePrice then
                local uid
                for _,card in ipairs(run.deck) do if card.cardId=='strike' then uid=card.uid;break end end
                if uid then
                    local gold=run.gold
                    transaction('remove_card',function() return Nodes.removeCard(run,uid) end)
                    assert(run.gold==gold-view.removePrice)
                    reject('duplicate_remove_card',function() return Nodes.removeCard(run,uid) end)
                end
            end
            view=Nodes.view(run,map).node
            if Nodes.buyPotion and Run.potionCount(run)<run.data.rules.player.potionSlots then
                for slot,offer in ipairs(view.potions or {}) do
                    if not offer.unavailable and not offer.sold and offer.price<=run.gold then
                        transaction('buy_potion',function() return Nodes.buyPotion(run,slot) end);break
                    end
                end
            end
            transaction('leave_shop',function() return Nodes.leaveShop(run) end)
            reject('duplicate_leave_shop',function() return Nodes.leaveShop(run) end)
        elseif run.nodeFlow.type=='event' then
            local id=run.nodeFlow.event.id
            local choice,uid='leave',nil
            if id=='golden_shrine' then choice='pray'
            elseif id=='goop' then choice=run.hp>35 and 'gather' or 'leave'
            elseif id=='cleric' and run.hp<55 and run.gold>=35 then choice='heal'
            elseif id=='purifier' then choice='pray';uid=run.deck[1].uid
            elseif id=='upgrade_shrine' then
                for _,c in ipairs(Nodes.view(run,map).node.upgradeCards) do choice='upgrade';uid=c.uid;if c.cardId=='bash' then break end end
            end
            transaction('event_'..id..'_'..choice,function() return Nodes.chooseEvent(run,choice,uid) end)
            reject('duplicate_event',function() return Nodes.chooseEvent(run,choice,uid) end)
        elseif run.nodeFlow.type=='treasure' then
            if chosen.roomKind=='boss_treasure' and Nodes.claimBossRelic then
                transaction('boss_treasure',function() return Nodes.claimBossRelic(run,1) end)
            else transaction('treasure',function() return Nodes.claimTreasure(run) end)
                reject('duplicate_treasure',function() return Nodes.claimTreasure(run) end)
            end
        end
    end
    if map.floor==17 and run.nodeFlow.complete then result.status='offline_route_complete' end
    result.final=snapshot(run,map)
    local restarted,restartedMap=Run.new(data,seed),Map.generate(data,seed)
    assert(json(snapshot(restarted,restartedMap))==fresh,'new run retained prior assets or random counters')
    result.resetVerified=true
    return result
end
local report={kind='offline_normal_data_run',platformVerified=false,dataModified=false,runs={}}
for _,seed in ipairs(M2_SEEDS or {42}) do
    local result=runSeed(seed);report.runs[#report.runs+1]=result
    print('M2_SEED '..seed..' '..result.status..' floor='..result.final.floor..' hp='..result.final.hp..' gold='..result.final.gold)
end
print('M2_EVIDENCE_JSON '..json(report))
