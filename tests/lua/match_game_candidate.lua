-- Candidate only: supplied board, no production cards, RNG or permanent deck.
local ok, Game = pcall(dofile, 'tools/candidates/match_game.lua')
assert(ok and type(Game) == 'table' and type(Game.new) == 'function', 'pairing reducer candidate must exist')
local count = 0
local function test(name, fn) fn(); count = count + 1; print('ok pairing candidate ' .. count .. ' - ' .. name) end
local function eq(a,b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
local function same(a,b)
    eq(type(a),type(b)); if type(a) ~= 'table' then eq(a,b); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, 'extra field '..tostring(k)) end
end
local function board() return {'a','a','b','b','c','c','d','d','e','e','f','f'} end
local function new() return assert(Game.new(board())) end
local function refuse(game, command, reason)
    local before = game:view()
    local accepted, why = command()
    eq(accepted,false); eq(why,reason); same(game:view(),before)
end
local function pair(game,a,b)
    assert(game:select(a)); assert(game:select(b)); return game:resolve()
end

test('initial view conceals all twelve cards with five attempts',function()
    local g=new();local v=g:view();eq(v.phase,'selecting');eq(v.attemptsLeft,5);eq(#v.slots,12)
    for i,s in ipairs(v.slots) do eq(s.slot,i);eq(s.faceUp,false);eq(s.removed,false);eq(s.cardId,nil) end
end)
test('first reveal does not consume an attempt',function()
    local g=new();assert(g:select(1));local v=g:view()
    eq(v.phase,'selecting');eq(v.attemptsLeft,5);eq(v.slots[1].cardId,'a');eq(v.slots[2].cardId,nil)
    refuse(g,function()return g:resolve()end,'pair_incomplete')
end)
test('second reveal locks selection until explicit pair resolution',function()
    local g=new();assert(g:select(1));assert(g:select(3));local v=g:view()
    eq(v.phase,'resolving');eq(v.attemptsLeft,5);eq(v.slots[1].cardId,'a');eq(v.slots[3].cardId,'b')
    refuse(g,function()return g:select(4)end,'pair_pending')
end)
test('a match removes both slots and emits exactly one award',function()
    local g=new();local accepted,result=pair(g,1,2);assert(accepted)
    eq(result.matched,true);eq(result.awardCardId,'a');eq(result.attemptsLeft,4);eq(result.complete,false)
    local v=g:view();eq(v.slots[1].removed,true);eq(v.slots[2].removed,true);eq(v.slots[1].cardId,nil)
    refuse(g,function()return g:resolve()end,'pair_incomplete')
    refuse(g,function()return g:select(1)end,'slot_unavailable')
end)
test('a mismatch conceals both slots and also consumes one attempt',function()
    local g=new();local accepted,result=pair(g,1,3);assert(accepted)
    eq(result.matched,false);eq(result.awardCardId,nil);eq(result.attemptsLeft,4)
    local v=g:view();eq(v.slots[1].faceUp,false);eq(v.slots[3].faceUp,false);eq(v.slots[1].removed,false)
    eq(v.slots[1].cardId,nil);assert(g:select(1))
end)
test('same slot cannot count as a second reveal',function()
    local g=new();assert(g:select(1));refuse(g,function()return g:select(1)end,'slot_unavailable')
    assert(g:select(2));local accepted,result=g:resolve();assert(accepted);eq(result.awardCardId,'a')
end)
test('five matches finish with two unclaimed slots and reject all replay',function()
    local g=new()
    for i=1,5 do local accepted,r=pair(g,2*i-1,2*i);assert(accepted);eq(r.attemptsLeft,5-i);eq(r.complete,i==5) end
    eq(g:view().phase,'complete');eq(g:view().slots[11].removed,false)
    refuse(g,function()return g:select(11)end,'game_complete')
    refuse(g,function()return g:resolve()end,'game_complete')
end)
test('five mismatches finish without an award',function()
    local g=new()
    for i=1,5 do local accepted,r=pair(g,1,3);assert(accepted);eq(r.awardCardId,nil);eq(r.complete,i==5) end
    eq(g:view().attemptsLeft,0);eq(g:view().phase,'complete')
end)
test('mixed fifth-attempt match emits final award before becoming terminal',function()
    local g=new();for _=1,4 do assert(pair(g,1,3)) end
    local accepted,r=pair(g,1,2);assert(accepted);eq(r.awardCardId,'a');eq(r.complete,true)
    refuse(g,function()return g:resolve()end,'game_complete')
end)
test('equal IDs match even when not original adjacent pair slots',function()
    local b=board();b[3],b[4]='a','a';local g=assert(Game.new(b))
    local accepted,r=pair(g,1,4);assert(accepted);eq(r.awardCardId,'a')
    eq(g:view().slots[2].removed,false);eq(g:view().slots[3].removed,false)
end)
test('constructor does not retain board aliases',function()
    local b=board();local g=assert(Game.new(b));b[1]='changed';b[2]=nil
    local accepted,r=pair(g,1,2);assert(accepted);eq(r.awardCardId,'a')
end)
test('every view and result is detached from private state',function()
    local g=new();local v=g:view();v.attemptsLeft=99;v.slots[1].removed=true;v.slots[2]=v.slots[1]
    local accepted,r=pair(g,1,2);assert(accepted);r.attemptsLeft=99;r.awardCardId='changed'
    eq(g:view().attemptsLeft,4);eq(g:view().slots[3].removed,false)
    refuse(g,function()return g:select(1)end,'slot_unavailable')
end)
test('instances cannot affect each other',function()
    local a,b=new(),new();assert(pair(a,1,2));eq(b:view().attemptsLeft,5);assert(b:select(1))
    eq(a:view().slots[3].faceUp,false)
end)
test('malformed slot indices are atomically rejected',function()
    local g=new();local values={0,13,-1,1.5,math.huge,-math.huge,0/0,'1',false,{},function()end}
    for _,v in ipairs(values) do refuse(g,function()return g:select(v)end,'invalid_slot') end
    refuse(g,function()return g:select(nil)end,'invalid_slot')
end)
test('malformed board shapes and values are rejected without mutation',function()
    local cases={false,'board',{},board(),board(),board(),board(),board(),board(),board(),board()}
    cases[4][12]=nil;cases[5][13]='x';cases[6].extra='x';cases[7][1]='';cases[8][1]=false
    cases[9][1]={cardId='a'};cases[10][1]='b';cases[11][0]='x'
    for _,b in ipairs(cases) do local g,reason=Game.new(b);eq(g,nil);eq(reason,'invalid_board') end
    local g,reason=Game.new(nil);eq(g,nil);eq(reason,'invalid_board')
    local b=board();b[1]=b;g,reason=Game.new(b);eq(g,nil);eq(reason,'invalid_board');eq(b[1],b)
end)
test('metatable inputs are rejected without invoking metamethods',function()
    local b=setmetatable(board(),{__pairs=function()error('must not iterate')end,__index=function()error('must not read')end})
    local g,reason=Game.new(b);eq(g,nil);eq(reason,'invalid_board')
end)
test('rejecting an invalid board does not alter caller array',function()
    local b=board();b[1]='b';local copy={};for k,v in pairs(b)do copy[k]=v end
    eq(Game.new(b),nil);same(b,copy)
end)
print('LUA_MATCH_GAME_CANDIDATE_PASS '..count)
