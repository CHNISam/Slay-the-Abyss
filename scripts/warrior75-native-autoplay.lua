-- EXPLICIT NORMAL-RULE AUTOPLAY CANDIDATE ONLY. Adapted from our archived M2
-- driver. Exclude from the production manifest. No inventory/navigation fixture.
-- Commands exercise the native controllers; they do not certify physical input.
-- No writes to Run, Map, card/enemy data or inventory. The sole host write is
-- view.seed before GameUI:start(), an explicit test configuration.
local Policy = require("abyss_w75_policy")
local Run, Nodes, Theme = require("abyss_run"), require("abyss_nodes"), require("abyss_theme")
local M = {config={seed=42, interval=0.65, victoryDelay=8, maxActions=2400}}
local states = setmetatable({}, {__mode="k"})
local function json(v)
    local t=type(v)
    if t=="nil" then return "null" end
    if t=="number" or t=="boolean" then return tostring(v) end
    if t=="string" then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
        return c=='"' and '\\"' or c=='\\' and '\\\\' or string.format('\\u%04x',string.byte(c)) end)..'"' end
    local keys,n,array={},0,true
    for k in pairs(v) do keys[#keys+1]=k;n=n+1;if type(k)~="number" then array=false end end
    local out={}
    if array and #v==n then for _,x in ipairs(v) do out[#out+1]=json(x) end return '['..table.concat(out,',')..']' end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do out[#out+1]=json(tostring(k))..':'..json(v[k]) end
    return '{'..table.concat(out,',')..'}'
end
local printSequence=0
local function emit(kind,value)
    local encoded=json(value)
    if #encoded<=850 then print(kind.." "..encoded);return end
    -- Bound individual native prints. Every part is independently valid JSON;
    -- consumers concatenate payload strings to recover the original record.
    printSequence=printSequence+1
    local parts,offset={},1
    while offset<=#encoded do
        local finish=math.min(#encoded,offset+499)
        while finish<#encoded and encoded:byte(finish+1)>=128 and encoded:byte(finish+1)<192 do finish=finish-1 end
        parts[#parts+1]=encoded:sub(offset,finish);offset=finish+1
    end
    print(kind.." "..json({chunked=true,record=printSequence,parts=#parts}))
    for i,payload in ipairs(parts) do print(kind.."_PART "..json({record=printSequence,part=i,payload=payload})) end
end
local function rng(value)
    if type(value)~="table" then return value end
    local copied={};for key,item in pairs(value) do copied[key]=rng(item) end
    return copied -- Includes primitive state and nested shop card/merchant/potion streams.
end
local function snapshot(ui,s,event)
    local run,map=ui.run,ui.map
    local v={event=event,configuredSeed=s.seed,time=s.time,actions=s.actions,mode=ui.mode}
    if not run then return v end
    v.seed,v.floor,v.mapFloor,v.hp,v.maxHp,v.gold=run.seed,run.floor,map.floor,run.hp,run.maxHp,run.gold
    v.phase,v.victories,v.elapsedSeconds=run.phase,run.victories,run.elapsedSeconds
    v.deck,v.relics,v.potions={},{},{}
    for _,c in ipairs(run.deck) do v.deck[#v.deck+1]={uid=c.uid,cardId=c.cardId,upgraded=c.upgraded==true} end
    for _,id in ipairs(run.relics) do v.relics[#v.relics+1]=id end
    for i=1,run.data.rules.player.potionSlots do v.potions[i]={slot=i,id=run.potions[i] or false} end
    v.nextDeckUid,v.shopRemoveCount=run.nextDeckUid,run.shopRemoveCount
    v.rng={event=rng(run.eventRng),misc=rng(run.miscRng),shop=rng(run.shopRng),potion=rng(run.potionRng),
        combat=run.combat and {seed=run.combat.seed},potionChanceModifier=run.potionChanceModifier}
    v.node=run.nodeFlow and {id=run.nodeFlow.id,type=run.nodeFlow.type,roomKind=run.nodeFlow.roomKind,
        complete=run.nodeFlow.complete,result=run.nodeFlow.result,event=run.nodeFlow.event and run.nodeFlow.event.id}
    v.path={};for _,id in ipairs(map.path) do v.path[#v.path+1]=id end
    if run.combat then
        v.combat={turn=run.combat.turn,phase=run.combat.phase,hp=run.combat.player.hp,
            energy=run.combat.energy,block=run.combat.player.block,hand={}}
        for _,c in ipairs(run.combat.hand) do v.combat.hand[#v.combat.hand+1]={uid=c.uid,cardId=c.cardId,upgraded=c.upgraded==true} end
    end
    return v
end
local function ledger(ui,s,event)
    local value=snapshot(ui,s,event)
    s.ledger=(s.ledger or 0)+1
    local record=s.ledger
    for _,key in ipairs({"deck","relics","potions","path"}) do
        local entries=value[key];value[key]=nil
        if entries then
            for first=1,math.max(1,#entries),5 do
                local items={};for i=first,math.min(first+4,#entries) do items[#items+1]=entries[i] end
                emit("M2_LEDGER_"..key:upper(),{record=record,event=event,configuredSeed=s.seed,first=first,total=#entries,items=items})
            end
        end
    end
    local random=value.rng;value.rng=nil
    if random then emit("M2_LEDGER_RNG",{record=record,event=event,configuredSeed=s.seed,streams=random}) end
    if value.combat then
        emit("M2_LEDGER_HAND",{record=record,event=event,configuredSeed=s.seed,cards=value.combat.hand})
        value.combat.hand=nil
    end
    value.record=record;emit("M2_LEDGER",value)
end
local function stop(ui,s,reason)
    s.stopped,s.reason=true,reason;ledger(ui,s,"stopped")
    emit("M2_STOP",{seed=s.seed,reason=reason,floor=ui.map and ui.map.floor,phase=ui.run and ui.run.phase,time=s.time})
end
local function perform(ui,s,label,fn,details)
    s.actions=s.actions+1
    local run=ui.run
    local record={action=label,configuredSeed=s.seed,time=s.time,index=s.actions,mode=ui.mode,
        phase=run and run.phase,floor=ui.map and ui.map.floor,turn=run and run.combat and run.combat.turn,details=details}
    local ok,result,reason=pcall(fn)
    record.ok,record.result,record.reason=ok and result~=false,result,reason
    if not ok then record.reason=tostring(result);record.result=nil end
    emit("M2_ACTION",record)
    ledger(ui,s,"after_"..label)
    if not ok or result==false then stop(ui,s,label..":"..tostring(record.reason or "rejected"));return false end
    return true
end
local function press(ui,s,key,details)
    return perform(ui,s,"node_"..key,function() return ui.nodeUI:press(key) end,details)
end
local function mark(s,plan)
    if plan then s.coverage[plan.coverage or plan.method]=true;s.localDone[plan.coverage or plan.method]=true end
    s.plan=nil
end
local function selectPicker(ui,s)
    local node,plan=ui.nodeUI,s.plan
    if not plan or not plan.uid then return stop(ui,s,"picker_without_public_suggestion") end
    local rows=node.picker=="upgrade" and node.upgradeRows or node.removeRows
    local wanted
    for i,c in ipairs(rows) do if c.uid==plan.uid then wanted=i break end end
    if not wanted then return stop(ui,s,"suggested_UID_not_in_picker") end
    local size=#Theme.layout.nativeNode.picker.columns
    local page=math.floor((wanted-1)/size)+1
    if node.pickPage~=page then return press(ui,s,"pickerView/"..(page>node.pickPage and "next" or "previous")) end
    if node.selected~=plan.uid then return press(ui,s,"pickerView/card"..((wanted-1)%size+1),{uid=plan.uid}) end
    if press(ui,s,"confirm",{uid=plan.uid,method=plan.method}) then mark(s,plan) end
end
local function eventKey(ui,plan)
    local flow=ui.run.nodeFlow
    if flow.event.id=="cleric" then return "eventView/option"..(plan.choice=="heal" and 1 or plan.choice=="purify" and 2 or 3) end
    if flow.event.id=="purifier" then return "eventView/option"..(plan.choice=="pray" and 1 or 2) end
    for i,option in ipairs(ui.nodeUI.view.node.event.options or {}) do
        if option.choice==plan.choice then return "eventView/option"..i end
    end
end
local function actNode(ui,s)
    local node,flow=ui.nodeUI,ui.run.nodeFlow
    if node:holding() then return press(ui,s,"confirm",{continueResult=true}) end
    if node.mode=="picker" then return selectPicker(ui,s) end
    local plan=Policy.suggestNodeAction(ui.run,ui.map,s.coverage,s.localDone)
    if not plan then return stop(ui,s,"node_has_no_legal_suggestion") end
    -- The normal UI disables rest at full HP when forging is possible, even
    -- though the lower-level rest command accepts a zero-heal transaction.
    -- Respect the visible UI boundary and choose a real eligible upgrade.
    if plan.method=="rest" and node.actions["campView/rest"] and not node.actions["campView/rest"].enabled then
        local chosen
        for _,card in ipairs(node.view.node.upgradeCards or {}) do
            if not chosen or card.cardId=="bash" or Policy.scoreCard(ui.run,card.cardId)>Policy.scoreCard(ui.run,chosen.cardId) then chosen=card end
        end
        if not chosen or not node.actions["campView/forge"].enabled then return stop(ui,s,"camp_has_no_enabled_public_action") end
        plan={method="upgrade",uid=chosen.uid,adaptation="full_hp_rest_disabled"}
    end
    local method,key=plan.method,nil
    if method=="rest" then key="campView/rest"
    elseif method=="upgrade" then key="campView/forge";s.plan=plan
    elseif method=="buyCardSlot" or method=="buyCard" then
        local slot=plan.slot
        if not slot then for i,o in ipairs(node.view.node.cards) do if o.id==plan.id and not o.sold then slot=i break end end end
        if not slot then return stop(ui,s,"shop_offer_not_found") end
        key="shopView/card"..slot
    elseif method=="removeCard" then key="shopView/removal";s.plan=plan
    elseif method=="buyPotion" then key="shopView/potion"..plan.slot
    elseif method=="leaveShop" then key="confirm"
    elseif method=="chooseEvent" then key=eventKey(ui,plan);s.plan=plan
    elseif method=="claimTreasure" or method=="claimBossTreasure" then
        if not node.opened then return press(ui,s,"treasureView/chest") end
        if method=="claimBossTreasure" and #flow.reward.relics==0 then key="back"
        elseif method=="claimBossTreasure" and node.treasureChoice~=(plan.index or 1) then
            return press(ui,s,"treasureView/"..(node.treasureChoice<(plan.index or 1) and "next" or "previous"))
        else key="treasureView/take" end
    end
    if not key then return stop(ui,s,"unsupported_node_suggestion:"..tostring(method)) end
    if press(ui,s,key,plan) and node.mode~="picker" then mark(s,plan) end
end
local function actReward(ui,s)
    -- Each is a legal public command, one per tick; no reward, RNG or inventory
    -- field is written by this driver. Physical reward inputs have separate evidence.
    local rewards=ui.run.rewards
    if rewards.gold and not rewards.goldClaimed then
        return perform(ui,s,"claimGoldReward",function()local ok,why=Run.claimGoldReward(ui.run);ui:refresh();return ok,why end)
    end
    local offer=ui.run.rewards and ui.run.rewards.potion
    if offer and not offer.resolved and s.ignoredPotion~=offer then
        local skip=offer.unavailable or Run.potionCount(ui.run)>=ui.run.data.rules.player.potionSlots
        if skip then s.ignoredPotion=offer;return end -- Proceed leaves the bottle unclaimed.
        local command="claimPotionReward"
        return perform(ui,s,command,function()
            if ui.battleUI[command] then return ui.battleUI[command](ui.battleUI) end
            -- Explicit public Run-command fallback for an earlier test candidate.
            local ok,reason=Run[command](ui.run);ui:refresh();return ok,reason
        end,{id=offer.id,reason=skip and "full_or_unavailable" or "available"})
    end
    if rewards.cardResolved then
        return perform(ui,s,"leaveCombatRewards",function()local ok,why=Run.leaveCombatRewards(ui.run);ui:refresh();return ok,why end)
    end
    local choice=Policy.chooseReward(ui.run)
    if choice==0 then
        return perform(ui,s,"leave_unclaimed_card_reward",function()local ok,why=Run.leaveCombatRewards(ui.run);ui:refresh();return ok,why end)
    end
    return perform(ui,s,"card_reward",function()
        local ok,why=Run.claimCardReward(ui.run,choice);ui:refresh();return ok,why
    end,{index=choice,options=Run.rewardOptions(ui.run)})
end
local function actChoice(ui,s)
    local battle=ui.run.combat;local choice=battle.pendingChoice
    local chosen,best
    for _,uid in ipairs(choice.uids) do
        local card
        for _,pile in ipairs({battle.hand,battle.discard,battle.exhaust}) do
            for _,c in ipairs(pile) do if c.uid==uid then card=c end end
        end
        assert(card,'native driver choice UID missing')
        local def=require('abyss_combat').cardDefinition(battle,card)
        local score=Policy.scoreCard(ui.run,card.cardId)+(def.type=='attack' and 10 or 0)
        if def.type=='status' or def.type=='curse' then score=-100 end
        if choice.op=='exhaustChoose' or choice.op=='handToDraw' then score=-score end
        if not best or score>best then chosen,best=uid,score end
    end
    return perform(ui,s,'card_choice',function()return ui.battleUI:chooseCard(choice.token,chosen)end,{op=choice.op,uid=chosen})
end
local function actCombat(ui,s)
    local b,run=ui.battleUI,ui.run
    if run.combat.phase~="player" then return end
    if s.card then
        local chosen=s.card;s.card=nil
        return perform(ui,s,"playSelected",function()
            b:playSelected(chosen.target)
            return b.selected==nil,"selected_card_not_consumed"
        end,chosen)
    end
    local uid,target,chosen=Policy.chooseCombat(run)
    if uid then
        local ok=perform(ui,s,"playSlot",function()
            b:playSlot(chosen.handIndex)
            return b.selected==uid,"card_selection_rejected"
        end,chosen)
        if ok then s.card={uid=uid,cardId=chosen.cardId,handIndex=chosen.handIndex,target=target} end
    else
        return perform(ui,s,"endTurn",function() b:endTurn();return b.busy==true,"end_turn_not_started" end)
    end
end
function M.configure(config)
    assert(type(config)=="table" and type(config.seed)=="number" and config.seed%1==0,"explicit integer test seed required")
    M.config={seed=config.seed,interval=config.interval or .65,victoryDelay=config.victoryDelay or 8,maxActions=config.maxActions or 2400}
    assert(M.config.interval>=.5 and M.config.interval<=.8,"one action per 0.5-0.8 seconds")
    assert(M.config.victoryDelay>=8,"preserve victory evidence for at least eight seconds")
end
function M.status(ui) return states[ui] end
function M.update(ui,dt)
    if type(dt)~="number" or dt~=dt or dt<0 or dt==math.huge then return end
    local s=states[ui]
    if not s then
        s={seed=M.config.seed,interval=M.config.interval,victoryDelay=M.config.victoryDelay,maxActions=M.config.maxActions,
            time=0,clock=0,actions=0,coverage={},localDone={}}
        states[ui]=s
        emit("M2_DRIVER_READY",{seed=s.seed,interval=s.interval,normalData=true,physicalTouchCertified=false})
    end
    if s.stopped then return end
    s.time,s.clock=s.time+dt,s.clock+dt
    if ui.run and ui.run~=s.run then s.run=ui.run;ledger(ui,s,"new_run") end
    if ui.run and ui.run.nodeFlow and ui.run.nodeFlow.id~=s.node then
        s.node=ui.run.nodeFlow.id;s.localDone={};s.coverage[ui.run.nodeFlow.type]=true;ledger(ui,s,"enter_floor")
    end
    if ui.battleUI.busy or ui.exitOpen then return end
    local choosing=ui.run and ui.run.combat and ui.run.combat.pendingChoice
    if ui.deckUI.visible and not choosing then return end
    if ui.mode=="defeat" then return stop(ui,s,"normal_run_defeat") end
    if ui.mode=="victory" then
        if not s.victoryAt then s.victoryAt=s.time;ledger(ui,s,"victory") end
        if s.time-s.victoryAt<s.victoryDelay then return end
    end
    if s.clock<s.interval then return end
    s.clock=0 -- discard accumulated busy time; never dispatch a catch-up burst
    if s.actions>=s.maxActions or s.time>3600 then return stop(ui,s,"driver_budget_exhausted") end
    if choosing then return actChoice(ui,s) end
    if ui.mode=="menu" and not ui.run then
        return perform(ui,s,"start",function() ui.seed=s.seed;return ui:start() end,{testConfigurationSeed=s.seed})
    elseif ui.mode=="victory" then
        if perform(ui,s,"settle_victory",function() return ui:settle() end,{observedVictorySeconds=s.time-s.victoryAt}) then
            s.stopped,s.reason=true,"settlement_requested";ledger(ui,s,"settlement_requested")
        end
    elseif ui.mode=="node" then return actNode(ui,s)
    elseif ui.run and ui.run.phase=="reward" then return actReward(ui,s)
    elseif ui.run and ui.run.phase=="combat" then return actCombat(ui,s)
    elseif ui.mode=="map" then
        local chosen=Policy.chooseNode(ui.run,ui.map,s.coverage)
        if not chosen then return stop(ui,s,"no_legal_next_node") end
        return perform(ui,s,"choose_map_node",function() return ui.mapUI:choose(chosen.id) end,{id=chosen.id,type=chosen.type,floor=chosen.floor})
    end
end
return M
