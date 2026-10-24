-- Red/Green Louse A0: actor-local Bite sampling and the shared two-move policy.
-- The runtime still uses a shared RNG, not the original independent streams.
local M = {}
local Actors = require("abyss_actor")

local function intent(enemy, id)
    for i, move in ipairs(enemy.intents) do
        if move.id == id then return move, i end
    end
    error("unknown Louse intent: " .. tostring(id))
end

function M.prepare(state, enemy, random)
    local range = enemy.ai.biteRange
    local move = intent(enemy, enemy.ai.biteIntent)
    -- Called once after this actor's HP draw, before constructing the next one.
    -- Combat copied the definition, so neither the catalog nor another actor
    -- receives this instance's immutable base Bite damage.
    move.effects[1].value = range.min + random(state, range.max - range.min + 1) - 1
end

function M.preBattle(state, enemy, random)
    local range = enemy.ai.curlUpRange
    local amount = range.min + random(state, range.max - range.min + 1) - 1
    Actors.applyPower(state, enemy, "curl_up", amount, enemy)
end

local function choose(state, enemy, random)
    local ai = enemy.ai
    local support = random(state, ai.rollRange) - 1 < ai.supportCutoff
    local wanted = support and ai.supportIntent or ai.biteIntent
    if enemy.louseLast == wanted and enemy.lousePrevious == wanted then
        wanted = support and ai.biteIntent or ai.supportIntent
    end
    local _, index = intent(enemy, wanted)
    enemy.intentIndex = index
end

function M.initialize(state, enemy, random)
    enemy.louseLast, enemy.lousePrevious = nil, nil
    choose(state, enemy, random)
end

function M.advance(state, enemy, random)
    enemy.lousePrevious, enemy.louseLast = enemy.louseLast, enemy.intents[enemy.intentIndex].id
    choose(state, enemy, random)
end

return M
