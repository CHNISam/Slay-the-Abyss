-- Fixed ScryAction semantics, without GUI/Golden Eye/Weave. No manual discard.
local Events=require("abyss_events")
local M={}
local MAX=2147483647
local function integer(n,lo,hi)
    return type(n)=="number" and n==n and n%1==0 and n>=lo and n<=hi
end
local function dense(t)
    if type(t)~="table" or getmetatable(t)~=nil then return nil end
    local n=0
    for k in next,t do if not integer(k,1,MAX) then return nil end;n=n+1 end
    for i=1,n do if rawget(t,i)==nil then return nil end end
    return n
end
local function live(state)
    if type(state)~="table" or state.phase~="player" or not state.player or state.player.hp<=0 then return false end
    for _,enemy in ipairs(state.enemies) do if enemy.hp>0 and not enemy.escaped then return true end end
    return false
end
local function piles(state)
    if type(state.catalog)~="table" or type(state.catalog.cards)~="table" then return nil end
    local drawCount,discardCount=dense(state.draw),dense(state.discard)
    if not drawCount or not discardCount then return nil end
    local seen={}
    if state.cardInUse~=nil then
        local card=state.cardInUse
        if type(card)~="table" or not integer(card.uid,1,MAX)
            or not state.catalog.cards[card.cardId] then return nil end
        seen[card.uid]=true
    end
    for _,pile in ipairs({state.draw,state.discard,state.hand or {},state.exhaust or {}}) do
        if not dense(pile) then return nil end
        for _,card in ipairs(pile) do
            if type(card)~="table" or getmetatable(card)~=nil or not integer(card.uid,1,MAX)
                or seen[card.uid] or not state.catalog.cards[card.cardId] then return nil end
            seen[card.uid]=true
        end
    end
    return drawCount
end
function M.begin(state,amount,queue)
    assert(integer(amount,0,MAX),"invalid scry amount")
    assert(state.pendingScry==nil,"scry already pending")
    if not live(state) then return true end
    local n=piles(state)
    assert(n,"invalid scry piles")
    assert(type(state.events)=="table" and integer(state.turn,0,MAX),"invalid scry state")
    local nirvana=state.player.statuses.nirvana or 0
    assert(integer(nirvana,0,MAX),"invalid Nirvana amount")
    local serial=state.scrySerial or 0
    assert(integer(serial,0,MAX-1),"scry serial overflow")
    local uids={}
    for i=1,math.min(amount,n) do uids[i]=state.draw[n-i+1].uid end
    -- ScryAction queues Power hooks BEFORE checking whether draw is empty.
    if nirvana>0 then
        assert(type(queue)=="table" and type(queue.pushBottom)=="function","missing scry action queue")
        queue.pushBottom(state,{kind="effect",effect={op="block",value=nirvana,fixed=true}})
    end
    if n>0 then
        local recalls=require('abyss_watcher_flow_cards').planScry(state,true)
        for _,effect in ipairs(recalls.bottom) do
            assert(queue and type(queue.pushBottom)=='function','missing Weave action queue')
            queue.pushBottom(state,{kind='effect',effect=effect})
        end
    end
    state.scrySerial=serial+1
    Events.emit(state,"scry",{amount=amount,candidates=#uids,token=state.scrySerial})
    -- No visible choices: collapse the empty UI, preserve all logical hooks.
    -- Empty draw never shuffles discard into it and skips card callbacks.
    if #uids==0 then return true end
    state.pendingScry={token=state.scrySerial,turn=state.turn,drawSize=n,candidateUids=uids}
    return "pause"
end
function M.choose(state,orderedUids,token)
    if not live(state) then return false,"not_player_turn" end
    local pending=state.pendingScry
    if type(pending)~="table" or not integer(token,1,MAX) or pending.token~=token
        or state.scrySerial~=token then return false,"stale_scry_token" end
    local n=piles(state)
    local candidates=dense(pending.candidateUids)
    if not n or not candidates or candidates==0 or pending.turn~=state.turn or pending.drawSize~=n or candidates>n then
        return false,"stale_scry_draw"
    end
    local allowed={}
    for i,uid in ipairs(pending.candidateUids) do
        if not integer(uid,1,MAX) or allowed[uid] or state.draw[n-i+1].uid~=uid then return false,"stale_scry_draw" end
        allowed[uid]=true
    end
    local count=dense(orderedUids)
    if not count or count>candidates then return false,"invalid_scry_count" end
    local seen,selected={},{ }
    for _,uid in ipairs(orderedUids) do
        if not integer(uid,1,MAX) or seen[uid] or not allowed[uid] then return false,"invalid_scry_uid" end
        seen[uid]=true
        for _,card in ipairs(state.draw) do if card.uid==uid then selected[#selected+1]=card;break end end
    end
    if not state.actionQueue then
        local needs=false
        for _,card in ipairs(state.discard) do if card.cardId=='weave' then needs=true end end
        for _,card in ipairs(selected) do if card.cardId=='weave' then needs=true end end
        if needs then return false,'missing_weave_action_queue' end
    end
    assert(type(state.events)=="table","missing scry events")
    -- Validation of every candidate and UID finishes before the first move.
    for _,card in ipairs(selected) do
        for i,current in ipairs(state.draw) do
            if current==card then table.remove(state.draw,i);break end
        end
        state.discard[#state.discard+1]=card
        if (state.player.statuses.corruption or 0)~=0 then require('abyss_corruption').onDrawOrDiscard(state) end
        if (state.player.statuses.accuracy or 0)>0 then require('abyss_shivs').onDrawOrDiscard(state) end
        Events.emit(state,"scry_discard",{uid=card.uid,cardId=card.cardId})
    end
    state.pendingScry=nil
    if state.actionQueue then
        local recalls=require('abyss_watcher_flow_cards').planScry(state,true)
        require('abyss_flow_actions').enqueue(state,recalls,require('abyss_action_queue'))
    end
    return true
end
return M
