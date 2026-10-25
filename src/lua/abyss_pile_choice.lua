-- Retrieval moves original instances; all persisted choice state is plain data.
-- Combat/Run owns queue resume and the surrounding whole-card transaction.
local Events=require("abyss_events")
local Snapshot=require("abyss_snapshot")
local M={}
local MAX=2147483647
local pileNames={"hand","draw","discard","exhaust"}
local specs={headbutt={source="discard",destination="draw"},exhume={source="exhaust",destination="hand"},
    hologram={source="discard",destination="hand"},seek={source="draw",destination="hand"}}
local rarity={basic=0,special=1,common=2,uncommon=3,rare=4,curse=5,status=1}
local function integer(n,lo,hi) return type(n)=="number" and n==n and n%1==0 and n>=lo and n<=hi end
local function dense(t)
    if type(t)~="table" or getmetatable(t)~=nil then return nil end
    local n=0
    for k in next,t do if not integer(k,1,MAX) then return nil end;n=n+1 end
    for i=1,n do if rawget(t,i)==nil then return nil end end
    return n
end
local function copy(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function live(s)
    if type(s)~="table" or s.phase~="player" or type(s.player)~="table" or type(s.player.statuses)~="table"
        or type(s.player.hp)~="number" or s.player.hp<=0 or not dense(s.enemies) then return false end
    for _,enemy in ipairs(s.enemies) do if type(enemy)=="table" and type(enemy.hp)=="number" and enemy.hp>0 and not enemy.escaped then return true end end
    return false
end
local function fact(card) return {uid=card.uid,cardId=card.cardId,upgraded=card.upgraded==true} end
local function validCard(s,card)
    return type(card)=="table" and getmetatable(card)==nil and integer(card.uid,1,MAX)
        and type(card.cardId)=="string" and s.catalog.cards[card.cardId]~=nil
        and (card.upgraded==nil or type(card.upgraded)=="boolean")
end
local function graph(s)
    if not s.catalog or type(s.catalog.cards)~="table" then return nil end
    local result,seen={byUid={},piles={}},{}
    for _,name in ipairs(pileNames) do
        local pile=s[name];local n=dense(pile)
        if not n or name=="hand" and n>10 then return nil end
        local rows={};result.piles[name]=rows
        for i,card in ipairs(pile) do
            if not validCard(s,card) or seen[card.uid] then return nil end
            seen[card.uid]=true;result.byUid[card.uid]={card=card,pile=name,index=i};rows[i]=fact(card)
        end
    end
    if s.cardInUse then
        if not validCard(s,s.cardInUse) or seen[s.cardInUse.uid] then return nil end
        result.using=fact(s.cardInUse)
    end
    return result
end
local function isExhume(s,card)
    return card.cardId=="exhume" or s.catalog.cards[card.cardId].sourceId=="Exhume"
end
local function candidates(s,mode,requested)
    local spec=specs[mode];local result,excluded={},{}
    for _,card in ipairs(s[spec.source]) do
        if mode=="exhume" and isExhume(s,card) then excluded[#excluded+1]=card.uid
        else result[#result+1]=card.uid end
    end
    -- BetterDrawPileToHand sorts a TEMPORARY group only when it must ask.
    -- Locale display names are current data names, not an asserted original
    -- language pack. Never reorder the real draw pile for this presentation.
    if mode=="seek" and #result>requested then
        local original={};for i,uid in ipairs(result) do original[uid]=i end
        local keys={}
        for _,card in ipairs(s.draw) do
            local def=s.catalog.cards[card.cardId]
            local name=def.name or def.sts_name or def.sourceId or def.id
            assert(type(name)=="string" and rarity[def.rarity],"unsupported retrieval display definition")
            keys[card.uid]={status=def.type=="status",rarity=rarity[def.rarity],name=name..(card.upgraded and "+" or "")}
        end
        table.sort(result,function(a,b)
            local ka,kb=keys[a],keys[b]
            local sa,ra,na=ka.status,ka.rarity,ka.name;local sb,rb,nb=kb.status,kb.rarity,kb.name
            if sa~=sb then return not sa end
            if ra~=rb then return ra>rb end
            if na~=nb then return na<nb end
            return original[a]<original[b]
        end)
    end
    return result,excluded
end
local function sameFact(a,b)
    return a==nil and b==nil or type(a)=="table" and type(b)=="table"
        and a.uid==b.uid and a.cardId==b.cardId and a.upgraded==b.upgraded
end
local function sameList(a,b)
    local n=dense(a);if not n or n~=dense(b) then return false end
    for i=1,n do
        if type(a[i])=="table" then if not sameFact(a[i],b[i]) then return false end
        elseif a[i]~=b[i] then return false end
    end
    return true
end
local function fresh(s,p,generation)
    local spec=type(p)=="table" and specs[p.mode]
    if not spec or p.source~=spec.source or p.destination~=spec.destination or p.turn~=s.turn
        or not integer(p.token,1,MAX) or p.token~=s.pileChoiceSerial
        or not integer(p.generation,0,MAX) or p.generation~=generation
        or not integer(p.requested,1,MAX) or not integer(p.count,1,p.requested)
        or p.minCount~=p.count or p.maxCount~=p.count or type(p.piles)~="table" then return nil end
    local current=graph(s);if not current or not sameFact(current.using,p.using) then return nil end
    for _,name in ipairs(pileNames) do if not sameList(current.piles[name],p.piles[name]) then return nil end end
    local uids,excluded=candidates(s,p.mode,p.requested)
    if not sameList(uids,p.candidateUids) or not sameList(excluded,p.excludedUids)
        or #uids<p.count or p.count~=math.min(p.requested,#uids) then return nil end
    return current
end
local function transaction(s,fn)
    local restore=Snapshot.capture(s)
    local called,a,b=pcall(fn)
    if not called then restore();error(a,0) end
    if a==false then restore() end
    return a,b
end
local function remove(s,name,card)
    for i,current in ipairs(s[name]) do if current==card then table.remove(s[name],i);return end end
    error("retrieval instance left source pile")
end
local function discardHook(s)
    if (s.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(s) end
    if (s.player.statuses.accuracy or 0)>0 then require("abyss_shivs").onDrawOrDiscard(s) end
end
local function restoreExcluded(s)
    local excluded={};local i=1
    while i<=#s.exhaust do
        local card=s.exhaust[i]
        if isExhume(s,card) then excluded[#excluded+1]=table.remove(s.exhaust,i) else i=i+1 end
    end
    for _,card in ipairs(excluded) do s.exhaust[#s.exhaust+1]=card end
end
local function resolve(s,p,uids,current)
    for _,uid in ipairs(uids) do
        local card=assert(current.byUid[uid],"retrieval card missing").card
        local destination=p.destination
        if destination=="hand" and #s.hand>=10 then
            if p.mode=="seek" then destination="discard"
            else destination=p.source end -- Hologram stays in discard; no fake discard trigger.
        end
        if destination~=p.source then
            remove(s,p.source,card);s[destination][#s[destination]+1]=card
            if p.mode=="exhume" and (s.player.statuses.corruption or 0)~=0 then
                -- Exhume explicitly sets a skill's turn cost; it is NOT a draw
                -- event and must not trigger Void/Eviscerate or hand-wide hooks.
                require("abyss_corruption").onDraw(s,card)
            elseif p.mode=="seek" and destination=="discard" then discardHook(s) end
            Events.emit(s,"pile_choice_move",{mode=p.mode,uid=card.uid,cardId=card.cardId,source=p.source,destination=destination})
        end
    end
    if p.mode=="exhume" and #p.piles.exhaust>1 then restoreExcluded(s) end
    s.pendingPileChoice=nil
    return true
end
function M.active(s) return type(s)=="table" and s.pendingPileChoice~=nil end
function M.begin(s,mode,count,generation)
    local spec=assert(specs[mode],"unknown retrieval mode")
    assert(integer(count,0,MAX) and ((mode=="seek" or mode=="hologram") or count==1),"invalid retrieval count")
    assert(integer(generation,0,MAX),"retrieval requires explicit combat generation")
    assert(type(s)=="table" and not s.pendingPileChoice and not s.pendingHandChoice and not s.pendingScry and not s.pendingDiscard,
        "another selection is pending")
    if not live(s) then return true end
    local current=assert(graph(s),"invalid retrieval piles")
    assert(type(s.events)=="table" and integer(s.turn,0,MAX),"invalid retrieval event state")
    if count==0 or mode=="exhume" and #s.hand==10 then return true end
    local uids,excluded=candidates(s,mode,count)
    if #uids==0 then return true end
    assert(integer(s.pileChoiceSerial or 0,0,MAX-1),"retrieval token overflow")
    local rawCount=#s[spec.source]
    local auto=mode=="exhume" and rawCount==1 or mode~="exhume" and rawCount<=count
    return transaction(s,function()
        s.pileChoiceSerial=(s.pileChoiceSerial or 0)+1
        local p={mode=mode,source=spec.source,destination=spec.destination,requested=count,count=math.min(count,#uids),
            minCount=math.min(count,#uids),maxCount=math.min(count,#uids),token=s.pileChoiceSerial,generation=generation,
            turn=s.turn,piles=current.piles,using=current.using,candidateUids=uids,excludedUids=excluded}
        if auto then return resolve(s,p,uids,current) end
        s.pendingPileChoice=p
        Events.emit(s,"pile_choice",{mode=mode,source=spec.source,count=p.count,candidates=#uids,token=p.token,generation=generation})
        return "pause"
    end)
end
function M.choose(s,uids,token,generation)
    if not live(s) then return false,"not_player_turn" end
    local p=s.pendingPileChoice
    if type(p)~="table" or not integer(token,1,MAX) or p.token~=token or s.pileChoiceSerial~=token then return false,"stale_pile_choice_token" end
    if not integer(generation,0,MAX) or p.generation~=generation then return false,"stale_pile_choice_generation" end
    local current=fresh(s,p,generation)
    if not current then return false,"stale_pile_choice_state" end
    if dense(uids)~=p.count then return false,"invalid_pile_choice_count" end
    local allowed,selected={},{}
    for _,uid in ipairs(p.candidateUids) do allowed[uid]=true end
    for _,uid in ipairs(uids) do
        if not integer(uid,1,MAX) or not allowed[uid] or selected[uid] then return false,"invalid_pile_choice_uid" end
        selected[uid]=true
    end
    return transaction(s,function()return resolve(s,p,uids,current)end)
end
function M.view(s)
    local p=type(s)=="table" and s.pendingPileChoice
    if not p then return nil end
    if not live(s) then return nil,"not_player_turn" end
    local current=fresh(s,p,p.generation)
    if not current then return nil,"stale_pile_choice_state" end
    local out={mode=p.mode,source=p.source,destination=p.destination,count=p.count,minCount=p.minCount,maxCount=p.maxCount,
        token=p.token,generation=p.generation,turn=p.turn,candidateUids=copy(p.candidateUids),candidates={},optional=false}
    for i,uid in ipairs(p.candidateUids) do out.candidates[i]=fact(current.byUid[uid].card) end
    return out
end
return M
