-- Scene signalling only. The platform's per-player BGM node owns playback.
local M = {}
local signals = {
    map = "ABYSS_BGM_MAP", battle = "ABYSS_BGM_BATTLE", elite = "ABYSS_BGM_ELITE",
    boss = "ABYSS_BGM_BOSS", victory = "ABYSS_BGM_VICTORY", defeat = "ABYSS_BGM_DEFEAT", stop = "ABYSS_BGM_STOP",
}
function M.scene(mode, run, busy, previous)
    if mode == "menu" then return "stop" end
    -- Rule state may already be terminal while hit/death feedback is still visible.
    if busy then return previous or "battle" end
    if mode == "victory" or mode == "defeat" then return mode end
    if run and run.phase == "combat" then
        local kind = run.nodeFlow and run.nodeFlow.type
        if kind == "elite" or kind == "boss" then return kind end
        return "battle"
    end
    return "map"
end
function M.new(send)
    local self = {}
    function self:update(cue)
        if not signals[cue] or type(send) ~= "function" then return false end
        if cue == self.cue then return not self.error end
        self.cue = cue -- A broken audio path must not create a retry storm on UI refresh.
        local ok, accepted = pcall(send, signals[cue])
        self.error = not ok or accepted == false
        return not self.error
    end
    return self
end
return M
