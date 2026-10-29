-- Presentation samples only. Existing feedback poses still own actions and death.
local M = {}
local TAU = math.pi * 2

-- A visual clock never advances the committed action queue or catches up on resume.
function M.advance(clock,dt,config)
    assert(type(dt)=='number' and dt==dt and dt>=0 and dt<math.huge,'invalid idle delta')
    return (clock+math.min(dt,config.maxDelta))%config.period
end

-- Select once before composing the existing pose, hit and death transforms.
-- Death/escape must suppress breathing even when a hit or attack is still alive.
function M.state(actor,posed,effect,dying,escaping)
    if not actor then return 'inactive' end
    if dying or actor.hp<=0 or actor.halfDead or actor.isDead or actor.isDying then return 'death' end
    if escaping or actor.escaped then return 'escape' end
    if effect and (effect.kind=='damage' or effect.kind=='hp_loss' or effect.kind=='status_damage')
        and ((effect.detail.amount or 0)>0 or (effect.detail.blocked or 0)>0)then return 'hit' end
    if posed then return 'action' end
    return 'idle'
end

local function phase(id)
    local hash=0
    for i=1,#id do hash=(hash*31+id:byte(i))%360 end
    return hash/360*TAU
end

-- Portrait-only motion preserves the HP/intent/status and input hitbox positions.
-- Stable actor IDs replace the source's random starting animation track time.
-- Four scalar returns avoid one transform allocation per actor per frame.
function M.idle(actor,id,clock,state,config)
    if state~='idle' then return 0,0,1,1 end
    local wave=math.sin(clock/config.period*TAU+phase(id))
    local definition=actor.definitionId or id
    if definition=='cultist' then
        return config.sway*wave,config.lift*wave/2,1,1+config.scale*wave/2
    elseif definition=='jaw_worm' or definition:find('slime',1,true) then
        return 0,config.lift*wave/2,1-config.scale*wave,1+config.scale*wave
    end
    return 0,config.lift*wave,1+config.scale*wave/2,1+config.scale*wave
end

return M
