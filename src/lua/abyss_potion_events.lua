-- Fixed 319009d5 Lab/WomanInBlue: each RewardItem uses the no-argument
-- PotionHelper uniform class pool, not the rarity-rejection reward sampler.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local P=require('abyss_potion_random')
local H=require('abyss_relic_hooks')
local M={ids={lab=true,woman_in_blue=true}}
local function find(list,id)for _,value in ipairs(list)do if value.id==id then return value end end end
local function row(choice,title,description,enabled)return {choice=choice,title=title,description=description,enabled=enabled~=false}end
local function result(event,text)event.stage,event.body='result',text;return true,'pending'end
local function rewards(run,event,count)
    local entries=P.pool(P.character(run))
    local rng=run.shopRng and R.cloneState(run.shopRng.potion) or R.fromSeed(run.eventSeed)
    local offers={}
    for i=1,count do
        local index=R.randomIntBetween(rng,0,#entries-1)
        local selected=entries[index+1]
        if not find(run.data.potions.potions,selected.id)then return false,'unknown_potion' end
        offers[i]={id=selected.id,sourceId=selected.sourceId,sourceIndex=index,claimed=false}
    end
    run.shopRng=run.shopRng or {merchant=R.fromSeed(run.eventSeed)}
    run.shopRng.potion=rng
    event.potionOffers,event.stage=offers,'potion_rewards'
    event.body='选择要领取的药水。背包已满时可先打开药水背包处理，也可以放弃余下奖励。'
    return true,'pending'
end
function M.options(run,event)
    if event.stage=='result' then return {row('leave','离开','返回路线。')} end
    if event.stage=='potion_rewards' then
        local rows={}
        local full=Run.potionCount(run)>=Run.potionCapacity(run)
        local blocked=H.owns(run,'sozu')
        for i,offer in ipairs(event.potionOffers)do
            local definition=find(run.data.potions.potions,offer.id)
            local text=offer.claimed and (offer.blocked and '遗物阻止了领取。' or '已经领取。')
                or blocked and '遗物阻止获得药水，点击后放弃本项。'
                or full and '药水槽已满，请先在药水背包腾出空间。' or '领取到第一个空药水槽。'
            local entry=row('claim_'..i,definition and definition.name or offer.sourceId,text,
                not offer.claimed and (blocked or not full))
            entry.potionId=offer.id;rows[#rows+1]=entry
        end
        rows[#rows+1]=row('leave','继续','放弃尚未领取的药水。')
        return rows
    end
    if event.id=='lab' then return {row('take','收下药水','展示三瓶随机药水，可分别领取或放弃。')} end
    return {row('buy_1','购买1瓶','支付20金币，展示1瓶随机药水。',run.gold>=20),
        row('buy_2','购买2瓶','支付30金币，展示2瓶随机药水。',run.gold>=30),
        row('buy_3','购买3瓶','支付40金币，展示3瓶随机药水。',run.gold>=40),
        row('leave','离开','不购买药水，免费离开。')}
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='result' then
        if choice~='leave' then return false,'invalid_event_choice' end
        return true,'complete'
    elseif event.stage=='potion_rewards' then
        if choice=='leave' then return result(event,'你收好已领取的药水，准备离开。') end
        local index=type(choice)=='string' and choice:match('^claim_([123])$')
        local offer=index and event.potionOffers[tonumber(index)]
        if not offer or offer.claimed then return false,'invalid_event_choice' end
        if not find(run.data.potions.potions,offer.id)then return false,'unknown_potion' end
        if H.owns(run,'sozu')then offer.claimed,offer.blocked=true,true;return true,'pending' end
        local ok,slot=Run.obtainPotion(run,offer.id);if not ok then return false,slot end
        offer.claimed,offer.obtainedSlot=true,slot
        return true,'pending'
    elseif event.stage then return false,'invalid_event_choice'
    elseif event.id=='lab' then
        if choice~='take' then return false,'invalid_event_choice' end
        return rewards(run,event,3)
    elseif event.id=='woman_in_blue' then
        if choice=='leave' then return result(event,'你谢绝了药水，继续赶路。') end
        local count=type(choice)=='string' and choice:match('^buy_([123])$')
        count=count and tonumber(count)
        if not count then return false,'invalid_event_choice' end
        local cost=({20,30,40})[count]
        if run.gold<cost then return false,'insufficient_gold' end
        -- Event loseGold does not fire the ShopRoom-only onSpendGold hook.
        run.gold=run.gold-cost
        return rewards(run,event,count)
    end
    return false,'invalid_event_choice'
end
return M
