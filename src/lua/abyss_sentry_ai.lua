-- Sentry / A0. Full monster-list slot controls opening; no random decision.
-- rollMove still consumes a primary draw. Evidence: TASK-15-sentries-ai.md.
local M={}

local function select(enemy,id)
    for i,intent in ipairs(enemy.intents) do
        if intent.id==id then enemy.intentIndex=i;return end
    end
    error("unknown Sentry intent: "..tostring(id))
end

function M.initialize(state,enemy,random,applyPower)
    local position
    for i,value in ipairs(state.enemies) do if value==enemy then position=i end end
    assert(position,"Sentry missing from encounter")
    random(state,enemy.ai.rollRange)
    select(enemy,position%2==1 and enemy.ai.boltIntent or enemy.ai.beamIntent)
    applyPower(state,enemy,"artifact",enemy.ai.artifactStacks,enemy)
end

function M.advance(state,enemy,random)
    random(state,enemy.ai.rollRange)
    local executed=enemy.intents[enemy.intentIndex].id
    select(enemy,executed==enemy.ai.beamIntent and enemy.ai.boltIntent or enemy.ai.beamIntent)
end

return M
