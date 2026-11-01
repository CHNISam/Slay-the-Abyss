-- Acid Slime M/L / A0. Fixed-source decisions: TASK-15.7-acid-slime-m.md.
-- Source rooms use independent aiRng; explicit fixtures retain their legacy callback.
local M = {}
local R=require('abyss_enemy_random')

function M.choose(ai, last, previous, roll, boolean, unit)
    if roll < ai.spitCutoff then
        if last ~= ai.spitIntent or previous ~= ai.spitIntent then return ai.spitIntent end
        return boolean() and ai.tackleIntent or ai.weakIntent
    elseif roll < ai.tackleCutoff then
        if last ~= ai.tackleIntent then return ai.tackleIntent end
        return unit() < ai.spitChance and ai.spitIntent or ai.weakIntent
    end
    if last ~= ai.weakIntent or previous ~= ai.weakIntent then return ai.weakIntent end
    return unit() < ai.spitChance and ai.spitIntent or ai.tackleIntent
end

local function select(enemy, id)
    for index, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = index; return end
    end
    error("unknown Acid Slime intent: " .. tostring(id))
end

local function choose(state, enemy, random)
    local id = M.choose(enemy.ai, enemy.acidLast, enemy.acidPrevious,
        random(state, enemy.ai.rollRange) - 1,
        function() return R.boolean(state,random) end,
        function() return R.float(state,random) end)
    select(enemy, id)
end

function M.initialize(state, enemy, random)
    enemy.acidLast, enemy.acidPrevious = nil, nil
    choose(state, enemy, random)
end

function M.advance(state, enemy, random)
    enemy.acidPrevious, enemy.acidLast = enemy.acidLast, enemy.intents[enemy.intentIndex].id
    choose(state, enemy, random)
    -- An interrupted ordinary action keeps its queued roll, then SetMove restores
    -- split. The recorded last move is split, as in the source damage override.
    if enemy.hp > 0 and enemy.splitTriggered then select(enemy, enemy.ai.splitIntent) end
end

return M
