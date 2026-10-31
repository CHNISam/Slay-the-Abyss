-- Act2 behavior derived from aeubanks/sts at 319009d5 (not Java code).
-- Nodes owns each command's transaction. Payment and removal are separate
-- commands: a failed permanent remove must never refund an earlier donation.
local Run=require('abyss_run')
local Purge=require('abyss_living_wall')
local Random=require('abyss_sts_random')
local Basics=require('abyss_back_to_basics')
local Joust=require('abyss_joust_event')
local Library=require('abyss_library_event')
local Ghosts=require('abyss_ghosts_event')
local Nest=require('abyss_nest_event')
local Duplicator=require('abyss_duplicator_event')
local M={ids={beggar=true,mausoleum=true,addict=true,back_to_basics=true,joust=true,the_library=true,ghosts=true,nest=true,duplicator=true}}
local GOLD_COST=75

for _,id in ipairs({'colosseum','masked_bandits','cursed_tome','forgotten_altar','drug_dealer','vampires'})do M.ids[id]=true end
local function extension(id)
    if id=='colosseum'then return require('abyss_colosseum_event')end
    if id=='masked_bandits'then return require('abyss_masked_bandits_event')end
    if id=='cursed_tome'then return require('abyss_cursed_tome_event')end
    if id=='forgotten_altar'then return require('abyss_forgotten_altar_event')end
    if id=='drug_dealer'then return require('abyss_drug_dealer_event')end
    if id=='vampires'then return require('abyss_vampires_event')end
end
function M.prepare(run,event,miscRng,floor)
    local extra=extension(event.id);if extra then return extra.prepare(run,event,miscRng,floor)end
    if event.id=='duplicator' then return Duplicator.prepare(run,event) end
    if event.id=='nest' then return Nest.prepare(run,event) end
    if event.id=='joust' then return Joust.prepare(run,event) end
    if event.id=='ghosts' then return Ghosts.prepare(run,event) end
    if event.id=='the_library' then return Library.prepare(run,event) end
    if event.id=='back_to_basics' then return Basics.prepare(run,event) end
    event.stage='intro'
    if event.id=='addict' then event.body='一位商贩提供一件遗物，价格是85金币。';return end
    event.body=event.id=='mausoleum' and '一座古墓中放着封闭的石棺。' or '一位乞丐向你请求75金币。'
end

local function row(choice,title,description,enabled,picker)
    return {choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
end

function M.options(run,event)
    local extra=extension(event.id);if extra then return extra.options(run,event)end
    if event.id=='duplicator' then return Duplicator.options(run,event) end
    if event.id=='nest' then return Nest.options(run,event) end
    if event.id=='joust' then return Joust.options(run,event) end
    if event.id=='ghosts' then return Ghosts.options(run,event) end
    if event.id=='the_library' then return Library.options(run,event) end
    if event.id=='back_to_basics' then return Basics.options(run,event) end
    if event.id=='addict' then
        if event.stage=='intro' then
            return {row('buy','支付85金币','获得一件随机遗物。',run.gold>=85),
                row('steal','偷取遗物','获得一件随机遗物和诅咒「羞惭」。'),
                row('leave','离开','不获取遗物。')}
        elseif event.stage=='result' then return {row('leave','离开','返回路线。')} end
        return {}
    end
    if event.id=='mausoleum' then
        if event.stage=='intro' then
            return {row('open','打开石棺','获得随机遗物；50%概率获得诅咒「蜷缩」。'),
                row('leave','离开','不打开石棺。')}
        elseif event.stage=='result' then return {row('leave','离开','返回路线。')} end
        return {}
    end
    if event.stage=='intro' then
        return {row('donate','施舍75金币','支付75金币，然后选择移除一张卡牌。',run.gold>=GOLD_COST),
            row('leave','离开','不支付金币。')}
    elseif event.stage=='gave_money' then
        return {row('confirm','继续','已支付75金币；接下来查看可移除的卡牌。')}
    elseif event.stage=='choose_card' then
        if #Purge.purgeCards(run)==0 then
            return {row('leave','离开','没有可移除的卡牌；已支付的75金币不退还，返回路线。')}
        end
        return {row('purge','移除卡牌','必须选择一张非瓶装、可清除的永久牌；不能跳过。',
            #Purge.purgeCards(run)>0,'beggar_purge')}
    elseif event.stage=='leave' then
        return {row('leave','离开','返回路线。')}
    end
    return {}
end

local function chooseAddict(run,event,choice,uid)
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='result' then
        if choice=='leave' then return true,'complete' end
        return false,'invalid_event_choice'
    end
    if event.stage~='intro' then return false,'invalid_event_choice' end
    if choice=='leave' then return true,'complete' end
    if choice~='buy' and choice~='steal' then return false,'invalid_event_choice' end
    if choice=='buy' and run.gold<85 then return false,'insufficient_gold' end
    -- Unlike Mausoleum, Addict selects the source screenless relic BEFORE
    -- constructing the delayed curse effect. Unsupported content refuses the
    -- enclosing Nodes transaction, never rerolls against implemented content.
    local offer,nextPool=Run.prepareRelic(run,{channel='event',screenless=true,room='event'})
    if not offer then return false,nextPool end
    local card,why
    if choice=='steal' then
        card,why=Run.prepareCard(run,'Shame');if not card then return false,why end
    else run.gold=run.gold-85 end
    local ok,id=Run.obtainRelic(run,offer.id);if not ok then return false,id end
    event.obtainedRelicId=id
    if card then
        ok,why=Run.commitCard(run,card);if not ok then return false,why end
        event.obtainedCardUid=type(why)=='number' and why or nil
        event.curseBlocked=why=='curse_blocked'
    end
    run.relicPool=nextPool
    event.relicOffer,event.choice=offer,choice
    event.stage='result'
    event.body=choice=='buy' and '你支付85金币，获得了一件遗物。' or
        ('你取得了一件遗物。'..(event.curseBlocked and '诅咒已被御守阻止。' or '诅咒「羞惭」已加入牌组。'))
    return true,'pending'
end

local function chooseMausoleum(run,event,choice,uid)
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='result' then
        if choice=='leave' then return true,'complete' end
        return false,'invalid_event_choice'
    end
    if event.stage~='intro' then return false,'invalid_event_choice' end
    if choice=='leave' then
        event.stage='result';event.body='你没有打开石棺，准备离开。'
        return true,'pending'
    end
    if choice~='open' then return false,'invalid_event_choice' end
    -- A0: one room misc boolean, before either card or relic acquisition.
    -- Prepare the delayed curse against OLD Omamori before selecting/equipping
    -- the relic. Its later onObtain hooks see the NEW relic (e.g. Ceramic Fish).
    -- Nodes owns the enclosing transaction: unsupported relics fail closed,
    -- rolling back this boolean, curse protection, pools and all reward hooks.
    local cursed=Random.randomBoolean(run.miscRng)
    local card,why
    if cursed then
        card,why=Run.prepareCard(run,'Writhe');if not card then return false,why end
    end
    local offer,nextPool=Run.prepareRelic(run,{channel='event',screenless=true,room='event'})
    if not offer then return false,nextPool end
    local ok,id=Run.obtainRelic(run,offer.id);if not ok then return false,id end
    event.obtainedRelicId=id
    if card then
        ok,why=Run.commitCard(run,card);if not ok then return false,why end
        event.obtainedCardUid=type(why)=='number' and why or nil
        event.curseBlocked=why=='curse_blocked'
    end
    run.relicPool=nextPool
    event.relicOffer,event.cursed=offer,cursed
    event.stage='result'
    event.body='你打开了石棺，获得一件遗物。'..(cursed and
        (event.curseBlocked and '诅咒已被御守阻止。' or '诅咒「蜷缩」已加入牌组。') or '没有获得诅咒。')
    return true,'pending'
end

-- Only enrich the detached Nodes view, never the permanent owner. The source
-- opens even an empty mandatory grid. Our explicit empty-only exit prevents
-- a softlock; it is a local safety deviation, not proven source completion.
function M.view(run,event)
    local extra=extension(event.id);if extra then if extra.view then extra.view(run,event)end;return end
    if event.id=='duplicator' then
        if event.stage=='choose_card' then
            event.copyCards=Duplicator.cards(run)
            event.selection={count=1,canCancel=false,forPurge=false,anyNumber=false}
        end
        return
    end
    if event.id=='the_library' then return Library.view(run,event) end
    if event.id=='back_to_basics' then return Basics.view(run,event) end
    if event.stage~='choose_card' then return end
    event.purgeCards=Purge.purgeCards(run)
    event.selection={count=1,canCancel=false,forPurge=true,anyNumber=false}
    if #event.purgeCards==0 then event.body='没有可移除的卡牌。已支付75金币，可以离开。' end
end

function M.choose(run,flow,choice,uid,upgradeable)
    local extra=extension(flow.event.id);if extra then return extra.choose(run,flow,choice,uid)end
    if flow.event.id=='duplicator' then return Duplicator.choose(run,flow,choice,uid) end
    if flow.event.id=='nest' then return Nest.choose(run,flow,choice,uid) end
    if flow.event.id=='the_library' then return Library.choose(run,flow,choice,uid) end
    if flow.event.id=='joust' then return Joust.choose(run,flow,choice,uid) end
    local event=flow.event
    if event.id=='ghosts' then return Ghosts.choose(run,flow,choice,uid) end
    if event.id=='back_to_basics' then return Basics.choose(run,flow,choice,uid,upgradeable) end
    if event.id=='addict' then return chooseAddict(run,event,choice,uid) end
    if event.id=='mausoleum' then return chooseMausoleum(run,event,choice,uid) end
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
        event.body='已支付75金币。请查看下方选项。'
        return true,'choose_card'
    elseif event.stage=='choose_card' then
        -- Recheck live candidates: a stale empty-screen leave cannot skip a card.
        if choice=='leave' and uid==nil and #Purge.purgeCards(run)==0 then
            event.stage='result';event.body='没有可移除的卡牌。你离开了，已支付的75金币不退还。'
            return true,'complete'
        end
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
