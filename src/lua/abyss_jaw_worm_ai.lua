-- Fixed JawWorm decision; Act1 forces Chomp, Act3 hard constructor does not.
-- Source rooms use independent STS aiRng; explicit fixtures retain their callback.
local M = {}
local R=require('abyss_enemy_random')

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Jaw Worm intent: " .. tostring(id))
end

function M.choose(ai, last, previous, roll, unit)
    if roll < ai.chompCutoff then
        if last ~= ai.chompIntent then return ai.chompIntent end
        return unit() < ai.bellowAfterChomp and ai.bellowIntent or ai.thrashIntent
    elseif roll < ai.thrashCutoff then
        if last ~= ai.thrashIntent or previous ~= ai.thrashIntent then return ai.thrashIntent end
        return unit() < ai.chompAfterTwoThrashes and ai.chompIntent or ai.bellowIntent
    end
    if last ~= ai.bellowIntent then return ai.bellowIntent end
    return unit() < ai.chompAfterBellow and ai.chompIntent or ai.thrashIntent
end

function M.initialize(state, enemy, random)
    enemy.jawLast, enemy.jawPrevious = nil, nil
    local roll=random(state, enemy.ai.rollRange)-1 -- primary is consumed even on forced Act1 Chomp
    local next=enemy.ai.chompIntent
    if enemy.ai.hardMode==true then
        next=M.choose(enemy.ai,nil,nil,roll,function()return R.float(state,random)end)
    end
    select(enemy,next)
end

function M.preBattle(state,enemy,actors)
    if enemy.ai.hardMode~=true then return end
    actors.applyPower(state,enemy,'strength',enemy.ai.preBattleStrength,enemy)
    actors.block(state,enemy,enemy.ai.preBattleBlock,true)
end

function M.advance(state, enemy, random)
    local executed = enemy.intents[enemy.intentIndex].id
    enemy.jawPrevious, enemy.jawLast = enemy.jawLast, executed
    local roll = random(state, enemy.ai.rollRange) - 1
    local next = M.choose(enemy.ai, enemy.jawLast, enemy.jawPrevious, roll, function()
        -- Source conditional probabilities use the 24-bit nextFloat primitive.
        return R.float(state,random)
    end)
    select(enemy, next)
end

return M
