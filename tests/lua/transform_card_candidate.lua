-- TASK-13.1.2.2. Supplied ordered pools only; no playable event or deck grant.
package.path = './src/lua/?.lua;' .. package.path
local R = require('abyss_sts_random')
local ok, Transform = pcall(dofile, 'tools/candidates/transform_card.lua')
assert(ok and type(Transform)=='table' and type(Transform.select)=='function', 'transform selection candidate must exist')
local count=0
local function test(name, fn) fn(); count=count+1; print('ok transform candidate '..count..' - '..name) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
    eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k,v in pairs(b) do same(v,a[k]) end
end
-- Hand-derived XS128 fixture: a=0, b=n (<2^26) emits 2n, so the
-- bounded draw is n % bound and the next two words are n,n.
local function state(n,counter)
    return R.restore({words={'0000000000000000',string.format('%016x',n)},counter=counter or 0})
end
local function after(n,counter)
    return {words={string.format('%016x',n),string.format('%016x',n)},counter=counter or 1}
end
local function pools()
    return {common={'old','C1','repeat'},srcUncommon={'U1','old','repeat'},srcRare={'R1','old'},
        srcColorless={'old','L1','L2'},curses={'old','Regret','Necronomicurse','AscendersBane','CurseOfTheBell','Pride','Doubt'},
        srcCommon={'wrong-source-common'},uncommon={'wrong-current-uncommon'},rare={'wrong-current-rare'},colorless={'wrong-current-colorless'}}
end
local function check(category,expected,p)
    p=p or pools()
    for n,id in ipairs(expected) do
        local input=state(n-1,7);local before=R.snapshot(input)
        local card,nextRng=Transform.select(category,'old',p,input)
        assert(card,nextRng);same(card,{cardId=id,upgraded=false})
        same(R.snapshot(nextRng),after(n-1,8));same(R.snapshot(input),before)
    end
end
local function refuse(category,id,p,r,reason)
    local before=type(r)=='table' and getmetatable(r)==nil and r.primitive and R.snapshot(r) or nil
    local card,why=Transform.select(category,id,p,r);eq(card,nil);eq(why,reason)
    if before then same(R.snapshot(r),before) end
end

test('colored flattens exact source groups without rarity weighting',function()
    check('colored',{'C1','repeat','U1','repeat','R1'})
end)
test('colorless uses source colorless, not current colorless or colored groups',function()
    check('colorless',{'L1','L2'})
end)
test('curse excludes original and all four special curse IDs',function()
    check('curse',{'Regret','Doubt'})
end)
test('every duplicate original ID is removed before drawing',function()
    check('colored',{'a','b'},{common={'old','old','a','old'},srcUncommon={'old'},srcRare={'old','b','old'}})
    check('colorless',{'a','b'},{srcColorless={'old','a','old','old','b','old'}})
    check('curse',{'Regret','Doubt'},{curses={'old','old','Regret','old','Doubt'}})
end)
test('non-prohibited duplicates retain separate slots and original ordering',function()
    check('colorless',{'z','a','z'},{srcColorless={'z','a','z'}})
    check('curse',{'Regret','Doubt','Regret'},{curses={'Regret','Doubt','Regret'}})
end)
test('a singleton still consumes exactly one RNG call',function()
    for _,category in ipairs({'colored','colorless','curse'}) do
        local p={common={'only'},srcUncommon={},srcRare={},srcColorless={'only'},curses={'only'}}
        local before=state(73,11);local card,nextRng=Transform.select(category,'old',p,before)
        eq(card.cardId,'only');same(R.snapshot(nextRng),after(73,12));same(R.snapshot(before),{words={'0000000000000000','0000000000000049'},counter=11})
    end
end)
test('empty source tiers do not block remaining colored tiers',function()
    check('colored',{'only'},{common={},srcUncommon={},srcRare={'only'}})
    check('colored',{'only'},{common={},srcUncommon={'only'},srcRare={}})
end)
test('all filtered or empty pools refuse without advancing RNG',function()
    refuse('colored','old',{common={'old'},srcUncommon={},srcRare={}},state(3),'empty_transform_pool')
    refuse('colorless','old',{srcColorless={}},state(3),'empty_transform_pool')
    refuse('curse','old',{curses={'old','Necronomicurse','AscendersBane','CurseOfTheBell','Pride'}},state(3),'empty_transform_pool')
end)
test('special curse exclusions apply only to curse category',function()
    check('colorless',{'Necronomicurse','Pride'},{srcColorless={'Necronomicurse','Pride'}})
    check('colored',{'CurseOfTheBell'},{common={'CurseOfTheBell'},srcUncommon={},srcRare={}})
end)
test('invalid category and prohibited ID are rejected before RNG access',function()
    for _,v in ipairs({'','red','COLORLESS',3,false,{}}) do refuse(v,'old',pools(),state(0),'invalid_category') end
    refuse(nil,'old',pools(),state(0),'invalid_category')
    for _,v in ipairs({'',3,false,{}}) do refuse('colored',v,pools(),state(0),'invalid_card_id') end
    refuse('colored',nil,pools(),state(0),'invalid_card_id')
end)
test('missing required pool groups cannot silently become empty',function()
    refuse('colored','old',{common={'a'},srcRare={'r'}},state(0),'invalid_pools')
    refuse('colorless','old',{colorless={'a'}},state(0),'invalid_pools')
    refuse('curse','old',{},state(0),'invalid_pools')
    refuse('colored','old',nil,state(0),'invalid_pools')
end)
test('malformed dense array shapes and IDs are rejected atomically',function()
    local bad={{[2]='a'},{[1]='a',[3]='b'},{[0]='a'},{[-1]='a'},{[1.5]='a'},{[math.huge]='a'},
        {[1]='a',label='b'},{[1]=false},{[1]=17},{[1]=''},{[1]={}},'a',false}
    for _,v in ipairs(bad) do refuse('colorless','old',{srcColorless=v},state(2),'invalid_pools') end
end)
test('selected pool and outer metatables cannot execute hooks',function()
    local calls=0
    local meta={__index=function() calls=calls+1;error('unexpected lookup') end,__len=function() calls=calls+1;return 99 end,
        __pairs=function() calls=calls+1;error('unexpected iterator') end,__metatable=false}
    refuse('colorless','old',setmetatable({},meta),state(0),'invalid_pools')
    refuse('colorless','old',{srcColorless=setmetatable({'a'},meta)},state(0),'invalid_pools');eq(calls,0)
end)
test('only selected pool groups are required or inspected',function()
    local poison=setmetatable({}, {__index=function()error('unused pool touched')end})
    check('colorless',{'a'},{srcColorless={'a'},common=poison})
    check('curse',{'Regret'},{curses={'Regret'},srcColorless=poison})
end)
test('bad RNG refuses without falling back to global randomness',function()
    for _,r in ipairs({false,'seed',{}, {counter=0}, {primitive={},counter=0}}) do
        local card,why=Transform.select('colorless','old',{srcColorless={'a'}},r);eq(card,nil);eq(why,'invalid_rng')
    end
    local card,why=Transform.select('colorless','old',{srcColorless={'a'}},nil);eq(card,nil);eq(why,'invalid_rng')
end)
test('results, next RNG and source arrays are detached',function()
    local p=pools();local input=state(0);local before=R.snapshot(input)
    local card,nextRng=Transform.select('colored','old',p,input)
    same(p,pools());card.cardId='changed';nextRng.primitive.a[1]=600;nextRng.counter=999
    same(R.snapshot(input),before);local card2,next2=Transform.select('colored','old',p,input)
    same(card2,{cardId='C1',upgraded=false});same(R.snapshot(next2),after(0))
    p.common[2]='changed';eq(card2.cardId,'C1')
end)
test('counter wraps at the signed32 boundary without changing inputs',function()
    local input=state(0,2147483647);local card,nextRng=Transform.select('colorless','old',{srcColorless={'a'}},input)
    eq(card.cardId,'a');same(R.snapshot(nextRng),after(0,-2147483648));eq(input.counter,2147483647)
end)
test('fixed signed64 seed vectors agree with independent integer oracle',function()
    -- Generated independently with Python integer arithmetic, not this selector
    -- or the Lua RNG; each vector indexes the five-slot colored pool above.
    local vectors={
        {'0','U1','d1f9a22af8e83383','56d6714ba8506ef6'},
        {'1','C1','7d6e4ac38b2b1be2','b722f2631cb7b14d'},
        {'-1','repeat','fa605f44aea3667d','9b70dcd6b42485f6'},
        {'23','repeat','37865107100ff2c0','e14d9a6f86b7a70b'},
        {'9223372036854775807','repeat','e72306068b6e596a','b4ce8a4fcd5c1b3a'},
        {'-9223372036854775808','U1','d1f9a22af8e83383','56d6714ba8506ef6'},
    }
    for _,v in ipairs(vectors) do
        local input=R.fromSeed(v[1]);local before=R.snapshot(input)
        local card,nextRng=Transform.select('colored','old',pools(),input)
        eq(card.cardId,v[2]);same(R.snapshot(nextRng),{words={v[3],v[4]},counter=1});same(R.snapshot(input),before)
    end
end)
test('bounded-draw rejection advances two primitive words but one wrapper call',function()
    -- First raw=ffffffffffffffff: its high63 value is rejected for bound 3.
    -- The second draw selects slot 3. Both values derived independently.
    local snap={words={'07e07ff03fffe000','0000000000000000'},counter=9}
    for _,category in ipairs({'colored','colorless','curse'}) do
        local input=R.restore(snap)
        local p={common={'a','b','c'},srcUncommon={},srcRare={},srcColorless={'a','b','c'},curses={'a','b','c'}}
        local card,nextRng=Transform.select(category,'old',p,input)
        eq(card.cardId,'c');same(R.snapshot(nextRng),{words={'ffffffffffffffff','ffffffc000000000'},counter=10})
        same(R.snapshot(input),snap)
    end
end)
test('protected RNG metatables are rejected without evaluating hooks',function()
    local calls=0
    local input=setmetatable({}, {__index=function()calls=calls+1;error('RNG hook')end,__metatable=false})
    local card,why=Transform.select('colorless','old',{srcColorless={'a'}},input)
    eq(card,nil);eq(why,'invalid_rng');eq(calls,0)
end)
print('transform selection candidate groups passed: '..count)
