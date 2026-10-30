-- Behavioral port of UNKNOWN/STUN at aeubanks/sts@319009d5.
-- Resource replacement and double-precision trig are explicit native differences.
-- No handles, combat RNG, battle state, frame scheduler, or arbitrary effect cap.
local M = {}

function M.newSequence() return { unknownPhase = 0 } end
-- Keep ONE sequence for the application's class/module lifetime, across battles.
function M.newActor()
    return { timer = 0, effects = {}, nextId = 0, intentAlpha = 0, intentAlphaTarget = 0 }
end
function M.createIntent(actor)
    actor.timer = 0.5
    actor.intentAlpha, actor.intentAlphaTarget = 0, 1
end
function M.flashIntent(actor) actor.intentAlphaTarget = 0 end
function M.updateAlpha(actor, dt)
    if actor.intentAlpha ~= actor.intentAlphaTarget and actor.intentAlphaTarget == 1 then
        actor.intentAlpha = math.min(actor.intentAlphaTarget, actor.intentAlpha + dt)
    elseif actor.intentAlphaTarget == 0 then
        actor.intentAlpha = math.max(0, actor.intentAlpha - dt / 1.5)
    end
    return actor.intentAlpha
end

local function randomUnit(random)
    assert(type(random) == 'function', 'isolated cosmetic random callback required')
    local n = random()
    assert(type(n) == 'number' and n >= 0 and n < 1, 'cosmetic random must be [0,1)')
    return n
end
local function unknown(sequence, p, random)
    local phase = sequence.unknownPhase
    local s = p.scale
    local e = { textureKey = 'INTENT_UNKNOWN_L', width = 128, height = 128,
        x = p.x, y = p.y, duration = 1.5, scale = 0.01, rotationDeg = 0,
        targetScale = 1.2 * s, color = {1, 1, 1, 1}, renderBehind = false }
    if phase ~= 1 then
        e.x = e.x + (phase == 0 and -24 or 24) * s
        e.y = e.y - (6 + 4 * randomUnit(random)) * s
        e.rotationDeg = phase == 0 and 24 or -24
        e.targetScale, e.renderBehind = 0.8 * s, true
        e.color = randomUnit(random) < 0.5 and {218/255, 165/255, 32/255, 1} or {1, 215/255, 0, 1}
    end
    sequence.unknownPhase = (phase + 1) % 3
    return e
end
local function star(p, random)
    -- Original atlas packed bounds unavailable. Caller must explicitly supply
    -- replacement resource dimensions; never silently pretend they are original.
    assert(p.starWidth and p.starWidth > 0 and p.starHeight and p.starHeight > 0,
        'explicit replacement star bounds required')
    return { textureKey = 'TINY_STAR', width = p.starWidth, height = p.starHeight,
        x = p.x, y = p.y + (p.starHeight - p.starWidth) / 2,
        duration = 2, scale = p.scale, settingsScale = p.scale,
        rotationDeg = randomUnit(random) * 360, color = {1, 0.9, 0.3, 0}, renderBehind = false }
end
local function elasticOut(a)
    if a == 0 then return 0 end
    return 1 - 2 ^ (-10 * a) * math.sin((1 - a) * -7 * math.pi)
end
local function updateEffect(e, dt)
    if e.textureKey == 'INTENT_UNKNOWN_L' then
        if e.duration > 0.5 then
            e.scale = 0.01 + (e.targetScale - 0.01) * elasticOut(1.5 - e.duration)
        end
        e.duration = e.duration - dt
        if e.duration >= 0 and e.duration < 0.5 then e.color[4] = e.duration * 2 end
        e.centerX, e.centerY = e.x, e.y
    else
        e.centerX = e.x - math.cos(math.pi * e.duration) * 30 * e.settingsScale
        e.centerY = e.y - math.cos(math.pi * e.duration * 2) * 5 * e.settingsScale
        e.rotationDeg = e.rotationDeg - dt * 60
        e.duration = e.duration - dt
        if e.duration >= 0 and e.duration < 1 then
            local v = 1 - (1 - e.duration) ^ 2
            e.color = {v, v * 0.9, v * 0.3, 1 - (1 - e.duration) ^ 5}
        elseif e.duration > 1 then
            local v = 1 - (e.duration - 1) ^ 4
            e.color = {v, v * 0.9, v * 0.3, 1 - (e.duration - 1) ^ 5}
        end
    end
end

-- Call AFTER updateAlpha, with that current alpha in p.intentAlpha.
-- Existing particles always update, including NONE/dying/escaping/hidden frames.
-- Caller applies original render gate and behind/base/after order, not alpha again.
function M.update(actor, sequence, p, cosmeticRandom)
    local period = p.intent == 'UNKNOWN' and 0.5 or p.intent == 'STUN' and 0.67 or nil
    if period and p.intentAlpha > 0 and not p.isDying and not p.isEscaping then
        actor.timer = actor.timer - p.dt
        if actor.timer < 0 then
            local e = p.intent == 'UNKNOWN' and unknown(sequence, p, cosmeticRandom) or star(p, cosmeticRandom)
            actor.timer = period
            actor.nextId = actor.nextId + 1
            e.effectId = actor.nextId
            actor.effects[#actor.effects + 1] = e
        end
    end
    local alive = {}
    for _, e in ipairs(actor.effects) do
        updateEffect(e, p.dt)
        if e.duration >= 0 then alive[#alive + 1] = e end
    end
    actor.effects = alive
    return alive
end
return M
