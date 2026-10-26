-- Enemy-only adapters. Source rooms supply STS streams; explicit legacy fixtures
-- keep their injected integer callback. Float/Boolean never masquerade as ints.
local R=require('abyss_sts_random')
local M={}
-- Shared compatibility stream for explicit replay fixtures and death callbacks.
function M.legacyInteger(state,maximum)
 assert(maximum>=1 and maximum%1==0,'invalid random range')
 state.seed=(state.seed*25173+13849)%65536
 return state.seed%maximum+1
end
function M.integer(state,maximum,legacy)
 if state.aiRng then return R.randomInt(state.aiRng,maximum-1)+1 end
 return legacy(state,maximum)
end
function M.boolean(state,legacy)
 if state.aiRng then return R.randomBoolean(state.aiRng) end
 return legacy(state,2)==2
end
function M.float(state,legacy)
 if state.aiRng then return R.randomFloat(state.aiRng) end
 return (legacy(state,65536)-1)/65536
end
return M
