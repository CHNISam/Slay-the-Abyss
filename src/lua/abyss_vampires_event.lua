-- Independent Vampires behavior from fixed source 319009d5; Nodes owns rollback.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local M={}
-- STARTER_STRIKE is narrower than STRIKE/attack/basic or a translated name.
local starters={Strike_R=true,Strike_G=true,Strike_B=true,Strike_P=true}
local function vial(run)
    for i,id in ipairs(run.relics or {})do if id=='blood_vial' then return i end end
end
local function row(choice,title,description)
    return {choice=choice,title=title,description=description,enabled=true}
end
function M.prepare(run,event)
    assert(type(run.maxHp)=='number' and run.maxHp%1==0 and run.maxHp>=1
        and run.maxHp<=2147483647,'invalid Vampires max health')
    local loss=math.ceil(Random.float32(Random.float32(run.maxHp)*Random.float32(0.3)))
    event.hpLoss=math.min(loss,run.maxHp-1)
    event.hasVial=vial(run)~=nil
    event.stage='intro';event.body='夜行者提出交换：舍弃初始打击，获得5张「噬咬」。'
end
function M.options(_run,event)
    if event.stage=='result' then return {row('leave','离开','返回路线。')} end
    if event.stage~='intro' then return {} end
    local rows={row('accept','接受','失去 '..event.hpLoss..' 点最大生命，移除全部初始打击，获得5张「噬咬」。')}
    if event.hasVial then rows[#rows+1]=row('give_vial','献出血瓶','失去遗物「血瓶」，移除全部初始打击，获得5张「噬咬」；不降低最大生命。')end
    rows[#rows+1]=row('leave','拒绝','不交换生命、遗物或卡牌。')
    return rows
end
local function strikeUids(run)
    if run.data.originalV4Role~=nil or run.characterProfile and run.characterProfile.originalV4==true then
        return nil,'starter_tags_unresolved'
    end
    local definitions={}
    for _,entry in ipairs(run.data.cards.cards)do definitions[entry.id]=entry end
    local sources=run.data.cards.sourcePools
    local metadata=sources and sources.cardSourceMetadata or {}
    local targets,seen={},{}
    for i=#run.deck,1,-1 do
        local card=run.deck[i];local definition=definitions[card.cardId]
        local sourceId=definition and definition.sourceId or metadata[card.cardId] and metadata[card.cardId].sourceId
            or definition and definition.id
        if starters[sourceId] then
            if not definition then return nil,'card_content_unavailable' end
            if type(card.uid)~='number' or card.uid%1~=0 or card.uid<=0 or seen[card.uid] then return nil,'invalid_card' end
            seen[card.uid]=true;targets[#targets+1]=card.uid
        end
    end
    return targets
end
local function exchange(run,event,choice)
    local targets,why=strikeUids(run);if not targets then return false,why end
    if choice=='give_vial' then
        local position=vial(run)
        if not event.hasVial or not position then return false,'event_condition_unmet' end
        -- BloodVial inherits the source's empty onUnequip; no generic relic API.
        -- Removing canonical ownership stops its future atBattleStart healing.
        table.remove(run.relics,position);event.lostRelicId='blood_vial'
    else
        local ok;ok,why=Run.decreaseMaxHp(run,event.hpLoss);if not ok then return false,why end
    end
    for _,uid in ipairs(targets)do
        local ok;ok,why=Run.removeCard(run,uid);if not ok then return false,why end
    end
    local obtained={}
    for _=1,5 do
        local ok;ok,why=Run.obtainCard(run,'bite');if not ok then return false,why end
        if type(why)~='number' then return false,'invalid_bite_obtain' end
        obtained[#obtained+1]=why
    end
    event.removedCardUids,event.obtainedCardUids=targets,obtained
    event.body=choice=='give_vial' and '你献出血瓶，换得5张「噬咬」。初始打击已移除，最大生命不变。'
        or '你舍弃了部分最大生命与全部初始打击，获得5张「噬咬」。当前最大生命为 '..run.maxHp..'。'
    return true
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='result' and choice=='leave' then return true,'complete' end
    if event.stage~='intro' or choice~='accept' and choice~='give_vial' and choice~='leave' then
        return false,'invalid_event_choice'
    end
    if choice=='leave' then event.body='你拒绝了交换，保留原有的生命、遗物与牌组。'
    else local ok,why=exchange(run,event,choice);if not ok then return false,why end end
    event.choice,event.stage=choice,'result';return true,'pending'
end
return M
