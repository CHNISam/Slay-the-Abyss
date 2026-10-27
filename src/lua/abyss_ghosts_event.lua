-- Ghosts A0 at fixed STS source 319009d5. Nodes owns atomicity, including
-- the health cost and each real permanent obtain; this event owns no RNG.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local M={}
local function row(choice,title,description)
    return {choice=choice,title=title,description=description,enabled=true}
end
function M.prepare(run,event)
    assert(type(run.maxHp)=='number' and run.maxHp%1==0 and run.maxHp>=1
        and run.maxHp<=2147483647,'invalid Ghosts max health')
    local loss=math.ceil(Random.float32(Random.float32(run.maxHp)*0.5))
    if loss>=run.maxHp then loss=run.maxHp-1 end
    event.hpLoss,event.stage=loss,'intro'
    event.body='幽灵邀请你加入它们：以最大生命为代价，获得5张「幻影」。'
end
function M.options(_run,event)
    if event.stage=='intro' then
        return {row('accept','接受','失去 '..event.hpLoss..' 点最大生命，获得5张「幻影」。'),
            row('leave','拒绝','不失去最大生命，也不获得卡牌。')}
    elseif event.stage=='result' then return {row('leave','离开','返回路线。')} end
    return {}
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='result' and choice=='leave' then return true,'complete' end
    if event.stage~='intro' or (choice~='accept' and choice~='leave') then return false,'invalid_event_choice' end
    if choice=='leave' then
        event.choice,event.stage='leave','result';event.body='你拒绝了幽灵的邀请，准备离开。'
        return true,'pending'
    end
    local before=run.maxHp
    local ok,why=Run.decreaseMaxHp(run,event.hpLoss)
    if not ok then return false,why end
    -- Do not precompute hook plans before paying: every fresh UID and obtain
    -- hook must see the post-cost current state and earlier successful obtains.
    local uids={}
    for _=1,5 do
        ok,why=Run.obtainCard(run,'apparition')
        if not ok then return false,why end
        if type(why)~='number' then return false,'invalid_apparition_obtain' end
        uids[#uids+1]=why
    end
    event.obtainedCardUids,event.choice,event.stage=uids,'accept','result'
    event.body='你获得了5张「幻影」。最大生命从 '..before..' 降为 '..run.maxHp..'。'
    return true,'pending'
end
return M
