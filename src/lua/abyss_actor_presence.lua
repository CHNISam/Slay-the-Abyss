-- Read-only targetability and encounter presence; callers own lifecycle writes.
local M={}
function M.isActive(actor) return actor ~= nil and actor.hp > 0 and not actor.escaped and not actor.halfDead and not actor.isDying end

-- A half-dead monster is not targetable, but it has not ended the combat.
function M.isPresent(actor)
    return actor~=nil and not actor.escaped and not actor.isDying and (actor.hp>0 or actor.halfDead or actor.awakenedRebirthPending) or false
end

return M
