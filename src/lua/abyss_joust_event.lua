-- Independent behavior implementation of TheJoust.buttonEffect, fixed
-- aeubanks/sts@319009d5. Nodes owns the enclosing command transaction.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local M={}
local OWNER_CHANCE=Random.float32(0.3)
local function row(choice,title,description)
    return {choice=choice,title=title,description=description,enabled=true}
end
function M.prepare(_,event)
    event.stage='halt'
    event.body='两名决斗者拦住去路，邀请你观看一场比试。'
end
function M.options(_,event)
    if event.stage=='halt' then return {row('continue','走近','听取比试和下注规则。')} end
    if event.stage=='explanation' then
        return {row('bet_against','押挑战者','支付50金币；若挑战者获胜，获得100金币。'),
            row('bet_for','押庄园主','支付50金币；若庄园主获胜，获得250金币。')}
    end
    if event.stage=='pre_joust' then return {row('continue','开始比试','观看两名决斗者交手。')} end
    if event.stage=='joust' then return {row('continue','查看结果','查看胜者及下注结果。')} end
    if event.stage=='complete' then return {row('leave','离开','返回路线。')} end
    return {}
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='halt' and choice=='continue' then
        event.stage='explanation'
        event.body='挑战者胜出可获得100金币，庄园主胜出可获得250金币；每次下注50金币。'
    elseif event.stage=='explanation' and (choice=='bet_against' or choice=='bet_for') then
        -- Eligibility checks 50 gold before the event is drawn. The source
        -- buttons remain enabled thereafter; loseGold clamps stale funds to 0.
        event.betFor=choice=='bet_for'
        event.goldPaid=math.min(run.gold,50)
        run.gold=math.max(0,run.gold-50)
        event.stage='pre_joust'
        event.body='你已下注，决斗者准备开始比试。'
    elseif event.stage=='pre_joust' and choice=='continue' then
        -- This is the only rule-RNG call: AFTER paying and confirming the bet,
        -- BEFORE the outcome page. The 0.3f binary32 threshold is intentional.
        event.ownerWins=Random.randomBooleanChance(run.miscRng,OWNER_CHANCE)
        event.stage='joust'
        event.body='两名决斗者开始交手。'
    elseif event.stage=='joust' and choice=='continue' then
        event.won=event.betFor==event.ownerWins
        event.payout=event.won and (event.betFor and 250 or 100) or 0
        event.goldGained=event.payout>0 and Run.gainGold(run,event.payout) or 0
        event.stage='complete'
        event.body=(event.ownerWins and '庄园主获胜。' or '挑战者获胜。')..
            (event.won and '你押中了胜者，获得'..event.goldGained..'金币。' or '你押下的金币归对方所有。')
    elseif event.stage=='complete' and choice=='leave' then
        return true,'complete'
    else return false,'invalid_event_choice' end
    return true,'pending'
end
return M
