-- Beggar behavior derived from aeubanks/sts at 319009d5 (not Java code).
-- Nodes owns each command's transaction. Payment and removal are separate
-- commands: a failed permanent remove must never refund an earlier donation.
local Run=require('abyss_run')
local Purge=require('abyss_living_wall')
local M={ids={beggar=true}}
local GOLD_COST=75

function M.prepare(_run,event)
    event.stage='intro'
    event.body='一位乞丐向你请求75金币。'
end

local function row(choice,title,description,enabled,picker)
    return {choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
end

function M.options(run,event)
    if event.stage=='intro' then
        return {row('donate','施舍75金币','支付75金币，然后选择移除一张卡牌。',run.gold>=GOLD_COST),
            row('leave','离开','不支付金币。')}
    elseif event.stage=='gave_money' then
        return {row('confirm','继续','已支付75金币；接下来必须选择移除一张卡牌。')}
    elseif event.stage=='choose_card' then
        return {row('purge','移除卡牌','必须选择一张非瓶装、可清除的永久牌；不能跳过。',
            #Purge.purgeCards(run)>0,'beggar_purge')}
    elseif event.stage=='leave' then
        return {row('leave','离开','返回路线。')}
    end
    return {}
end

-- Only enrich the detached Nodes view, never the permanent owner. The source
-- opens even an empty mandatory grid; its empty-group resolution is unproven.
-- Keep this boundary pending instead of inventing zero-choice success/refunds.
function M.view(run,event)
    if event.stage~='choose_card' then return end
    event.purgeCards=Purge.purgeCards(run)
    event.selection={count=1,canCancel=false,forPurge=true,anyNumber=false}
    if #event.purgeCards==0 then event.pendingBoundary='empty_purge_group_source_unproven' end
end

function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil and event.stage~='choose_card' then return false,'invalid_event_choice' end
    if event.stage=='intro' then
        if choice=='leave' then
            event.stage='leave';event.body='你没有施舍，准备离开。'
            return true,'pending'
        end
        if choice~='donate' then return false,'invalid_event_choice' end
        if run.gold<GOLD_COST then return false,'insufficient_gold' end
        run.gold=run.gold-GOLD_COST
        event.stage='gave_money';event.body='你支付了75金币。乞丐示意你继续。'
        return true,'pending'
    elseif event.stage=='gave_money' then
        if choice~='confirm' then return false,'invalid_event_choice' end
        event.stage,event.choice='choose_card','purge'
        event.body='选择一张非瓶装、可清除的永久牌移除。'
        return true,'choose_card'
    elseif event.stage=='choose_card' then
        if choice~='purge' then return false,'invalid_event_choice' end
        -- UIDs represent source object identity. Never remove the first of two
        -- ambiguous instances, nor reinterpret a stale position as another card.
        local matches=0
        for _,card in ipairs(run.deck) do if card.uid==uid then matches=matches+1 end end
        if uid==nil or matches~=1 then return false,'invalid_card' end
        local allowed=false
        for _,card in ipairs(Purge.purgeCards(run)) do if card.uid==uid then allowed=true;break end end
        if not allowed then return false,'card_not_purgeable' end
        local ok,why=Run.removeCard(run,uid)
        if not ok then return false,why end
        event.removedUid=uid;event.stage='result'
        return true,'complete'
    elseif event.stage=='leave' and choice=='leave' then
        return true,'complete'
    end
    return false,'invalid_event_choice'
end
return M
