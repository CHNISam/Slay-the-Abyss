-- Vampires PC A0, fixed319009d5. Cached maxHP/Vial choice, exact starter tags,
-- reverse-order removals, then FIVE fresh Bite obtains regardless of count.
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local Hooks=require('abyss_relic_hooks')
local M={}
local strikes={Strike_R=true,Strike_G=true,Strike_B=true,Strike_P=true}
local function row(choice,title,text)return {choice=choice,title=title,description=text,enabled=true}end
local function vial(run)
    for i,id in ipairs(run.relics)do if id=='Blood Vial'or Hooks.localId(id)=='blood_vial'then return i end end
end
local function unresolved(run)
    return run.data.originalV4Role~=nil or run.characterProfile and run.characterProfile.originalV4==true
end
function M.prepare(run,event)
    assert(type(run.maxHp)=='number'and run.maxHp%1==0 and run.maxHp>=1 and run.maxHp<=2147483647,'invalid Vampires health')
    event.maxHpLoss=math.ceil(Random.float32(Random.float32(run.maxHp)*Random.float32(.3)))
    if event.maxHpLoss>=run.maxHp then event.maxHpLoss=run.maxHp-1 end
    event.hasVial=vial(run)~=nil
    event.stage,event.body='intro','吸血鬼邀请你加入它们，用噬咬取代最初的打击。'
end
function M.options(run,event)
    if event.stage=='result'then return {row('leave','离开','返回路线。')}end
    if event.stage~='intro'then return {}end
    local rows={row('accept','接受','失去 '..event.maxHpLoss..' 点最大生命，移除所有初始打击，获得5张噬咬。')}
    if event.hasVial then rows[#rows+1]=row('give_vial','交出血瓶','失去血瓶，移除所有初始打击，获得5张噬咬；不损失最大生命。')end
    rows[#rows+1]=row('leave','拒绝','不成为吸血鬼。')
    if unresolved(run)then
        for _,option in ipairs(rows)do if option.choice~='leave'then option.enabled=false;option.description='当前原创职业的初始打击源标签映射尚未确认。'end end
    end
    return rows
end
local function sourceId(run,instance)
    for _,card in ipairs(run.data.cards.cards)do if card.id==instance.cardId then return card.sourceId or card.sts_name or card.id end end
    local pools=run.data.cards.sourcePools
    local metadata=pools and pools.cardSourceMetadata and pools.cardSourceMetadata[instance.cardId]
    return metadata and metadata.sourceId or instance.cardId
end
local function replaceAttacks(run,event)
    event.removedUids={}
    for i=#run.deck,1,-1 do
        local card=run.deck[i]
        if strikes[sourceId(run,card)]then
            local matches=0
            for _,other in ipairs(run.deck)do if other.uid==card.uid then matches=matches+1 end end
            if matches~=1 then return false,'invalid_card'end
            -- Source removes STARTER_STRIKE even when upgraded/bottled. It does
            -- not preserve bottle flags on any of the newly created Bites.
            local ok,why=Run.removeCard(run,card.uid);if not ok then return false,why end
            event.removedUids[#event.removedUids+1]=card.uid
        end
    end
    event.obtainedCardUids={}
    for _=1,5 do
        local ok,why=Run.obtainCard(run,'Bite');if not ok then return false,why end
        if type(why)~='number'then return false,'invalid_bite_obtain'end
        event.obtainedCardUids[#event.obtainedCardUids+1]=why
    end
    return true
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice'end
    if event.stage=='result'and choice=='leave'then return true,'complete'end
    if event.stage~='intro'then return false,'invalid_event_choice'end
    if choice=='leave'then event.choice,event.stage,event.body=choice,'result','你拒绝了吸血鬼。';return true,'pending'end
    if choice~='accept'and choice~='give_vial'then return false,'invalid_event_choice'end
    if unresolved(run)then return false,'starter_tags_unresolved'end
    if choice=='give_vial'then
        if not event.hasVial then return false,'event_condition_unmet'end
        -- BloodVial has no onUnequip effect; source loseRelic is a no-op if the
        -- constructor-cached relic has disappeared before this command.
        local position=vial(run);if position then table.remove(run.relics,position)end
    else
        local ok,why=Run.decreaseMaxHp(run,event.maxHpLoss);if not ok then return false,why end
    end
    local ok,why=replaceAttacks(run,event);if not ok then return false,why end
    event.choice,event.stage,event.body=choice,'result','你获得了5张噬咬，成为了吸血鬼。'
    return true,'pending'
end
return M
