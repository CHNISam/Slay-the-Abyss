-- Source-derived poison actions; shared Actor remains the only status owner.
local Actors = require("abyss_actor")
local Random = require("abyss_sts_random")
local M = {}
local MAX = 2147483647
local function integer(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= MAX
end
local function living(actor)
    return Actors.isActive(actor) and not actor.isDead and not actor.halfDead and not actor.isDying and not actor.isEscaping
end
local function running(state)
    if not living(state.player) then return false end
    for _, enemy in ipairs(state.enemies) do if living(enemy) then return true end end
    return false
end
local function member(state, target)
    for _, enemy in ipairs(state.enemies) do if enemy == target then return true end end
    return false
end
local function apply(state, target, raw)
    assert(integer(raw), "poison application overflow")
    if not living(target) then return false end
    local before = target.statuses.poison or 0
    assert(integer(before), "invalid current poison")
    -- PoisonPower's constructor clamps the new power object's amount, whereas
    -- ApplyPowerAction stacks its separate, unclamped stackAmount on an owner
    -- already holding Poison. Never globally cap the accumulated status.
    local amount = before > 0 and raw or math.min(9999, raw)
    if not Actors.artifactBlocksPower(target, "poison", amount) then
        assert(before + 0.0 + amount <= MAX, "poison stack overflow")
    end
    return Actors.applyPower(state, target, "poison", amount, state.player)
end

function M.multiply(state, target, factor, _api)
    assert(factor == 2 or factor == 3, "unsupported poison multiplier")
    assert(member(state, target), "poison target is not a combat enemy")
    if not running(state) or not living(target) then return false end
    local current = target.statuses.poison or 0
    assert(integer(current), "invalid current poison")
    -- No Poison means no ApplyPowerAction, so Artifact is not consumed.
    if current == 0 then return false end
    local raw = current * 1.0 * (factor - 1)
    return apply(state, target, raw)
end

local function selectTarget(state)
    local candidates = {}
    for _, enemy in ipairs(state.enemies) do
        if living(enemy) then candidates[#candidates + 1] = enemy end
    end
    if #candidates == 0 then return nil end
    -- Source exception=null branch consumes random(0,0) for a single target.
    return candidates[Random.randomInt(state.cardRandomRng, #candidates - 1) + 1]
end

function M.flask(state, count, _api)
    assert(count == 3 or count == 4, "unsupported flask count")
    if not running(state) then return false end
    assert(state.cardRandomRng, "flask requires independent cardRandomRng")
    Random.snapshot(state.cardRandomRng) -- validation before first draw
    local target = selectTarget(state)
    for bounce = 1, count do
        if not target or not running(state) then break end
        -- The next BouncingFlaskAction and its VFX are pushed first, then the
        -- current ApplyPower is pushed ahead of them. Preserve RNG lookahead.
        local nextTarget
        if bounce < count then nextTarget = selectTarget(state) end
        if living(target) then apply(state, target, 3) end
        target = nextTarget
    end
    return true
end

function M.postDraw(state, _api)
    if not running(state) then return false end
    local amount = state.player.statuses.noxious_fumes or 0
    assert(integer(amount), "invalid noxious fumes")
    if amount == 0 then return false end
    -- One post-draw Power hook snapshots its amount and creates applications in
    -- monster-list order. It does not deal poison damage or decay Poison.
    for _, enemy in ipairs(state.enemies) do
        if living(enemy) then apply(state, enemy, amount) end
    end
    return true
end

return M
