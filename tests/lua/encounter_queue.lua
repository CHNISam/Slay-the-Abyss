local Q,R=require('abyss_encounter_queue'),require('abyss_sts_random')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
    path=path or 'state';eq(type(a),type(b),path)
    if type(a)~='table'then eq(a,b,path);return end
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok encounter queue '..count..' - '..name)end
local function controlled(values,fn)
    local draw,index=R.randomFloat,0
    R.randomFloat=function(s)
        local value=draw(s);index=index+1
        assert(index<1000,'controlled trace failed to terminate')
        return values[index] or value
    end
    local ok,reason=pcall(fn,function()return index end)
    R.randomFloat=draw;assert(ok,reason)
end

test('weak pool strict thresholds preserve source declaration order',function()
    for _,v in ipairs({{0,'Cultist'},{0.25-2^-24,'Cultist'},{0.25,'Jaw Worm'},
        {0.5,'2 Louse'},{0.75,'Small Slimes'},{1-2^-24,'Small Slimes'}})do
        controlled({v[1]},function()eq(Q.new('42').normal[1],v[2])end)
    end
end)
test('strong pool sorts stably by weight and retains all ten strict thresholds',function()
    local values={{0,'Gremlin Gang'},{0.0625,'Lots of Slimes'},{0.125,'Red Slaver'},
        {0.1875,'Exordium Thugs'},{0.28125,'Exordium Wildlife'},{0.375,'Blue Slaver'},
        {0.5,'Looter'},{0.625,'Large Slime'},{0.75,'3 Louse'},{0.875,'2 Fungi Beasts'},
        {1-2^-24,'2 Fungi Beasts'}}
    for _,v in ipairs(values)do
        controlled({0,0.5,0.25,v[1]},function()eq(Q.new('42').normal[4],v[2])end)
    end
end)
test('normal rejection consumes draws and excludes the previous two source names',function()
    -- Weak C, repeated C, Jaw, C again (two-back), repeated Jaw, Louse.
    controlled({0,0,0.25,0,0.25,0.5,0,0,0.5,0,0.5,0.125},function()
        local s=Q.new('42')
        same({s.normal[1],s.normal[2],s.normal[3]},{'Cultist','Jaw Worm','2 Louse'})
        -- First strong Gremlins, rejected Gremlins, Looter, both rejected,
        -- then Red Slaver. Rejected values still advanced the shared stream.
        same({s.normal[4],s.normal[5],s.normal[6]},{'Gremlin Gang','Looter','Red Slaver'})
        assert(s.monsterRng.counter>=30)
    end)
end)
test('first strong excludes large and lots after Small Slimes without dropping their weights',function()
    controlled({0,0.25,0.75,0.625,0.0625,0.5},function()
        local s=Q.new('42');eq(s.normal[3],'Small Slimes');eq(s.normal[4],'Looter')
    end)
end)
test('first strong excludes Three Louse after Two Louse',function()
    controlled({0,0.25,0.5,0.75,0.875},function()
        local s=Q.new('42');eq(s.normal[3],'2 Louse');eq(s.normal[4],'2 Fungi Beasts')
    end)
end)
test('elite cumulative weights round each binary32 addition and forbid only the previous name',function()
    -- Finish the exact 16 normal entries without retries, then elite N,N,L,N.
    local values={0,0.25,0.5,0}
    for i=1,12 do values[#values+1]=({0.5,0.125,0})[(i-1)%3+1]end
    for _,v in ipairs({0,0,5592406/16777216,0})do values[#values+1]=v end
    controlled(values,function()
        local s=Q.new('42')
        same({s.elite[1],s.elite[2],s.elite[3]},{'Gremlin Nob','Lagavulin','Gremlin Nob'})
    end)
    local p=Q.rules().normalized.elite
    eq(p[1][2],R.float32(1/3));eq(p[2][2],R.float32(1/3));eq(p[3][2],R.float32(1/3))
end)
test('peek consume clone and snapshot isolate every nested table',function()
    local s=Q.new('2780424839485660359');local before=Q.snapshot(s)
    local name=Q.peek(s,'normal');same(Q.snapshot(s),before)
    local got,nextState=Q.consume(s,'normal');eq(got,name);same(Q.snapshot(s),before)
    eq(#nextState.normal,15);same(R.snapshot(nextState.monsterRng),before.monsterRng)
    local c=Q.clone(s);c.normal[1]='Jaw Worm';c.monsterRng.primitive.a[1]=0
    same(Q.snapshot(s),before)
    local restored=Q.restore(before)
    before.normal[1]='Jaw Worm';before.monsterRng.words[1]='0000000000000000'
    same(Q.snapshot(restored),Q.snapshot(s))
end)
test('normal exhaustion refuses without fabricated refill or RNG mutation',function()
    local s=Q.new('1')
    for _=1,16 do local _,n=Q.consume(s,'normal');s=n end
    local before=Q.snapshot(s)
    local name,reason=Q.peek(s,'normal');eq(name,nil);eq(reason,'normal_queue_exhausted')
    local got,n,why=Q.consume(s,'normal');eq(got,nil);eq(n,nil);eq(why,'normal_queue_exhausted')
    same(Q.snapshot(s),before)
end)
test('elite refill stages ten entries on the shared stream and failures cannot publish partial consumption',function()
    local s=Q.new('42')
    for _=1,10 do local _,n=Q.consume(s,'elite');s=n end
    local before=Q.snapshot(s)
    local draw,attempts=R.randomFloat,0
    R.randomFloat=function(rng)
        attempts=attempts+1;local n=draw(rng)
        if attempts==3 then error('injected refill failure')end
        return n
    end
    local ok=pcall(Q.consume,s,'elite');R.randomFloat=draw
    assert(not ok);same(Q.snapshot(s),before)
    local peek=Q.peek(s,'elite');same(Q.snapshot(s),before)
    local got,n=Q.consume(s,'elite');eq(got,peek);eq(#n.elite,9)
    assert(n.monsterRng.counter>before.monsterRng.counter)
end)
test('mixed normal and elite consumption restores exact suffixes and shared RNG state',function()
    local a=Q.new('-9223372036854775808');local b=Q.restore(Q.snapshot(a))
    for i=1,24 do
        local tier=i%3==0 and 'normal'or'elite'
        local left,n=Q.consume(a,tier);local right,m=Q.consume(b,tier)
        eq(left,right);a=n;b=Q.restore(Q.snapshot(m));same(Q.snapshot(a),Q.snapshot(b))
    end
end)
test('malformed snapshots and invalid seed encodings fail before caller state changes',function()
    local s=Q.new('1');local before=Q.snapshot(s)
    for _,seed in ipairs({1,'01','-0','9223372036854775808','-9223372036854775809','1.0'})do
        assert(not pcall(Q.new,seed))
    end
    local changes={function(x)x.version=2 end,function(x)x.extra=true end,
        function(x)x.normal[1]='not an encounter'end,function(x)x.normal[17]='Cultist'end,
        function(x)x.normal[2]=nil end,function(x)x.elite[1]='Cultist'end,
        function(x)x.normal[8]='Cultist'end,function(x)x.normal[2]=x.normal[1]end,
        function(x)x.elite[2]=x.elite[1]end,
        function(x)x.monsterRng.counter=1.5 end,function(x)x.monsterRng.words={'0000000000000000','0000000000000000'}end,
        function(x)x.rawSeed='01'end,function(x)setmetatable(x,{__index=function()error('must not run')end})end}
    for _,change in ipairs(changes)do local snap=Q.snapshot(s);change(snap);assert(not pcall(Q.restore,snap))end
    local name,nextState,reason=Q.consume(s,'boss');eq(name,nil);eq(nextState,nil);eq(reason,'invalid_encounter_tier')
    same(Q.snapshot(s),before)
end)
test('published pool descriptions cannot alter future draws or hide missing content',function()
    local rules=Q.rules();eq(#rules.weak,4);eq(#rules.strong,10);eq(#rules.elite,3)
    rules.weak[1][1]='invalid';rules.strong[1][2]=100;rules.normalized.elite[1][2]=1
    local a,b=Q.new('42'),Q.new('42');same(Q.snapshot(a),Q.snapshot(b))
    eq(Q.rules().weak[1][1],'Cultist');eq(Q.rules().strong[1][2],2)
end)
print('ENCOUNTER_QUEUE_CORE_PASS '..count)
