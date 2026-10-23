-- Promoted source-interpretation primitive for independent event streams.
-- Behavior reference: libGDX RandomXS128, commit 3b1fda1fc2e1f6b3c74851471870062d871ed16f.
-- Independently written limb arithmetic. Upstream: Copyright 2011 See AUTHORS,
-- Apache-2.0; Inferno and davebaol. See accompanying source/boundary report.
local R = {}
local floor = math.floor
local B = 65536.0
local function word(a,b,c,d) return {a or 0,b or 0,c or 0,d or 0} end
local function copy(a) return word(a[1],a[2],a[3],a[4]) end
local function exact(t,keys)
    assert(type(t)=='table' and getmetatable(t)==nil,'Invalid plain table')
    for k in pairs(t) do assert(keys[k], 'Unexpected field') end
end
local function valid(a)
    exact(a,{[1]=true,[2]=true,[3]=true,[4]=true})
    for i=1,4 do local n=a[i];assert(type(n)=='number' and n>=0 and n<B and n==floor(n),'Invalid limb') end
end
local function state(s)
    exact(s,{a=true,b=true});valid(s.a);valid(s.b)
end
local function add(a,b)
    local r,c=word(),0
    for i=1,4 do local n=a[i]+b[i]+c;r[i]=n%B;c=floor(n/B) end
    return r
end
local function mul(a,b)
    local r,c=word(),0.0
    for i=1,4 do
        local n=c
        for j=1,i do n=n+(a[j]/1.0)*b[i-j+1] end
        r[i]=n%B;c=floor(n/B)
    end
    return r
end
local function xor(a,b)
    local r=word()
    for i=1,4 do
        local x,y,p,n=a[i],b[i],1,0
        for _=1,16 do if x%2 ~= y%2 then n=n+p end;x=floor(x/2);y=floor(y/2);p=p*2 end
        r[i]=n
    end
    return r
end
local function shift(a,k,left)
    local r=word();local q=floor(k/16);local p=2.0^(k%16)
    for i=1,4 do
        if left then
            local j=i-q
            if j>=1 then r[i]=((a[j]*p)%B)+(j>1 and floor(a[j-1]*p/B) or 0) end
        else
            local j=i+q
            if j<=4 then r[i]=floor(a[j]/p)+(j<4 and (a[j+1]%p)*(B/p) or 0) end
        end
    end
    return r
end
local function hex(a) return string.format('%04x%04x%04x%04x',a[4],a[3],a[2],a[1]) end
local function parse(h)
    assert(type(h)=='string' and #h==16 and h:match('^[0-9a-f]+$'),'Invalid uint64 hex')
    local a=word();for i=1,4 do a[i]=tonumber(h:sub(17-i*4,20-i*4),16) end;return a
end
local function mix(a)
    for _,h in ipairs({'ff51afd7ed558ccd','c4ceb9fe1a85ec53'}) do a=mul(xor(a,shift(a,33,false)),parse(h)) end
    return xor(a,shift(a,33,false))
end
function R.fromSeed(seed)
    assert(type(seed)=='string' and #seed<=20,'Seed must be a signed decimal string')
    local negative=seed:sub(1,1)=='-';local digits=negative and seed:sub(2) or seed
    assert(digits=='0' or digits:match('^[1-9][0-9]*$'),'Noncanonical seed')
    assert(not (negative and digits=='0'),'Noncanonical negative zero')
    local limit=negative and '9223372036854775808' or '9223372036854775807'
    assert(#digits<#limit or (#digits==#limit and digits<=limit),'Seed outside signed64')
    local a=word()
    for i=1,#digits do a=add(mul(a,word(10)),word(tonumber(digits:sub(i,i)))) end
    if negative then for i=1,4 do a[i]=65535-a[i] end;a=add(a,word(1)) end
    if digits=='0' then a=word(0,0,0,32768) end
    a=mix(a);return {a=a,b=mix(a)}
end
function R.snapshot(s) state(s);return {hex(s.a),hex(s.b)} end
function R.restore(snap)
    exact(snap,{[1]=true,[2]=true});return {a=parse(snap[1]),b=parse(snap[2])}
end
local function raw(s)
    state(s)
    local old=copy(s.b);local t=xor(s.a,shift(s.a,23,true))
    local nextWord=xor(xor(t,old),xor(shift(t,17,false),shift(old,26,false)))
    local result=add(nextWord,old);s.a=old;s.b=nextWord;return result
end
function R.next64Hex(s) return hex(raw(s)) end
function R.nextUint24(s)
    local n=raw(s);return n[4]*256+floor(n[3]/256)
end
function R.nextFloat(s) return R.nextUint24(s)/16777216.0 end
function R.nextInt(s,bound)
    assert(type(bound)=='number' and bound>=1 and bound<=2147483647 and bound==floor(bound), 'Invalid bound')
    state(s)
    while true do
        local bits=shift(raw(s),1,false)
        local value=0.0
        for i=4,1,-1 do value=(value*B+bits[i])%bound end
        -- Equivalent to Java signed-overflow rejection, computed without overflow.
        local extra=bound-1-value
        local sum=add(bits,word(extra%B,floor(extra/B)))
        if sum[4]<32768 then return value end
    end
end
return R
