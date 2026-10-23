-- Read-only A0 ordinary Jaw Worm decision candidate, not connected to runtime.
-- Actions: 1 Chomp, 2 Bellow, 3 Thrash. No random sampling or mutable state.
local M = {}

local function validHistory(history)
    assert(type(history) == 'table' and getmetatable(history) == nil, 'history must be a plain table')
    local size = 0
    for key, value in pairs(history) do
        assert(type(key) == 'number' and (key == 1 or key == 2), 'history must contain at most two consecutive indices')
        assert(type(value) == 'number' and (value == 1 or value == 2 or value == 3), 'invalid history action')
        size = size + 1
    end
    for i = 1, size do assert(rawget(history, i) ~= nil, 'history must be dense') end
    return size
end

-- history is oldest-to-newest (last zero, one or two SELECTED actions).
-- roll is the already-consumed inclusive 0..99 primary draw, even on first move.
-- nil choice requests a conditional Boolean; only strict booleans can resolve it.
-- Supplying a Boolean on a deterministic branch is rejected (no extra source draw).
-- All results are fresh tables; input/history are never changed or retained.
function M.select(firstMove, history, roll, choice)
    assert(type(firstMove) == 'boolean', 'firstMove must be Boolean')
    local size = validHistory(history)
    assert(type(roll) == 'number' and roll >= 0 and roll <= 99 and roll % 1 == 0,
        'roll must be an integer in 0..99')
    assert(choice == nil or type(choice) == 'boolean', 'choice must be Boolean or nil')
    local last, prior = history[size], history[size - 1]
    local action, chance, yes, no
    if firstMove then
        action = 1
    elseif roll < 25 then
        if last == 1 then
            chance, yes, no = 0.5625, 2, 3 -- 0x3f100000, exact source .5625f
        else action = 1 end
    elseif roll < 55 then
        if last == 3 and prior == 3 then
            chance, yes, no = 0.35699999332427978515625, 1, 2 -- 0x3eb6c8b4, source .357f
        else action = 3 end
    elseif last == 2 then
        chance, yes, no = 0.41600000858306884765625, 1, 3 -- 0x3ed4fdf4, source .416f
    else action = 2 end
    if chance then
        if choice == nil then return { kind = 'choice', chance = chance } end
        action = choice and yes or no
    else
        assert(choice == nil, 'this branch does not consume a conditional Boolean')
    end
    return { kind = 'action', action = action }
end

return M
