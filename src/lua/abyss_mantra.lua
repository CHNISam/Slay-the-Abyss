-- Source-verified Mantra/Devotion subset. The host owns queued card execution.
local Actors=require("abyss_actor")
local Events=require("abyss_events")
local M={}
local MAX=2147483647
local function integer(n) return type(n)=="number" and n==n and n%1==0 and n>=0 and n<=MAX end
local function stateOf(state)
    assert(type(state)=="table" and type(state.player)=="table" and type(state.player.statuses)=="table", "missing Mantra player")
    return state.player
end
local function live(state)
    if state.player.hp<=0 or state.phase=="victory" or state.phase=="defeat" then return false end
    for _,enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then return true end end
    return false
end
local function queueApi(queue,state)
    assert(type(queue)=="table" and type(queue.pushTop)=="function" and type(queue.pushBottom)=="function"
        and type(state.actionQueue)=="table","Mantra needs active action queue")
end
local function copy(v)
    if type(v)~="table" then return v end
    local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end

-- Mirrors CONSTRUCTION, not application: even an action later cancelled has
-- already contributed to GameActionManager.mantraGained in the pinned source.
-- Call while building the original actions, inside the host's play transaction.
function M.prepareGain(state,amount)
    stateOf(state)
    assert(integer(amount),"invalid Mantra amount")
    local before=state.mantraGained or 0
    assert(integer(before) and integer(before+0.0+amount),"Mantra counter overflow")
    state.mantraGained=before+amount
    return {op="applyMantra",value=amount}
end

-- Apply one previously constructed incoming MantraPower. No constructor count
-- here. First-application >=10 is deliberately refused pending full PC evidence.
function M.apply(state,amount,queue)
    local player=stateOf(state)
    assert(integer(amount),"invalid Mantra amount")
    if not live(state) then return true end
    local before=player.statuses.mantra
    if before~=nil then assert(integer(before),"invalid Mantra stack") end
    if before==nil and amount>=10 then return false,"unsupported_initial_mantra_threshold" end
    local total=(before or 0)+0.0+amount
    assert(integer(total),"Mantra stack overflow")
    local threshold=before~=nil and total>=10
    if threshold then queueApi(queue,state) end
    -- Mantra is explicitly BUFF in the source. Positive application does not
    -- consume Artifact; Actor retains the shared status validation/events.
    Actors.applyPower(state,player,"mantra",amount,player)
    if threshold then
        player.statuses.mantra=total-10
        queue.pushTop(state,{kind="effect",effect={op="changeStance",stance="Divinity"}})
        if player.statuses.mantra==0 then
            queue.pushTop(state,{kind="effect",effect={op="removeMantra"}})
        end
    end
    Events.emit(state,"mantra",{amount=amount,remaining=player.statuses.mantra,threshold=threshold})
    return true
end

function M.remove(state)
    local player=stateOf(state)
    assert(player.statuses.mantra==0,"Mantra removal requires zero remainder")
    player.statuses.mantra=nil
    Events.emit(state,"mantra_removed",{})
    return true
end

function M.applyDevotion(state,amount)
    local player=stateOf(state)
    assert(integer(amount),"invalid Devotion amount")
    if not live(state) then return true end
    local before=player.statuses.devotion or 0
    assert(integer(before) and integer(before+0.0+amount),"Devotion stack overflow")
    Actors.applyPower(state,player,"devotion",amount,player)
    return true
end

-- Construct once at the source StartOfTurnPostDraw hook: after its normal Draw
-- is queued, before that Draw executes. The host executes these queued effects
-- after Draw. This distinction preserves constructor-time mantraGained.
function M.postDraw(state,queue)
    local player=stateOf(state)
    local amount=player.statuses.devotion
    if amount==nil then return true end
    assert(integer(amount),"invalid Devotion stack")
    if not live(state) then return true end
    queueApi(queue,state)
    if player.statuses.mantra==nil and amount>=10 then
        -- The pinned source deliberately bypasses new MantraPower here: no
        -- remainder and no mantraGained increase, even at Devotion >10.
        queue.pushBottom(state,{kind="effect",effect={op="changeStance",stance="Divinity"}})
    else
        local effect=M.prepareGain(state,amount)
        queue.pushBottom(state,{kind="effect",effect=effect})
    end
    return true
end

function M.withCards(data)
    assert(type(data)=="table" and type(data.cards)=="table" and type(data.cards.cards)=="table"
        and type(data.statuses)=="table" and type(data.statuses.statuses)=="table","missing Mantra data")
    local result=copy(data)
    local ids={};for _,c in ipairs(result.cards.cards) do ids[c.id]=true end
    local cards={
        {id="prostrate",sourceId="Prostrate",sts_name="Prostrate",name="Prostrate",color="purple",type="skill",rarity="common",cost=0,
            effects={{op="gainMantra",value=2},{op="block",value=4}},
            upgrade={effects={{op="gainMantra",value=3},{op="block",value=4}}}},
        {id="worship",sourceId="Worship",sts_name="Worship",name="Worship",color="purple",type="skill",rarity="uncommon",cost=2,
            effects={{op="gainMantra",value=5}},upgrade={selfRetain=true}},
        {id="devotion",sourceId="Devotion",sts_name="Devotion",name="Devotion",color="purple",type="power",rarity="rare",cost=1,
            effects={{op="gainDevotion",value=2}},upgrade={effects={{op="gainDevotion",value=3}}}},
    }
    for _,card in ipairs(cards) do assert(not ids[card.id],"Mantra card already exists");result.cards.cards[#result.cards.cards+1]=card end
    local statuses={};for _,s in ipairs(result.statuses.statuses) do statuses[s.id]=true end
    for _,id in ipairs({"mantra","devotion"}) do
        assert(not statuses[id],"Mantra status already exists")
        result.statuses.statuses[#result.statuses.statuses+1]={id=id,name=id=="mantra" and "真言" or "供奉",kind="buff",stack="intensity",decay="none",
            description=id=="mantra" and "叠加达到10层时，消耗10层真言并进入神格。" or "从下回合起，每个你的回合抽牌后获得等同层数的真言；没有真言且供奉至少10层时，直接进入神格。"}
    end
    return result
end
return M
