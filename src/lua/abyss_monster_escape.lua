-- sts@319009d5: AbstractMonster.escape/updateEscapeAnimation + EscapeAction.
-- Presentation state only; never mutates the committed actor or combat RNG.
local M={actionDuration=0.5}
function M.actionDone(elapsed)
 return elapsed>M.actionDuration
end
function M.start()
 return {timer=3,x=0,flipHorizontal=false,escaped=false}
end
function M.advance(state,dt,scale)
 -- Active state replaces Java's timer!=0 sentinel: an exact-zero frame must
 -- not strand an escaping actor forever. Terminal remains strictly timer<0.
 if state.escaped then return true end
 state.flipHorizontal=true
 state.timer=state.timer-dt
 state.x=state.x+dt*400*scale
 state.escaped=state.timer<0
 return state.escaped
end
function M.pose(state,x,sx)
 return x+state.x,state.flipHorizontal and -math.abs(sx) or sx
end
return M
