-- Pairing-event candidate only; not registered in any production event pool.
-- Fixed source: GremlinMatchGame.java blob f86144bdf0e00acad096e8668f17fa96d6aabac1.
-- Independent state model; no original code, presentation, card sampling or RNG.
local M = {}
local SLOT_COUNT, ATTEMPTS = 12, 5

local function validBoard(board)
    if type(board) ~= 'table' or getmetatable(board) ~= nil then return false end
    local size, counts = 0, {}
    for key, id in pairs(board) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > SLOT_COUNT
            or type(id) ~= 'string' or id == '' then return false end
        size = size + 1
        counts[id] = (counts[id] or 0) + 1
    end
    if size ~= SLOT_COUNT then return false end
    for _, count in pairs(counts) do if count % 2 ~= 0 then return false end end
    return true
end

-- board is a dense twelve-element array of nonempty card-ID strings, already
-- sampled, duplicated and shuffled by a future adapter. Even multiplicities
-- allow different original pairs to have the same ID. IDs are not deck UIDs.
function M.new(board)
    if not validBoard(board) then return nil, 'invalid_board' end
    local ids, removed = {}, {}
    for i = 1, SLOT_COUNT do ids[i] = board[i] end
    local first, second, attempts = nil, nil, ATTEMPTS
    local api = {}

    function api:select(slot)
        if type(slot) ~= 'number' or slot % 1 ~= 0 or slot < 1 or slot > SLOT_COUNT then
            return false, 'invalid_slot'
        end
        if attempts == 0 then return false, 'game_complete' end
        if second then return false, 'pair_pending' end
        if removed[slot] or first == slot then return false, 'slot_unavailable' end
        if first then second = slot else first = slot end
        return true
    end

    -- Adapter calls this once AFTER presenting the revealed pair. No timers are
    -- simulated here. The returned award is an emission, not a deck mutation;
    -- integration must commit acquisition and event state together exactly once.
    function api:resolve()
        if attempts == 0 then return false, 'game_complete' end
        if not second then return false, 'pair_incomplete' end
        local matched = ids[first] == ids[second]
        local award = matched and ids[first] or nil
        if matched then removed[first], removed[second] = true, true end
        first, second, attempts = nil, nil, attempts - 1
        return true, {matched = matched, awardCardId = award,
            attemptsLeft = attempts, complete = attempts == 0}
    end

    -- Fresh display data only. Concealed/removed slots never disclose card IDs.
    function api:view()
        local slots = {}
        for i = 1, SLOT_COUNT do
            local faceUp = first == i or second == i
            slots[i] = {slot = i, faceUp = faceUp, removed = removed[i] == true,
                cardId = faceUp and ids[i] or nil}
        end
        return {phase = attempts == 0 and 'complete' or second and 'resolving' or 'selecting',
            attemptsLeft = attempts, slots = slots}
    end
    return api
end

return M
