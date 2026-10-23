-- Independent literal branch table: catches thresholds, history predicates and branch inversion.
local ok, P = pcall(dofile, 'tools/candidates/jaw_worm_policy.lua')
assert(ok and type(P)=='table' and type(P.select)=='function', 'Jaw Worm selector must exist')
local count = 0
local function eq(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)); count=count+1 end
local function same(a,b)
    for k,v in pairs(a) do eq(b[k],v) end
    for k,v in pairs(b) do eq(a[k],v) end
end
-- Each cell is either a fixed action or {source binary32 chance, true action, false action}.
local cb = {0.5625,2,3}
local tt = {0.35699999332427978515625,1,2}
local bb = {0.41600000858306884765625,1,3}
local cases = {
    {{},1,3,2}, {{1},cb,3,2}, {{2},1,3,bb}, {{3},1,3,2},
    {{1,1},cb,3,2}, {{1,2},1,3,bb}, {{1,3},1,3,2},
    {{2,1},cb,3,2}, {{2,2},1,3,bb}, {{2,3},1,3,2},
    {{3,1},cb,3,2}, {{3,2},1,3,bb}, {{3,3},1,tt,2}
}
local bands = {{0,24,2},{25,54,3},{55,99,4}}
local requests, resolved, direct, first = 0,0,0,0
for _,c in ipairs(cases) do
    for _,band in ipairs(bands) do
        for roll=band[1],band[2] do
            local h = {}; for k,v in pairs(c[1]) do h[k]=v end
            local opening=P.select(true,h,roll)
            eq(opening.kind,'action');eq(opening.action,1);first=first+1;same(h,c[1])
            local want=c[band[3]]
            local result=P.select(false,h,roll)
            if type(want)=='table' then
                eq(result.kind,'choice');eq(result.chance,want[1]);eq(result.action,nil); requests=requests+1
                for _,choice in ipairs({true,false}) do
                    local got=P.select(false,h,roll,choice)
                    eq(got.kind,'action');eq(got.action,want[choice and 2 or 3]); resolved=resolved+1
                    -- Returned values cannot alter later evaluations or another enemy's history.
                    got.action=99;result.chance=-1
                    eq(P.select(false,h,roll).chance,want[1]);same(h,c[1])
                end
            else
                eq(result.kind,'action');eq(result.action,want);eq(result.chance,nil);direct=direct+1
                for _,extra in ipairs({true,false}) do
                    assert(not pcall(P.select,false,h,roll,extra),'unused Boolean must be rejected')
                end
            end
            for _,extra in ipairs({true,false}) do assert(not pcall(P.select,true,h,roll,extra)) end
            same(h,c[1])
        end
    end
end
eq(first,1300);eq(requests,310);eq(resolved,620);eq(direct,990)
-- Invalid arguments must reject even when a forced first move could otherwise hide them.
local function bad(firstMove,h,roll,choice)
    local before={};if type(h)=='table' and getmetatable(h)==nil then for k,v in pairs(h) do before[k]=v end end
    assert(not pcall(P.select,firstMove,h,roll,choice),'must reject malformed input')
    if type(h)=='table' and getmetatable(h)==nil then same(h,before) end
end
for _,v in ipairs({0,1,'false',{},function() end}) do bad(v,{},0) end
bad(nil,{},0)
for _,v in ipairs({-1,100,0.5,1/0,-1/0,0/0,'1',false,{}}) do bad(false,{1},v);bad(true,{},v) end
bad(false,{},nil)
for _,v in ipairs({0,1,'true','false',{},function() end}) do bad(false,{1},0,v);bad(true,{},0,v) end
for _,h in ipairs({{0},{4},{1.5},{'1'},{false},{1,2,3},{[2]=1},{[0]=1},{[1]=1,extra=2},setmetatable({1},{})}) do
    bad(false,h,0);bad(true,h,0)
end
bad(false,nil,0);bad(false,1,0);bad(false,'',0)
local input={1};local a=P.select(false,input,0); local b=P.select(false,{2},55)
a.chance=123;eq(b.chance,0.41600000858306884765625);eq(input[1],1)
-- Legal successive choices, with explicit per-instance history management by the caller.
for roll=0,99 do
    for _,choice in ipairs({true,false}) do
        local h={1}
        for turn=1,20 do
            local r=P.select(false,h,roll)
            if r.kind=='choice' then r=P.select(false,h,roll,choice) end
            local last=h[#h];assert(not(last==1 and r.action==1));assert(not(last==2 and r.action==2))
            assert(not(h[1]==3 and h[2]==3 and r.action==3))
            h={last,r.action}
        end
    end
end
print('Jaw Worm policy: '..count..' assertions; 1300 opening, 1300 subsequent requests, 620 resolved choices, 4000 sequence steps passed')
