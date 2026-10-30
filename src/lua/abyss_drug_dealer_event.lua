-- DrugDealer (Augmenter), PC A0 at319009d5. The transform branch requires
-- exactly TWO ordered object identities. Both removals/draws precede obtains.
local Run=require('abyss_run')
local Combat=require('abyss_combat')
local Transform=require('abyss_transform_card')
local Context=require('abyss_event_transform_context')
local Capability=require('abyss_card_capability')
local Hooks=require('abyss_relic_hooks')
local M={}
local protected={Necronomicurse=true,CurseOfTheBell=true,AscendersBane=true,
    necronomicurse=true,curse_of_the_bell=true,ascenders_bane=true}
local function row(choice,title,text,enabled,picker)
    return {choice=choice,title=title,description=text,enabled=enabled~=false,picker=picker}
end
local function definition(run,id)
    for _,card in ipairs(run.data.cards.cards)do if card.id==id then return card end end
end
local function sourceId(run,card)
    local d=definition(run,card.cardId)
    local pools=run.data.cards.sourcePools
    local meta=pools and pools.cardSourceMetadata and pools.cardSourceMetadata[card.cardId]
    return d and(d.sourceId or d.sts_name or d.id)or meta and meta.sourceId or card.cardId
end
function M.transformCards(run)
    local cards={}
    for _,card in ipairs(run.deck)do
        if not protected[card.cardId]and not protected[sourceId(run,card)]then cards[#cards+1]=Combat.copy(card)end
    end
    return cards
end
function M.prepare(run,event)
    event.canTransform=#M.transformCards(run)>=2
    event.stage,event.body='intro','一位增幅师提供三种实验方案。'
end
function M.options(_run,event)
    if event.stage=='intro'then return {row('jax','服用激素','获得1张J.A.X.。'),
        row('test_subject','成为实验对象','必须选择2张可清除卡牌，将它们转化。',event.canTransform),
        row('mutagens','注射诱变剂','获得突变力量；已拥有时获得Circlet。')}end
    if event.stage=='choose_card'then return {row('transform','转化两张卡牌','按选择顺序转化两张卡牌，不能跳过或少选。',true,'drug_dealer_transform')}end
    if event.stage=='result'then return {row('leave','离开','返回路线。')}end
    return {}
end
function M.view(run,event)
    if event.stage~='choose_card'then return end
    event.transformCards=M.transformCards(run)
    event.selectionCards=event.transformCards
    event.selection={count=2,canCancel=false,forTransform=false,forUpgrade=false,forPurge=false,anyNumber=false}
end
local function selectedPair(run,uids)
    if type(uids)~='table'or getmetatable(uids)~=nil then return nil,'invalid_card_selection'end
    local count=0
    for key in pairs(uids)do if key~=1 and key~=2 then return nil,'invalid_card_selection'end;count=count+1 end
    if count~=2 or uids[1]==uids[2]then return nil,'invalid_card_selection'end
    local targets={}
    local allowed={};for _,card in ipairs(M.transformCards(run))do allowed[card.uid]=true end
    for i,uid in ipairs(uids)do
        local matches=0
        for _,card in ipairs(run.deck)do if card.uid==uid then matches=matches+1;targets[i]=card end end
        if type(uid)~='number'or uid%1~=0 or uid<1 or matches~=1 then return nil,'invalid_card'end
        if not allowed[uid]then return nil,'card_not_purgeable'end
    end
    return targets
end
local function transformPair(run,event,uids)
    local targets,why=selectedPair(run,uids);if not targets then return false,why end
    local context=run.transformContext or Context.new(run)
    if type(context)~='table'or type(context.cards)~='table'or type(context.sourceToLocal)~='table'then return false,'event_content_unavailable'end
    local outputs={}
    event.removedUids,event.obtainedSourceIds={},{}
    for i,card in ipairs(targets)do
        local original=context.cards[card.cardId]
        if type(original)~='table'then return false,'event_content_unavailable'end
        local ok,reason=Run.removeCard(run,card.uid);if not ok then return false,reason end
        local transformed,rng=Transform.select(original.category,original.sourceId,context.pools,run.miscRng)
        if not transformed then return false,rng end
        local id=context.sourceToLocal[transformed.cardId]
        if not Capability.isImplemented(definition(run,id))then return false,'event_content_unavailable'end
        run.miscRng=rng
        event.removedUids[i],event.obtainedSourceIds[i]=card.uid,transformed.cardId
        outputs[i]=id
    end
    event.obtainedCardUids,event.curseBlocked={},{}
    for i,id in ipairs(outputs)do
        local ok,obtained=Run.obtainCard(run,id);if not ok then return false,obtained end
        event.obtainedCardUids[i]=type(obtained)=='number'and obtained or false
        event.curseBlocked[i]=obtained=='curse_blocked'
    end
    event.stage,event.body='result','实验完成，两张卡牌已经转化。'
    return true,'pending'
end
local function mutagens(run,event)
    local id='MutagenicStrength'
    for _,held in ipairs(run.relics)do if held==id or Hooks.localId(held)=='mutagenic_strength'then id='Circlet';break end end
    local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
    event.obtainedRelicId=why;return true
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if event.stage=='choose_card'then
        if choice~='transform'then return false,'invalid_event_choice'end
        return transformPair(run,event,uid)
    end
    if uid~=nil then return false,'invalid_event_choice'end
    if event.stage=='result'and choice=='leave'then return true,'complete'end
    if event.stage~='intro'then return false,'invalid_event_choice'end
    if choice=='test_subject'then
        if not event.canTransform then return false,'event_condition_unmet'end
        event.choice,event.stage,event.body='transform','choose_card','必须选择2张可清除卡牌进行转化。'
        return true,'choose_card'
    end
    local ok,why
    if choice=='jax'then
        ok,why=Run.obtainCard(run,'J.A.X.');if ok then event.obtainedCardUid=why end
    elseif choice=='mutagens'then ok,why=mutagens(run,event)
    else return false,'invalid_event_choice'end
    if not ok then return false,why end
    event.choice,event.stage,event.body=choice,'result','你完成了增幅实验。'
    return true,'pending'
end
return M
