local AI = dofile('tools/candidates/cultist_ai.lua')
local n = 0
local function eq(a,b) assert(a == b, tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn(); n=n+1; print('ok '..n..' - '..name) end

test('opener grants Ritual, not damage or immediate Strength', function()
 local before=AI.new(49); local after,action=AI.act(before)
 eq(before.phase,'opening'); eq(before.ritual,0); eq(before.awaitingRound,false)
 eq(after.hp,49); eq(after.ritual,3); eq(after.strength,0)
 eq(action.kind,'buff'); eq(action.status,'ritual'); eq(action.amount,3)
 eq(after.phase,'attacking'); eq(after.awaitingRound,true)
 local round=AI.endRound(after); eq(round.strength,0); eq(round.skipRitualRound,false)
 eq(after.skipRitualRound,true)
end)

test('unmodified single-enemy action trace is 0,6,9,12,15', function()
 local s=AI.new(53)
 for _,expected in ipairs({0,6,9,12,15}) do
  local nextState,action=AI.act(s)
  eq(action.kind=='attack' and action.baseDamage+s.strength or 0,expected)
  s=AI.endRound(nextState)
 end
 eq(s.strength,12); eq(s.ritual,3); eq(s.hp,53)
end)

test('teammate action gap does not trigger Ritual growth',function()
 local s=AI.endRound(AI.act(AI.new(48)))
 local acted,action=AI.act(s)
 eq(action.baseDamage,6); eq(acted.strength,0)
 -- Other enemies act here. No Cultist transition should be invoked.
 eq(acted.strength,0); eq(AI.endRound(acted).strength,3)
end)

test('each live instance has independent opener and first-round skip',function()
 local a,b=AI.new(48),AI.new(54)
 a=AI.endRound(AI.act(a)); a=AI.endRound(AI.act(a))
 eq(a.strength,3); eq(b.strength,0); eq(b.phase,'opening')
 b=AI.endRound(AI.act(b)); eq(b.strength,0); eq(a.hp,48); eq(b.hp,54)
end)

test('dead actors neither act nor gain end-round Strength',function()
 local s=AI.endRound(AI.act(AI.new(50)))
 local acted=AI.act(s); acted.hp=0
 local dead=AI.endRound(acted); eq(dead.strength,0); eq(dead.hp,0)
 local again,action=AI.act(dead); eq(action.kind,'none'); eq(again.strength,0)
 local opener=AI.new(0); local _,openingAction=AI.act(opener); eq(openingAction.kind,'none')
end)

test('duplicate actions and rounds are rejected without mutating input',function()
 local initial=AI.new(51)
 assert(not pcall(AI.endRound,initial)); eq(initial.awaitingRound,false)
 local acted=AI.act(initial)
 assert(not pcall(AI.act,acted)); eq(acted.ritual,3); eq(acted.strength,0)
 local ended=AI.endRound(acted)
 assert(not pcall(AI.endRound,ended)); eq(ended.strength,0)
end)

test('candidate preserves externally supplied HP without RNG or range substitution',function()
 for _,hp in ipairs({0,1,48,49,50,51,52,53,54,100}) do eq(AI.new(hp).hp,hp) end
 assert(not pcall(AI.new,-1)); assert(not pcall(AI.new,1.5)); assert(not pcall(AI.new,'50'))
end)

print('Cultist candidate: '..n..' tests passed; no runtime integration or parity certification')
