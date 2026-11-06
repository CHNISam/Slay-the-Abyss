local verifyTurn=dofile('scripts/runtime-baseline/turn.lua')
local battle={turn=2,phase='player'}
local host={run={phase='combat',combat=battle},battleUI={busy=false}}
verifyTurn(host,battle,1)
local function rejected(change,restore)
 change()
 assert(not pcall(verifyTurn,host,battle,1),'incomplete turn accepted')
 restore()
end
rejected(function()battle.turn=1 end,function()battle.turn=2 end)
rejected(function()battle.turn=3 end,function()battle.turn=2 end)
rejected(function()battle.phase='enemy' end,function()battle.phase='player' end)
rejected(function()host.run.combat={turn=2,phase='player'}end,function()host.run.combat=battle end)
rejected(function()host.run.phase='reward'end,function()host.run.phase='combat'end)
rejected(function()host.battleUI.busy=true end,function()host.battleUI.busy=false end)
assert(not pcall(verifyTurn,host,battle,0.5),'fractional initial turn accepted')
verifyTurn(host,battle,1)
print('RUNTIME_TURN_CONTRACT_PASS')
