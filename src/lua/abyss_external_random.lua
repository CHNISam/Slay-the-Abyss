-- Unseeded session entropy for original MathUtils paths. It is independent
-- of the run seed and survives Run.new; visual MathUtils history from the PC
-- executable is not reproduced. See docs/SHOP_PARITY.md for the replay boundary.
local P=require('abyss_randomxs128')
local M={}
local current,revision=nil,0
local function initialize()
    if current then return end
    -- Host time APIs are available in the native client. Keep the combined
    -- integer below binary64's exact limit; never derive it from run.seed.
    local seed=os.time()*1000000+math.floor(os.clock()*1000)%1000000
    current=P.fromSeed(string.format('%.0f',seed))
end
function M.snapshot()
    initialize()
    return {words=P.snapshot(current),revision=revision}
end
function M.begin()
    local snapshot=M.snapshot()
    return {state=P.restore(snapshot.words),revision=snapshot.revision}
end
function M.commit(transaction)
    assert(type(transaction)=='table' and transaction.revision==revision,'Stale external entropy transaction')
    local nextState=P.restore(P.snapshot(transaction.state))
    current,revision=nextState,(revision+1)%2147483647
end
-- Explicit external-entropy replay injection. Core/UI never calls this; an
-- original run seed alone cannot specify a MathUtils identity sequence.
function M.setReplayState(words)
    current=P.restore(words)
    revision=(revision+1)%2147483647
end
return M
