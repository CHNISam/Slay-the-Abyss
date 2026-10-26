-- Fixed community source: Looter.takeTurn, TASK-15.16 source ledger.
-- Source rooms use independent STS aiRng; explicit fixtures retain the LCG adapter.
local M = {}
local R=require('abyss_enemy_random')
local Actors = require("abyss_actor")
local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do if intent.id == id then enemy.intentIndex = i; return end end
    error("unknown Looter intent: " .. tostring(id))
end
function M.initialize(state, enemy, random)
    enemy.stolenGold, enemy.stolenGoldRewarded, enemy.escaped = 0, false, false
    enemy.looterSlashCount, enemy.looterQueuedIntent = 0, nil
    random(state, enemy.ai.rollRange) -- inherited opening roll, despite fixed Mug
    select(enemy, enemy.ai.mugIntent)
end
function M.preBattle(state, enemy)
    Actors.applyPower(state, enemy, "thievery", enemy.ai.stealAmount, enemy)
end
function M.beforeAction(state, enemy, random, executedIntent)
    local ai, id = enemy.ai, executedIntent.id
    enemy.looterQueuedIntent = nil
    if ai.mugger and (id==ai.mugIntent or id==ai.lungeIntent)then random(state,3) end
    if id == ai.mugIntent then
        if enemy.looterSlashCount == (ai.mugger and 1 or 0) then
            -- Source's float literal is binary32 0.6000000238418579, strictly <.
            enemy.looterTalk = R.float(state,random) < ai.talkChance
        end
        enemy.looterSlashCount = enemy.looterSlashCount + 1
        if enemy.looterSlashCount == 2 then
            if R.float(state,random) < ai.smokeChance then select(enemy, ai.smokeIntent)
            else enemy.looterQueuedIntent = ai.lungeIntent end
        else enemy.looterQueuedIntent = ai.mugIntent end
    elseif id == ai.lungeIntent then
        enemy.looterSlashCount = enemy.looterSlashCount + 1
        select(enemy, ai.smokeIntent)
    elseif id == ai.smokeIntent or id == ai.escapeIntent then
        enemy.looterQueuedIntent = ai.escapeIntent
    end
end
function M.afterAction(state, enemy)
    -- SetMoveAction has no owner-death guard; final battle cleanup is in Combat.
    if enemy.looterQueuedIntent then select(enemy, enemy.looterQueuedIntent); enemy.looterQueuedIntent = nil end
end
return M
