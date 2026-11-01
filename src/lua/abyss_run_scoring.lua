-- Collection adapters: staged battle facts never alias permanent run history.
local Score=require('abyss_run_score')
local M={}
function M.damage(battle,target,amount,hpLoss)
    local stats=battle.scoreStats
    if not stats then return end
    if target==battle.player then
        if not hpLoss and amount>0 then stats.nonHpLossDamage=stats.nonHpLossDamage+amount end
    elseif amount>=99 then stats.overkill=true end
end
function M.played(battle,card)
    local stats=battle.scoreStats
    if not stats or card.dontTriggerOnUseCard then return end
    stats.turnCardCount=stats.turnCardCount+1
    if stats.turnCardCount>=20 then stats.combo=true end
end
function M.startTurn(battle)
    if battle.scoreStats then battle.scoreStats.turnCardCount=0 end
end
local function countRoom(stats,facts,tier,act,outcome,allEscaped)
    if tier=='normal' then
        if not allEscaped then stats.normalWins=stats.normalWins+1 end
    elseif tier=='elite' then
        stats.eliteWins[act]=(stats.eliteWins[act]or 0)+1
        if outcome~='escaped' and facts.nonHpLossDamage==0 then stats.champion=stats.champion+1 end
    elseif tier=='boss' and outcome=='victory' then
        stats.bosses=stats.bosses+1
        if facts.nonHpLossDamage==0 then stats.perfect=stats.perfect+1 end
    end
end
function M.finishBattle(run,battle,outcome,allEscaped)
    local stats,facts=run.scoreStats,battle.scoreStats
    if not stats or not facts or facts.merged then return end
    stats.goldGained=stats.goldGained+facts.goldGained
    stats.overkill,stats.combo=stats.overkill or facts.overkill,stats.combo or facts.combo
    facts.merged=true
    if outcome=='defeat' or run.eventCombat then return end
    countRoom(stats,facts,run.encounterTier,run.act or 1,outcome,allEscaped)
end
function M.result(run,adjustment)
    if run.phase~='victory' and run.phase~='defeat' then return nil,'score_unavailable' end
    local catalog,cards={},{}
    for _,definition in ipairs(run.data.cards.cards)do catalog[definition.id]=definition end
    for _,instance in ipairs(run.deck)do
        local definition=catalog[instance.cardId]
        if not definition or not definition.sourceId then return nil,'score_unavailable' end
        cards[#cards+1]={sourceId=definition.sourceId,rarity=definition.rarity,type=definition.type}
    end
    return Score.compute({stats=run.scoreStats,floor=run.floor,maxHp=run.maxHp,
        elapsedSeconds=run.elapsedSeconds,victory=run.phase=='victory',cards=cards,
        relicCount=#run.relics,adjustment=adjustment})
end
return M
