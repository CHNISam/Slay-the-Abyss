-- Act 1 / A0; fixed evidence and RNG limits: TASK-15-red-slaver-ai.md.
local M = {}
local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Red Slaver intent: " .. tostring(id))
end

function M.choose(ai, usedEntangle, last, previous, roll)
    if not usedEntangle and roll >= ai.entangleCutoff then return ai.entangleIntent end
    if usedEntangle and roll >= ai.stabCutoff
        and not (last == ai.stabIntent and previous == ai.stabIntent) then return ai.stabIntent end
    if last ~= ai.scrapeIntent or previous ~= ai.scrapeIntent then return ai.scrapeIntent end
    return ai.stabIntent
end

function M.initialize(state, enemy, random)
    enemy.redLast, enemy.redPrevious, enemy.redUsedEntangle = nil, nil, false
    random(state, enemy.ai.rollRange) -- firstTurn ignores the already-consumed roll
    select(enemy, enemy.ai.stabIntent)
end

function M.beforeAction(enemy)
    -- takeTurn marks the net spent when queuing ApplyPower, regardless of
    -- Artifact's later result. Selection alone must not spend it.
    if enemy.intents[enemy.intentIndex].id == enemy.ai.entangleIntent then enemy.redUsedEntangle = true end
end

function M.advance(state, enemy, random)
    enemy.redPrevious, enemy.redLast = enemy.redLast, enemy.intents[enemy.intentIndex].id
    select(enemy, M.choose(enemy.ai, enemy.redUsedEntangle, enemy.redLast, enemy.redPrevious,
        random(state, enemy.ai.rollRange) - 1))
end
return M
