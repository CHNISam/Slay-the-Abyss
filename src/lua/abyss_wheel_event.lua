-- Fixed 319009d5 GremlinWheelGame gameplay stages. Visual wheel rotation is
-- presentation-only entropy; exactly one misc draw determines the real result.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Purge=require('abyss_living_wall')
local M={}
local function row(choice,title,description)return {choice=choice,title=title,description=description,enabled=true}end
local function result(event,text)event.stage,event.body='result',text;return true,'pending'end
function M.prepare(run,event)event.goldAmount=100*(run.act or 1)end
function M.options(_,event)
    if event.stage=='result' then return {row('leave','离开','返回路线。')} end
    if event.stage=='choose_card' then return {row('purge','移除','必须选择一张卡牌移除。')} end
    if event.stage=='relic_reward' then return {row('claim_relic','领取遗物','收下本次抽中的遗物。'),row('skip_relic','跳过遗物','放弃本次遗物奖励。')} end
    if event.stage=='wheel_result' then return {row('accept','接受结果','确认转轮已经决定的结果。')} end
    return {row('spin','转动转轮','接受转轮随机决定的六种结果之一。')}
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil and event.stage~='choose_card' then return false,'invalid_event_choice' end
    if event.stage=='result' then
        if choice~='leave' then return false,'invalid_event_choice' end
        return true,'complete'
    elseif not event.stage then
        if choice~='spin' then return false,'invalid_event_choice' end
        event.outcome=R.randomIntBetween(run.miscRng,0,5)
        event.stage='wheel_result'
        local descriptions={
            '转轮停在金币上。获得'..event.goldAmount..'金币。',
            '转轮停在遗物上。确认后展示一件随机遗物。',
            '转轮停在治疗上。确认后回复全部生命。',
            '转轮停在诅咒上。确认后获得诅咒「腐朽」。',
            '转轮停在移除上。确认后选择一张卡牌移除。',
            '转轮停在伤害上。确认后失去最大生命10%的生命。',
        }
        event.body=descriptions[event.outcome+1]
        -- Source preApplyResult pays only Gold before the result button.
        if event.outcome==0 then event.goldGained=Run.gainGold(run,event.goldAmount) end
        return true,'pending'
    elseif event.stage=='wheel_result' then
        if choice~='accept' then return false,'invalid_event_choice' end
        local outcome=event.outcome
        if outcome==0 then return result(event,'获得'..event.goldGained..'金币。')
        elseif outcome==1 then
            local offer,pool=Run.prepareRelic(run,{channel='event',screenless=true,room='event'})
            if not offer then return false,pool end
            run.relicPool=pool;event.relicOffer=offer;event.stage='relic_reward'
            event.body='转轮赠予你一件遗物。可以领取，也可以放弃。'
            return true,'pending'
        elseif outcome==2 then return result(event,'回复'..Run.heal(run,run.maxHp)..'点生命。')
        elseif outcome==3 then
            local ok,obtained=Run.obtainCard(run,'Decay');if not ok then return false,obtained end
            event.obtainedCardUid=type(obtained)=='number' and obtained or nil
            event.curseBlocked=obtained=='curse_blocked'
            return result(event,event.curseBlocked and '诅咒已被御守阻止。' or '诅咒「腐朽」已加入牌组。')
        elseif outcome==4 then
            if #Purge.purgeCards(run)==0 then return result(event,'没有可移除的卡牌。') end
            event.stage,event.choice='choose_card','purge';event.body='选择一张非瓶装可清除卡牌移除。'
            return true,'choose_card'
        elseif outcome==5 then
            local damage=math.floor(R.float32(R.float32(run.maxHp)*R.float32(.1)))
            run.hp=math.max(0,run.hp-damage);event.damage=damage
            return result(event,'失去'..damage..'点生命。')
        end
    elseif event.stage=='relic_reward' then
        if choice=='skip_relic' then return result(event,'你放弃了遗物奖励。') end
        if choice~='claim_relic' then return false,'invalid_event_choice' end
        local ok,id=Run.obtainRelic(run,event.relicOffer.id);if not ok then return false,id end
        event.obtainedRelicId=id
        return result(event,'转轮的遗物已收入行囊。')
    elseif event.stage=='choose_card' then
        if choice~='purge' then return false,'invalid_event_choice' end
        local eligible=false
        for _,card in ipairs(Purge.purgeCards(run))do if card.uid==uid then eligible=true end end
        if not eligible then return false,'card_not_purgeable' end
        local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
        event.removedUid=uid
        return result(event,'所选卡牌已移除。')
    end
    return false,'invalid_event_choice'
end
return M
