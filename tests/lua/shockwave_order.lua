-- Source-order oracle for real Shockwave plays, including every event frame.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, data = require('abyss_combat'), require('abyss_data')
local passed, failed, finalChecks = 0, 0, 0
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function triple(a) return string.format('%.0f/%.0f/%.0f',a.statuses.artifact or 0,a.statuses.weak or 0,a.statuses.vulnerable or 0) end
local function frame(actors) local r={} for _,a in ipairs(actors) do r[#r+1]=triple(a) end return table.concat(r,'|') end
local function case(name, arts, upgraded, inactive, preexisting)
    local enemies={} for _=1,#arts do enemies[#enemies+1]='cultist' end
    local s=C.new(data,{seed=42,deck={{cardId='shockwave',upgraded=upgraded}},enemies=enemies})
    local amount=upgraded and 5 or 3
    local expectedActors, expected, actual={}, {}, {}
    for i,a in ipairs(s.enemies) do
        a.statuses.artifact=arts[i]
        a.statuses.weak=preexisting and 2 or 0
        a.statuses.vulnerable=preexisting and 4 or 0
        if inactive and inactive[i]=='dead' then a.hp=0 end
        if inactive and inactive[i]=='escaped' then a.escaped=true end
        expectedActors[i]={statuses={artifact=arts[i],weak=a.statuses.weak,vulnerable=a.statuses.vulnerable}}
    end
    -- Independent source-order model: each target's Weak then Vulnerable.
    for i,a in ipairs(s.enemies) do if a.hp>0 and not a.escaped then
        for _,id in ipairs({'weak','vulnerable'}) do
            local p=expectedActors[i].statuses
            local status,delta,blocked=id,amount,''
            if p.artifact>0 then p.artifact=p.artifact-1; status,delta,blocked='artifact',-1,id
            else p[id]=p[id]+amount end
            expected[#expected+1]=a.id..':'..status..':'..delta..':'..blocked..'@'..frame(expectedActors)
        end
    end end
    local uid,seed,hp,energy=s.hand[1].uid,s.seed,s.player.hp,s.energy
    s.events={}
    assert(C.canPlay(s,uid,nil)); assert(C.play(s,uid,nil))
    for _,e in ipairs(s.events) do if e.kind=='status' then
        local d=e.detail
        actual[#actual+1]=d.target..':'..d.status..':'..string.format('%.0f',d.amount)..':'..(d.blockedStatus or '')..'@'..frame(e.frame.enemies)
    end end
    eq(s.seed,seed,'RNG unchanged');eq(s.player.hp,hp,'player HP unchanged');eq(s.energy,energy-2,'cost unchanged')
    eq(#s.hand,0,'hand removal');eq(#s.exhaust,1,'exhaust destination');eq(s.exhaust[1].uid,uid,'identity');eq(#s.discard,0,'not discard')
    eq(frame(s.enemies),frame(expectedActors),'final states')
    finalChecks=finalChecks+1
    local ok=table.concat(actual,';')==table.concat(expected,';')
    if ok then passed=passed+1 else failed=failed+1 end
    print((ok and 'MATCH ' or 'MISMATCH ')..name)
    if not ok then print('  expected '..table.concat(expected,';'));print('  actual   '..table.concat(actual,';')) end
end
for _,upgraded in ipairs({false,true}) do
    local suffix=upgraded and '+' or ''
    for a=0,2 do for b=0,2 do case('two-live'..suffix..' artifacts='..a..','..b,{a,b},upgraded) end end
    for a=0,2 do case('single-live'..suffix..' artifact='..a,{a},upgraded) end
    case('dead-and-escaped-middle'..suffix,{1,2,2,0},upgraded,{[2]='dead',[3]='escaped'})
    case('single-live-after-dead-escaped'..suffix,{2,2,1},upgraded,{[1]='dead',[2]='escaped'})
    case('existing-debuffs'..suffix,{1,0},upgraded,nil,true)
end
print('SUMMARY strict matches='..passed..' strict mismatches='..failed..' final-state/cost/disposal/RNG checks='..finalChecks)
eq(failed,0,'strict source-order parity');eq(passed,30,'strict matches');eq(finalChecks,30,'final checks')
