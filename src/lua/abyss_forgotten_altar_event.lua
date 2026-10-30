-- ForgottenAltar PC A0 at source 319009d5. Constructor caches rounded cost;
-- Shed Blood gains/heals maxHP BEFORE NORMAL damage. No unconditional Leave.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local Hooks=require('abyss_relic_hooks')
local M={}
local function row(choice,title,text,enabled)return {choice=choice,title=title,description=text,enabled=enabled~=false}end
local function owns(run,id,source)
    for _,held in ipairs(run.relics)do if held==source or Hooks.localId(held)==id then return true end end
    return false
end
function M.prepare(run,event)
    assert(type(run.maxHp)=='number'and run.maxHp%1==0 and run.maxHp>=1 and run.maxHp<=2147483647,'invalid Altar health')
    -- Preserve Java float multiplication before positive MathUtils rounding.
    local scaled=Random.float32(Random.float32(run.maxHp)*Random.float32(.25))
    event.hpLoss=math.floor(scaled+.5)
    event.hasIdol=owns(run,'golden_idol','Golden Idol')
    event.stage,event.body='intro','一座被遗忘的祭坛仍等待着供奉。'
end
function M.options(_run,event)
    if event.stage=='result'then return {row('leave','离开','返回路线。')}end
    if event.stage~='intro'then return {}end
    return {row('offer_idol','献上黄金神像','以黄金神像换取血色神像。',event.hasIdol),
        row('shed_blood','献血','获得5点最大生命，然后受到 '..event.hpLoss..' 点普通伤害。'),
        row('smash','砸毁祭坛','获得诅咒「腐朽」。')}
end
local function gainChalice(run,event)
    if not event.hasIdol or not owns(run,'golden_idol','Golden Idol')then return false,'event_condition_unmet'end
    local id=owns(run,'bloody_idol','Bloody Idol')and'Circlet'or'Bloody Idol'
    -- Bloody Idol's source replacement must occupy the Golden Idol slot.
    -- Missing dependency metadata is a refusal, not append-then-delete reward.
    if id=='Bloody Idol'then
        local definition
        for _,r in ipairs(run.data.relics.relics)do if r.id=='bloody_idol'or r.sourceId==id then definition=r;break end end
        if not definition or definition.replaces~='golden_idol'then return false,'relic_content_unavailable'end
    end
    local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
    event.obtainedRelicId=why;return true
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice'end
    if event.stage=='result'and choice=='leave'then return true,'complete'end
    if event.stage~='intro'then return false,'invalid_event_choice'end
    local ok,why
    if choice=='offer_idol'then ok,why=gainChalice(run,event)
    elseif choice=='shed_blood'then
        ok,why=Run.increaseMaxHp(run,5);if not ok then return false,why end
        ok,why=Run.eventNormalDamage(run,event.hpLoss)
    elseif choice=='smash'then
        ok,why=Run.obtainCard(run,'Decay')
        if ok then event.obtainedCardUid=type(why)=='number'and why or nil;event.curseBlocked=why=='curse_blocked'end
    else return false,'invalid_event_choice'end
    if not ok then return false,why end
    event.choice,event.stage=choice,'result';event.body='你完成了对祭坛的选择，准备离开。'
    return true,'pending'
end
return M
