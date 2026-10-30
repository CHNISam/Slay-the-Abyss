-- CursedTome PC A0, source 319009d5. Each page is its own committed command;
-- the final payment/draw and the later optional relic claim are NOT one obtain.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local Hooks=require('abyss_relic_hooks')
local M={}
local books={{sourceId='Necronomicon',id='necronomicon'},
    {sourceId='Enchiridion',id='enchiridion'},{sourceId="Nilry's Codex",id='nilrys_codex'}}
local function row(choice,title,text)return {choice=choice,title=title,description=text,enabled=true}end
local function owns(run,book)
    for _,id in ipairs(run.relics)do
        if id==book.sourceId or Hooks.localId(id)==book.id then return true end
    end
    return false
end
function M.prepare(_run,event)
    event.stage,event.damageTaken='intro',0
    event.body='一本被诅咒的古书躺在石台上。'
end
function M.options(_run,event)
    if event.stage=='intro'then return {row('read','阅读','翻开古书。'),row('leave','离开','不阅读古书。')}end
    local amount=({page_1=1,page_2=2,page_3=3})[event.stage]
    if amount then return {row('continue','继续','失去 '..amount..' 点生命，继续阅读。')}end
    if event.stage=='last_page'then return {row('obtain','拿走古书','失去10点生命，打开古书遗物奖励。'),
        row('stop','停止阅读','失去3点生命，不获得古书。')}end
    if event.stage=='reward'then return {row('claim','领取 '..event.book.sourceId,'领取这件已抽定的古书遗物。'),
        row('skip','跳过奖励','不领取遗物；已经支付的生命不会返还。')}end
    if event.stage=='result'then return {row('leave','离开','返回路线。')}end
    return {}
end
function M.view(_run,event)
    if event.stage=='reward'then event.relicReward={id=event.book.id,sourceId=event.book.sourceId,claimed=false}end
end
local function damage(run,event,amount)
    local ok,why=Run.eventDamage(run,amount)
    if not ok then return false,why end
    -- Source metrics count requested damage, not Tungsten/Fairy-adjusted loss.
    event.damageTaken=event.damageTaken+amount
    return true
end
local function drawBook(run,event)
    local candidates={}
    for _,book in ipairs(books)do if not owns(run,book)then candidates[#candidates+1]=book end end
    if #candidates==0 then candidates[1]={sourceId='Circlet',id='circlet'}end
    local selected=candidates[Random.randomInt(run.miscRng,#candidates-1)+1]
    event.book={sourceId=selected.sourceId,id=selected.id}
    event.stage,event.body='reward','你读完了古书。可以领取遗物，或放弃这份奖励。'
    return true,'pending'
end
local function chooseReward(run,event,choice)
    if choice=='claim'then
        local ok,why=Run.obtainRelic(run,event.book.sourceId)
        if not ok then return false,why end
        event.obtainedRelicId=why
    elseif choice~='skip'then return false,'invalid_event_choice'end
    event.rewardChoice,event.stage=choice,'result'
    event.body=choice=='claim'and'你拿走了古书。'or'你留下了古书。'
    return true,'pending'
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice'end
    if event.stage=='result'and choice=='leave'then return true,'complete'end
    if event.stage=='reward'then return chooseReward(run,event,choice)end
    if event.stage=='intro'then
        if choice=='leave'then event.stage,event.body='result','你没有翻开古书。';return true,'pending'end
        if choice~='read'then return false,'invalid_event_choice'end
        event.stage,event.body='page_1','书页上记载着古老的秘密。';return true,'pending'
    end
    local amount=({page_1=1,page_2=2,page_3=3})[event.stage]
    if amount then
        if choice~='continue'then return false,'invalid_event_choice'end
        local ok,why=damage(run,event,amount);if not ok then return false,why end
        event.stage=({page_1='page_2',page_2='page_3',page_3='last_page'})[event.stage]
        event.body='你继续阅读，已经支付 '..event.damageTaken..' 点生命。'
        return true,'pending'
    end
    if event.stage~='last_page'or(choice~='obtain'and choice~='stop')then return false,'invalid_event_choice'end
    local ok,why=damage(run,event,choice=='obtain'and 10 or 3);if not ok then return false,why end
    if choice=='obtain'then return drawBook(run,event)end
    event.stage,event.body='result','你合上古书，停止阅读。'
    return true,'pending'
end
return M
