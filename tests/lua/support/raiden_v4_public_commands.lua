-- Controlled legal decks and inert durable enemy; not natural acquisition/playthrough.
-- Frozen rules_v4.json#RD and RD2-001/003/004 are the independent numerical oracle.
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b,label)
    assert(rawequal(a,b),(label or 'value')..': expected '..tostring(b)..' got '..tostring(a))
end
-- Observe the original complete graph, including aliases, RNG, catalog and old frames.
-- Deliberately does not use the production snapshot/restore as its oracle.
local function unchanged(root)
    local saved={}
    local function visit(object)
        if type(object)~='table' or saved[object]then return end
        local fields={};saved[object]=fields
        for key,value in next,object do fields[key]=value;visit(key);visit(value)end
    end
    visit(root)
    return function()
        for object,fields in next,saved do
            for key,value in next,fields do eq(rawget(object,key),value,'original graph edge '..tostring(key))end
            for key,value in next,object do eq(value,rawget(fields,key),'new graph edge '..tostring(key))end
        end
    end
end
local function fixture(ids)
    local r=Run.new(Data,'85',{character='raiden',experimental=true,campaign=true,campaignProfile='full-source'})
    -- A controlled five-card permanent deck: real shuffle/draw, no minted hand,
    -- inflated energy or writes to V4 resources. Construction is not reward evidence.
    r.deck={}
    for i,id in ipairs(ids or {'RD2-003','RD2-003','RD2-004','RD2-001','RD2-001'})do
        r.deck[i]={uid=i,cardId=id,upgraded=false}
    end
    r.nextDeckUid=#r.deck+1
    assert(Run.startCombat(r,'cultist_solo'))
    local s=r.combat;local enemy=s.enemies[1]
    enemy.hp=500;enemy.maxHp=500;enemy.ai=nil;enemy.intentIndex=1
    enemy.intents={{id='verification_idle',effects={{op='block',value=0}}}}
    eq(s.energy,3);eq(#s.hand,5);eq(s.originalV4.resolve,0)
    return r,s
end
local function held(s,id)
    for _,card in ipairs(s.hand)do if card.cardId==id then return card end end
    error('missing real drawn card '..id)
end
local function play(r,id,command,target)
    local card=held(r.combat,id)
    assert(C.canPlay(r.combat,card.uid,target or 1))
    local ok,why=Run.play(r,card.uid,target or 1,command)
    assert(ok,tostring(why));return card
end
local function readyQ()
    local r,s=fixture()
    play(r,'RD2-003','eye-1');play(r,'RD2-003','eye-2')
    eq(s.originalV4.resolve,2);eq(s.originalV4.resolveGained,2)
    assert(Run.endTurn(r));eq(s.turn,2);eq(s.originalV4.resolveGained,0)
    play(r,'RD2-003','eye-3');eq(s.originalV4.resolve,3)
    return r,s
end
local function readyNormal()
    local r,s=readyQ();play(r,'RD2-004','burst')
    assert(Run.endTurn(r));eq(s.turn,3);eq(s.energy,3)
    eq(s.originalV4.eye.uses,1);eq(s.originalV4.musou.uses,3)
    return r,s
end
if ...=='fixture'then
    return {eq=eq,unchanged=unchanged,fixture=fixture,held=held,play=play,readyQ=readyQ,readyNormal=readyNormal}
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
test('paid commands cap resolve at two; eye establishment, refresh and replay are physical-play bounded',function()
    local r,s=fixture({'RD2-003','RD2-003','RD2-003','RD2-004','RD2-001'})
    local first=play(r,'RD2-003','cap-1')
    eq(s.enemies[1].hp,497);eq(s.originalV4.eye.uses,3);eq(s.player.block,2)
    play(r,'RD2-003','cap-2');eq(s.enemies[1].hp,492);eq(s.originalV4.eye.uses,2)
    play(r,'RD2-003','cap-3');eq(s.enemies[1].hp,487)
    eq(s.originalV4.resolve,2);eq(s.originalV4.resolveGained,2)
    eq(s.energy,0);eq(s.player.block,2);eq(s.originalV4.eye.uses,2)
    local check=unchanged(r)
    local ok,why=Run.play(r,first.uid,1,'cap-1');eq(ok,true);eq(why,'already_committed');check()
    ok,why=Run.play(r,first.uid,2,'cap-1');eq(ok,false);eq(why,'command_conflict');check()
    print('TRACE cap R=2 gain=2 eye=2 hp=487 energy=0 block=2 replay=unchanged')
    for turn=2,3 do
        assert(Run.endTurn(r))
        for n=1,3 do play(r,'RD2-003','cap-'..turn..'-'..n)end
        eq(s.originalV4.resolve,turn*2);eq(s.originalV4.resolveGained,2)
    end
    assert(Run.endTurn(r));play(r,'RD2-003','cap-full')
    eq(s.originalV4.resolve,6);eq(s.originalV4.resolveGained,0)
    print('TRACE paid-only accumulation turn2 R=4 turn3 R=6 turn4 R=6 gain=0')
end)
test('Q refusal and repeated preview preserve complete Run, then legal Q spends three and grants Musou',function()
    local r,s=fixture();local q=held(s,'RD2-004');local check=unchanged(r)
    local ok,why=Run.play(r,q.uid,1,'early-q');eq(ok,false);eq(why,'requires_resolve3');check()
    eq(r.originalCommands['early-q'],nil)
    r,s=readyQ();q=held(s,'RD2-004');check=unchanged(r)
    for _=1,3 do
        local preview=C.cardPreview(s,q,1)
        eq(preview.originalV4,true);eq(preview.reason,nil);eq(#preview,2)
        eq(preview[1].op,'damage');eq(preview[1].actual,16)
        eq(preview[2].op,'derived');eq(preview[2].actual,2);check()
    end
    ok,why=Run.play(r,q.uid,99,'bad-q');eq(ok,false);eq(why,'invalid_target');check()
    local hp=s.enemies[1].hp
    play(r,'RD2-004','legal-q');eq(hp-s.enemies[1].hp,18)
    eq(s.originalV4.resolve,0);eq(s.energy,0)
    eq(s.originalV4.musou.uses,3);eq(s.originalV4.musou.ends,2)
    eq(s.originalV4.eye.uses,1);eq(s.originalV4.nextEnergy,0)
    local normal=held(s,'RD2-001');check=unchanged(r)
    ok,why=Run.play(r,normal.uid,1,'no-energy');eq(ok,false);eq(why,'insufficient_energy');check()
    print('TRACE Q R=3 preview=16+2 read-only; commit R=0 eye=1 musou=3/2 energy=0')
end)
test('Musou refunds once per turn, expires after two ends and cannot leak into next battle',function()
    local r,s=readyNormal();local hp=s.enemies[1].hp;local normal=held(s,'RD2-001')
    local check=unchanged(r);local preview=C.cardPreview(s,normal,1)
    eq(#preview,2);eq(preview[1].actual,9);eq(preview[2].actual,2);check()
    play(r,'RD2-001','normal-1');play(r,'RD2-001','normal-2')
    eq(hp-s.enemies[1].hp,20);eq(s.originalV4.musou.uses,1)
    eq(s.originalV4.eye.uses,0);eq(s.originalV4.nextEnergy,1);eq(s.originalV4.musouRefunded,1)
    eq(s.energy,1)
    assert(Run.endTurn(r));eq(s.turn,4);eq(s.energy,4)
    eq(s.originalV4.musou.uses,0);eq(s.originalV4.musou.ends,0)
    eq(s.originalV4.eye.uses,0);eq(s.originalV4.eye.ends,0)
    eq(s.originalV4.nextEnergy,0);eq(s.originalV4.musouRefunded,0)
    hp=s.enemies[1].hp;play(r,'RD2-001','expired-normal');eq(hp-s.enemies[1].hp,6)
    eq(s.originalV4.nextEnergy,0)
    play(r,'RD2-003','fresh-eye');eq(s.originalV4.resolve,1);eq(s.originalV4.eye.uses,3)
    -- Controlled lethal boundary; finish/rewards and next combat creation stay real.
    s.enemies[1].hp=1;play(r,'RD2-001','finish')
    eq(r.phase,'reward');assert(Run.leaveCombatRewards(r));eq(r.phase,'map')
    local oldDeck=C.copy(r.deck);local nextUid=r.nextDeckUid;local commands=r.originalCommands
    assert(Run.startCombat(r,'cultist_solo'));eq(r.combatGeneration,2)
    local fresh=r.combat.originalV4
    for _,key in ipairs({'resolve','resolveGained','nextEnergy','nextDraw','nextBlock','musouRefunded'})do eq(fresh[key],0,key)end
    eq(fresh.eye.uses,0);eq(fresh.eye.ends,0);eq(fresh.musou.uses,0);eq(fresh.musou.ends,0)
    eq(r.originalCommands,commands);eq(r.nextDeckUid,nextUid)
    for i,card in ipairs(r.deck)do eq(card.uid,oldDeck[i].uid);eq(card.cardId,oldDeck[i].cardId)end
    print('TRACE Musou normals=11+9 next=1; turn4 energy=4 expired-hit=6; battle2 all RD resources=0')
end)
test('fully blocked Musou hit consumes one use but grants no refund or eye follow-up',function()
    local r,s=readyNormal();s.enemies[1].block=9
    local hp=s.enemies[1].hp
    play(r,'RD2-001','blocked-normal')
    eq(s.enemies[1].hp,hp);eq(s.enemies[1].block,0)
    eq(s.originalV4.musou.uses,2);eq(s.originalV4.eye.uses,1)
    eq(s.originalV4.nextEnergy,0);eq(s.originalV4.musouRefunded,0)
    play(r,'RD2-001','actual-normal');eq(hp-s.enemies[1].hp,11)
    eq(s.originalV4.eye.uses,0);eq(s.originalV4.nextEnergy,1)
    print('TRACE blocked actual=0 musou-use=1 eye-use=0 refund=0; next actual=11 refund=1')
end)
eq(count,4);print('RAIDEN_V4_PUBLIC_COMMANDS_PASS '..count)
