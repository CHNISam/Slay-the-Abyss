-- Source-defined True Grit / Warcry selection. Caller owns choose+resume rollback.
local Random=require('abyss_sts_random')
local Events=require('abyss_events');local Actors=require('abyss_actor')
local M={}
local MAX=2147483647
local modes={exhaust_random=true,exhaust_choose=true,put_on_deck=true,recycle=true}
local function integer(n,lo,hi)
    return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi
end
local function dense(t)
    if type(t)~='table' or getmetatable(t)~=nil then return nil end
    local n=0
    for k in next,t do if not integer(k,1,MAX) then return nil end;n=n+1 end
    for i=1,n do if rawget(t,i)==nil then return nil end end
    return n
end
local function live(s)
    if type(s)~='table' or s.phase~='player' or type(s.player)~='table' or type(s.player.hp)~='number'
        or s.player.hp<=0 or type(s.player.statuses)~='table' or type(s.enemies)~='table' then return false end
    for _,e in ipairs(s.enemies) do if Actors.isPresent(e) then return true end end
    return false
end
local function index(s)
    if not s.catalog or type(s.catalog.cards)~='table' then return nil end
    local n=dense(s.hand)
    if not n or n>10 then return nil end
    local byUid,seen={},{}
    for _,name in ipairs({'hand','draw','discard','exhaust'}) do
        local pile=s[name]
        if not dense(pile) then return nil end
        for _,card in ipairs(pile) do
            if type(card)~='table' or getmetatable(card)~=nil or not integer(card.uid,1,MAX)
                or seen[card.uid] or not s.catalog.cards[card.cardId] then return nil end
            seen[card.uid]=true
        end
    end
    if s.cardInUse then
        if type(s.cardInUse)~='table' or not integer(s.cardInUse.uid,1,MAX) or seen[s.cardInUse.uid]
            or not s.catalog.cards[s.cardInUse.cardId] then return nil end
    end
    for i,card in ipairs(s.hand) do byUid[card.uid]={position=i,card=card} end
    return byUid,n
end
local function exhaustSupported(s,card)
    if require('abyss_action_queue').active(s) then
        return pcall(require('abyss_exhaust').plan,s,card,{onExhaustRelics=s.onExhaustRelics or {}})
    end
    if (s.player.statuses.dark_embrace or 0)~=0 or (s.player.statuses.feel_no_pain or 0)~=0 then return false end
    local def=s.catalog.cards[card.cardId]
    return def and not def.onExhaust and not def.exhaustEffects and not def.exhaustTrigger
        and card.cardId~='sentinel' and card.cardId~='necronomicurse'
end
local function move(s,entry,mode)
    local card=entry.card
    if mode=='recycle'then
        require('abyss_defect_final_cards').recycle(s,card,require('abyss_action_queue'))
        Events.emit(s,'hand_choice_move',{uid=card.uid,cardId=card.cardId,mode=mode,pile='exhaust'})
        return
    end
    local destination=mode=='put_on_deck' and 'draw' or 'exhaust'
    if destination=='exhaust' and require('abyss_action_queue').active(s) then
        require('abyss_exhaust').move(s,card,'hand',require('abyss_action_queue'),{onExhaustRelics=s.onExhaustRelics or {}})
    else
        assert(table.remove(s.hand,entry.position)==card,'changed hand choice')
        s[destination][#s[destination]+1]=card
        if destination=='exhaust' and (s.player.statuses.corruption or 0)~=0 then require('abyss_corruption').onDrawOrDiscard(s) end
    end
    Events.emit(s,'hand_choice_move',{uid=card.uid,cardId=card.cardId,mode=mode,pile=destination})
end
function M.active(s) return type(s)=='table' and s.pendingHandChoice~=nil end
function M.begin(s,mode,count,_queue)
    assert(modes[mode] and count==1,'unsupported hand choice')
    assert(type(s)=='table' and not s.pendingHandChoice,'hand choice already pending')
    assert(not s.pendingScry and not s.pendingDiscard,'other selection already pending')
    if not live(s) then return true end
    local byUid,n=index(s);assert(byUid,'invalid hand choice piles')
    if n==0 then return true end
    assert(integer(s.choiceSerial or 0,0,MAX-1),'hand choice serial overflow')
    assert(integer(s.turn,0,MAX) and type(s.events)=='table','invalid hand choice state')
    if mode~='put_on_deck' then
        for _,card in ipairs(s.hand) do assert(exhaustSupported(s,card),'unsupported exhaust trigger') end
    end
    -- ExhaustAction auto-all is before its random branch. PutOnDeckAction's
    -- one-card shortcut explicitly uses getRandomCard, including random(0).
    local random=(mode=='exhaust_random' and n>1) or (mode=='put_on_deck' and n==1)
    if random then assert(s.cardRandomRng,'hand choice requires cardRandomRng');Random.snapshot(s.cardRandomRng) end
    local selected
    if random then selected=s.hand[Random.randomInt(s.cardRandomRng,n-1)+1]
    elseif n==1 then selected=s.hand[1] end
    s.choiceSerial=(s.choiceSerial or 0)+1
    if selected then move(s,byUid[selected.uid],mode);return true end
    local uids,ids,upgraded={},{},{}
    for i,card in ipairs(s.hand) do uids[i]=card.uid;ids[i]=card.cardId;upgraded[i]=card.upgraded==true end
    s.pendingHandChoice={mode=mode,count=1,serial=s.choiceSerial,token=s.choiceSerial,turn=s.turn,
        handUids=uids,cardIds=ids,upgraded=upgraded}
    Events.emit(s,'hand_choice',{mode=mode,token=s.choiceSerial,count=1})
    return 'pause'
end
function M.choose(s,uids,token)
    if not live(s) then return false,'not_player_turn' end
    local p=s.pendingHandChoice
    if type(p)~='table' or not integer(token,1,MAX) or p.token~=token or s.choiceSerial~=token then
        return false,'stale_hand_choice_token'
    end
    if not modes[p.mode] or p.mode=='exhaust_random' or p.count~=1 then return false,'invalid_hand_choice_mode' end
    local byUid,n=index(s)
    if not byUid or p.turn~=s.turn or dense(p.handUids)~=n or dense(p.cardIds)~=n or dense(p.upgraded)~=n then
        return false,'stale_hand_choice_hand'
    end
    for i,card in ipairs(s.hand) do
        if card.uid~=p.handUids[i] or card.cardId~=p.cardIds[i] or (card.upgraded==true)~=p.upgraded[i] then
            return false,'stale_hand_choice_hand'
        end
    end
    if dense(uids)~=1 or not integer(uids[1],1,MAX) or not byUid[uids[1]] then return false,'invalid_hand_choice_uid' end
    local entry=byUid[uids[1]]
    if p.mode~='put_on_deck' and not exhaustSupported(s,entry.card) then return false,'unsupported_exhaust_trigger' end
    assert(type(s.events)=='table','missing hand choice events')
    move(s,entry,p.mode);s.pendingHandChoice=nil
    return true
end
return M
