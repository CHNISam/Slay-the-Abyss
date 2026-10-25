-- Independent PR196 review probes. Run from the frozen head directory.
-- All behavior under test enters real Combat.play / Combat.chooseCard / Run.
-- Pile order, energy, and hostile boundary fields are explicit test fixtures;
-- these are not natural-acquisition or platform evidence. No function mocks.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local R=require('abyss_run')
local RNG=require('abyss_sts_random')
local data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', actual '..tostring(a)) end
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name)
    else failed=failed+1;print('FAIL '..name..' | '..tostring(err)) end
end
local function unchanged(state)
    local saved={}
    local function visit(t)
        if type(t)~='table' or saved[t] then return end
        local entries={};saved[t]=entries
        for k,v in pairs(t) do entries[k]=v;visit(k);visit(v) end
    end
    visit(state)
    return function()
        for t,entries in pairs(saved) do
            for k,v in pairs(entries) do eq(t[k],v,'old table/key '..tostring(k)) end
            for k,v in pairs(t) do eq(v,entries[k],'added table/key '..tostring(k)) end
        end
    end
end
local function fixture(hand,draw,discard,options)
    options=options or {};draw=draw or {};discard=discard or {}
    local deck={};for _,list in ipairs({hand,draw,discard}) do for _,id in ipairs(list) do deck[#deck+1]=id end end
    local s=C.new(data,{deck=deck,seed=17,shuffleSeed='17',hp=options.hp or 80,enemies={'cultist'}})
    local pool={};for _,pile in ipairs({s.hand,s.draw}) do for _,c in ipairs(pile) do pool[#pool+1]=c end end
    local function take(spec)
        local id=type(spec)=='table' and spec.cardId or spec
        local up=type(spec)=='table' and spec.upgraded==true or false
        for i,c in ipairs(pool) do if c.cardId==id and c.upgraded==up then return table.remove(pool,i) end end
        error('fixture card missing '..id)
    end
    s.hand={};s.draw={};s.discard={}
    for p,list in ipairs({hand,draw,discard}) do
        local target=({s.hand,s.draw,s.discard})[p]
        for _,id in ipairs(list) do target[#target+1]=take(id) end
    end
    eq(#pool,0);s.energy=20;s.events={}
    return s
end
local function held(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c end end
    error('missing hand card '..id)
end
local function play(s,id,target)
    local c=held(s,id);assert(C.play(s,c.uid,target));return c
end
local function powers(s,ids)
    for _,id in ipairs(ids) do play(s,id) end
    s.events={}
end
local function trace(s)
    local out={}
    for _,e in ipairs(s.events) do
        if e.kind=='exhaust' then out[#out+1]=e.detail.cardId..'@E'..e.frame.energy
        elseif e.kind=='damage' then out[#out+1]='damage:'..e.detail.amount
        elseif e.kind=='block' then out[#out+1]='block:'..e.detail.amount end
    end
    return table.concat(out,',')
end

test('Pact empty draw waits for disposal; one Sentinel/DE tail redraws that same Pact UID',function()
    local s=fixture({'dark_embrace','burning_pact','sentinel'})
    powers(s,{'dark_embrace'})
    local pact=held(s,'burning_pact');local e=s.energy;local shuffle=s.shuffleRng.counter
    play(s,'burning_pact')
    eq(s.energy,e+1);eq(#s.hand,1);eq(s.hand[1],pact);eq(#s.exhaust,1)
    eq(s.exhaust[1].cardId,'sentinel');eq(#s.discard,0);eq(s.shuffleRng.counter,shuffle+1)
    eq(s.cardActions,nil);eq(s.pendingChoice,nil)
    print('TRACE empty Pact '..trace(s)..'; sameUID='..pact.uid..'; shuffleDelta=1')
end)

test('Corruption keeps that Pact exhausted; empty DE tails do not reshuffle or duplicate hooks',function()
    local s=fixture({'dark_embrace','feel_no_pain','corruption','burning_pact','sentinel'})
    powers(s,{'dark_embrace','feel_no_pain','corruption'})
    local e=s.energy;local shuffle=s.shuffleRng.counter;play(s,'burning_pact')
    eq(s.energy,e+2);eq(#s.hand,0);eq(#s.exhaust,2);eq(s.player.block,6)
    eq(s.shuffleRng.counter,shuffle);eq(s.cardInUse,nil);eq(s.cardActions,nil)
    print('TRACE empty Corruption '..trace(s)..'; shuffleDelta=0')
end)

test('Second Wind reverse snapshot exhausts each original nonattack before block and draw tails',function()
    local s=fixture({'dark_embrace','feel_no_pain','second_wind',{cardId='sentinel',upgraded=true},'sentinel','defend','strike'}, {'anger','bash','carnage'})
    powers(s,{'dark_embrace','feel_no_pain'})
    local e=s.energy;local attack=held(s,'strike');play(s,'second_wind')
    eq(#s.exhaust,3);eq(s.exhaust[1].cardId,'defend');eq(s.exhaust[2].cardId,'sentinel')
    eq(s.exhaust[2].upgraded,false);eq(s.exhaust[3].upgraded,true)
    eq(s.energy,e+4);eq(s.player.block,24);eq(#s.hand,4);eq(s.hand[1],attack)
    local exhausted={};local firstBlock
    for i,event in ipairs(s.events) do
        if event.kind=='exhaust' then exhausted[#exhausted+1]={i=i,energy=event.frame.energy,draw=#event.frame.draw} end
        if event.kind=='block' and not firstBlock then firstBlock=i;eq(#event.frame.hand,1) end
    end
    eq(exhausted[1].energy,e-1);eq(exhausted[2].energy,e-1);eq(exhausted[3].energy,e+1)
    assert(exhausted[3].i<firstBlock);eq(exhausted[3].draw,3)
    print('TRACE Second Wind '..trace(s))
end)

test('Fiend Fire thorns defeat cancels queued DE/FNP and leaves played card in use',function()
    for _,up in ipairs({false,true}) do
        local s=fixture({'dark_embrace','feel_no_pain',{cardId='fiend_fire',upgraded=up},'defend','strike'}, {'anger','bash'}, nil, {hp=2})
        powers(s,{'dark_embrace','feel_no_pain'});C.addStatus(s.enemies[1],'thorns',2)
        local ff=held(s,'fiend_fire');local hp=s.enemies[1].hp;local e=s.energy
        play(s,'fiend_fire',1)
        eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.enemies[1].hp,hp-(up and 10 or 7))
        eq(s.player.block,0);eq(#s.hand,0);eq(#s.draw,2);eq(#s.exhaust,2)
        eq(s.cardInUse,ff);eq(#s.discard,0);eq(s.energy,e-2);eq(s.cardActions,nil)
        print('TRACE Fiend Fire '..(up and '+' or 'base')..' '..trace(s)..'; limboUID='..ff.uid)
    end
end)

test('Run selection commits Sentinel and exhaust hooks exactly once; stale replay is immutable',function()
    local s=fixture({'dark_embrace','feel_no_pain','burning_pact','sentinel','defend'},{'strike','anger','bash'})
    powers(s,{'dark_embrace','feel_no_pain'})
    local run=R.new(data,17);run.combat=s;run.phase='combat'
    local uid=held(s,'sentinel').uid;local pact=held(s,'burning_pact')
    local e=s.energy;assert(R.play(run,pact.uid));local token=assert(s.pendingChoice).token
    assert(R.chooseCard(run,token,uid));eq(s.energy,e+1);eq(s.player.block,3);eq(#s.exhaust,1);eq(#s.hand,4)
    local check=unchanged(run);local ok,reason=R.chooseCard(run,token,uid)
    eq(ok,false);eq(reason,'stale_card_choice');check()
    print('TRACE Run commit '..trace(s)..'; stale replay='..reason)
end)

test('failed resumed exhaust transaction restores aliases/RNG/piles and retries once after boundary repair',function()
    -- Explicit hostile-boundary fixture: malformed RNG counter. No function is
    -- replaced. The real Juggernaut tail fails only after Sentinel, Pact draws,
    -- a reshuffle, disposal and FNP have already executed in the transaction.
    local s=fixture({'feel_no_pain','juggernaut','burning_pact','sentinel','defend'},nil,{'strike','anger','bash'})
    powers(s,{'feel_no_pain','juggernaut'})
    local sentinel=held(s,'sentinel');local energy=s.energy
    play(s,'burning_pact');local token=assert(s.pendingChoice).token
    s.cardRandomRng.counter='hostile fixture'
    local check=unchanged(s);local ok,err=pcall(C.chooseCard,s,token,sentinel.uid)
    eq(ok,false);assert(tostring(err):find('Invalid signed32 counter',1,true));check()
    s.cardRandomRng.counter=0
    local hp=s.enemies[1].hp;assert(C.chooseCard(s,token,sentinel.uid))
    eq(s.energy,energy+1);eq(s.player.block,3);eq(#s.exhaust,1);eq(s.exhaust[1],sentinel)
    eq(s.enemies[1].hp,hp-5);eq(#s.hand,3);eq(s.pendingChoice,nil);eq(s.cardActions,nil)
    print('TRACE rollback exact table identity preserved; repaired retry '..trace(s))
end)

print('SUMMARY new exhaust probes: '..passed..' passed / '..failed..' failed')
if failed>0 then error('exhaust transaction regression') end
