-- Small Acid Slime / A0. Initial Boolean, then no further AI draws.
-- Evidence and adapter limits: TASK-15-acid-slime-s-ai.md.
local M = {}

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown small Acid Slime intent: " .. tostring(id))
end

function M.initialize(state, enemy, random)
    random(state, enemy.ai.rollRange) -- AbstractMonster.rollMove's ignored primary.
    -- The current adapter maps its two-value integer domain to false/true.
    -- It is not the original RandomXS128.nextBoolean stream.
    select(enemy, random(state, 2) == 2 and enemy.ai.tackleIntent or enemy.ai.weakIntent)
end

function M.advance(state, enemy)
    local executed = enemy.intents[enemy.intentIndex].id
    select(enemy, executed == enemy.ai.tackleIntent and enemy.ai.weakIntent or enemy.ai.tackleIntent)
end

return M
