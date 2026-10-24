package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_card_actions')
local data=require('abyss_data')
local count=0
local function eq(a,b,label) assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
local function test(name,run) run(); count=count+1; print('ok '..count..' - '..name) end
local function card(s,id,up)
    local c={uid=s.nextUid,cardId=id,upgraded=up==true};s.nextUid=s.nextUid+1;return c
end
local function setup(id,up)
    local s=C.new(data,{deck={id},hp=50,seed=17,enemies={'cultist'}})
    s.hand={card(s,id,up)}; s.draw={}; s.discard={card(s,'anger')};s.exhaust={card(s,'defend')}
    for _=1,8 do s.draw[#s.draw+1]=card(s,'strike') end
    s.energy=10;s.events={};s.player.block=10
    s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.enemies[1].statuses={};s.enemies[1].block=0
    s.enemies[1].intents={{id='test',kind='attack',effects={{op='damage',value=1}}}}
    s.enemies[1].ai=nil;s.enemies[1].intentIndex=1
    return s,s.hand[1]
end
local function play(s,c)
    assert(C.play(s,c.uid,1))
    while s.pendingChoice do
        local p=s.pendingChoice;assert(C.chooseCard(s,p.token,p.uids[1]))
    end
end
-- Independent rule expectations: base/upgraded pairs are explicit gameplay
-- results, never generated from card.effects or the reference JSON.
local cases={
 {'strike',1,1,6,9}, {'defend',1,1,0,0,5,8}, {'bash',2,2,8,10,0,0,'enemy:vulnerable',2,3},
 {'anger',0,0,6,8}, {'armaments',1,1,0,0,5,5}, {'body_slam',1,0,10,10},
 {'clash',0,0,14,18}, {'cleave',1,1,8,11}, {'clothesline',2,2,12,14,0,0,'enemy:weak',2,3},
 {'flex',0,0,0,0,0,0,'strength',2,4}, {'havoc',1,0,6,6}, {'headbutt',1,1,9,12},
 {'heavy_blade',2,2,14,14}, {'iron_wave',1,1,5,7,5,7}, {'perfected_strike',2,2,24,33},
 {'pommel_strike',1,1,9,10}, {'shrug_it_off',1,1,0,0,8,11}, {'sword_boomerang',1,1,9,12},
 {'thunderclap',1,1,4,7,0,0,'enemy:vulnerable',1,1}, {'true_grit',1,1,0,0,7,9},
 {'twin_strike',1,1,10,14}, {'warcry',0,0,0,0}, {'wild_strike',1,1,12,17},
 {'battle_trance',0,0,0,0}, {'blood_for_blood',4,3,18,22}, {'bloodletting',-2,-3,0,0},
 {'burning_pact',1,1,0,0}, {'carnage',2,2,20,28}, {'combust',1,1,0,0,0,0,'combust',5,7},
 {'dark_embrace',2,1,0,0,0,0,'dark_embrace',1,1}, {'disarm',1,1,0,0,0,0,'enemy:strength',-2,-3},
 {'dropkick',1,1,5,8}, {'dual_wield',1,1,0,0}, {'entrench',2,1,0,0,10,10},
 {'evolve',1,1,0,0,0,0,'evolve',1,2}, {'feel_no_pain',1,1,0,0,0,0,'feel_no_pain',3,4},
 {'fire_breathing',1,1,0,0,0,0,'fire_breathing',6,10}, {'flame_barrier',2,2,0,0,12,16,'flame_barrier',4,6},
 {'ghostly_armor',1,1,0,0,10,13}, {'hemokinesis',1,1,15,20}, {'infernal_blade',1,0,0,0},
 {'inflame',1,1,0,0,0,0,'strength',2,3}, {'intimidate',0,0,0,0,0,0,'enemy:weak',1,2},
 {'metallicize',1,1,0,0,0,0,'metallicize',3,4}, {'power_through',1,1,0,0,15,20},
 {'pummel',1,1,8,10}, {'rage',0,0,0,0,0,0,'rage',3,5}, {'rampage',1,1,8,8},
 {'reckless_charge',0,0,7,10}, {'rupture',1,1,0,0,0,0,'rupture',1,2}, {'searing_blow',2,2,12,16},
 {'second_wind',1,1,0,0}, {'seeing_red',-1,-2,0,0}, {'sentinel',1,1,0,0,5,8},
 {'sever_soul',2,2,16,22}, {'shockwave',2,2,0,0,0,0,'enemy:weak',3,5},
 {'spot_weakness',1,1,0,0,0,0,'strength',3,4}, {'uppercut',2,2,13,13,0,0,'enemy:weak',1,2},
 {'whirlwind',10,10,50,80}, {'barricade',3,2,0,0,0,0,'barricade',1,1},
 {'berserk',0,0,0,0,0,0,'vulnerable',2,1}, {'bludgeon',3,3,32,42},
 {'brutality',0,0,0,0,0,0,'brutality',1,1}, {'corruption',3,2,0,0,0,0,'corruption',1,1},
 {'demon_form',3,3,0,0,0,0,'demon_form',2,3}, {'double_tap',1,1,0,0,0,0,'double_tap',1,2},
 {'exhume',1,0,0,0}, {'feed',1,1,10,12}, {'fiend_fire',2,2,0,0}, {'immolate',2,2,21,28},
 {'impervious',2,2,0,0,30,40}, {'juggernaut',2,2,0,0,0,0,'juggernaut',5,7},
 {'limit_break',1,1,0,0}, {'offering',-2,-2,0,0}, {'reaper',2,2,4,5}
}
eq(#cases,75,'fixture covers exactly 75')
local seen={}
for _,case in ipairs(cases) do
    assert(not seen[case[1]]);seen[case[1]]=true
    for _,up in ipairs({false,true}) do
        test(case[1]..(up and '+' or '')..' independent ordinary execution',function()
            local s,c=setup(case[1],up);play(s,c)
            local n=up and 1 or 0
            eq(s.energy,10-case[2+n],'energy');eq(s.enemies[1].hp,1000-case[4+n],'damage')
            eq(s.player.block,10+(case[6+n] or 0),'block')
            if case[8] then
                local enemy=case[8]:sub(1,6)=='enemy:'
                eq((enemy and s.enemies[1] or s.player).statuses[enemy and case[8]:sub(7) or case[8]],case[9+n],'status')
            end
            eq(s.pendingChoice,nil,'no unresolved choice');eq(s.cardActions,nil,'queue drained')
            if case[1]=='offering' then eq(s.player.hp,44);eq(#s.hand,up and 5 or 3) end
            if case[1]=='bloodletting' then eq(s.player.hp,47) end
            if case[1]=='hemokinesis' then eq(s.player.hp,48) end
            if case[1]=='reaper' then eq(s.player.hp,up and 55 or 54) end
            if case[1]=='burning_pact' then eq(#s.hand,up and 3 or 2) end
            if case[1]=='battle_trance' then eq(#s.hand,up and 4 or 3);assert(s.player.noDraw) end
            if case[1]=='pommel_strike' then eq(#s.hand,up and 2 or 1) end
            if case[1]=='shrug_it_off' then eq(#s.hand,1) end
            if case[1]=='exhume' then eq(#s.hand,1);eq(s.hand[1].cardId,'defend');eq(#s.exhaust,1) end
            if case[1]=='power_through' then eq(#s.hand,2);eq(s.hand[1].cardId,'wound') end
            if case[1]=='infernal_blade' then eq(#s.hand,1);eq(C.cardDefinition(s,s.hand[1]).cost,0) end
        end)
    end
end
test('Corruption + Dark Embrace + Feel No Pain + Sentinel respects one real exhaust',function()
    local s,c=setup('true_grit',true)
    s.hand[#s.hand+1]=card(s,'sentinel',true)
    s.player.statuses.corruption=1;s.player.statuses.dark_embrace=1;s.player.statuses.feel_no_pain=4
    play(s,c)
    eq(s.energy,13,'free skill then Sentinel+ energy');eq(#s.exhaust,3)
    eq(#s.hand,2);eq(s.player.block,27,'9 card Block + two fixed exhaust gains')
end)
test('Burning Pact waits for an explicit UID choice and rejects stale/foreign input',function()
    local s,c=setup('burning_pact')
    local a,b=card(s,'sentinel'),card(s,'defend');s.hand={c,a,b}
    assert(C.play(s,c.uid));assert(s.pendingChoice)
    local token=s.pendingChoice.token;local energy=s.energy
    eq(C.endTurn(s),false);eq(C.play(s,a.uid,1),false)
    eq(C.chooseCard(s,token+1,a.uid),false);eq(C.chooseCard(s,token,999999),false)
    eq(s.energy,energy);assert(C.chooseCard(s,token,a.uid));eq(#s.hand,3);eq(s.energy,11)
    eq(C.chooseCard(s,token,a.uid),false)
end)
test('Fiend Fire snapshots count; Dark Embrace draws only after hits and FNP is fixed',function()
    local s,c=setup('fiend_fire')
    s.hand={c,card(s,'defend'),card(s,'sentinel')};s.player.statuses.dark_embrace=1;s.player.statuses.feel_no_pain=3
    s.player.statuses.dexterity=9;s.player.statuses.frail=1
    play(s,c);eq(s.enemies[1].hp,986);eq(#s.exhaust,4);eq(#s.hand,3);eq(s.player.block,19);eq(s.energy,10)
    local lastHit,firstBlock=0,nil
    for i,e in ipairs(s.events) do if e.kind=='damage' then lastHit=i elseif e.kind=='block' and not firstBlock then firstBlock=i end end
    assert(lastHit<firstBlock,'FNP appended behind original damage actions')
end)
test('Second Wind snapshots non-attacks and applies card modifiers separately per card',function()
    local s,c=setup('second_wind',true)
    s.hand={c,card(s,'defend'),card(s,'dazed'),card(s,'strike')}
    s.player.statuses.dexterity=2;s.player.statuses.frail=1;s.player.statuses.dark_embrace=1
    play(s,c);eq(s.player.block,22);eq(#s.hand,3);eq(s.hand[1].cardId,'strike');eq(#s.exhaust,3)
end)
test('Exhume cannot recover another Exhume and preserves the recovered instance',function()
    local s,c=setup('exhume');local d=card(s,'sentinel',true)
    s.exhaust={card(s,'exhume'),d};play(s,c)
    eq(s.hand[1],d);eq(#s.exhaust,2);eq(s.exhaust[1].cardId,'exhume')
end)
test('lethal Fiend Fire clears draw hooks but retains post-use exhaust Block',function()
    local s,c=setup('fiend_fire');s.enemies[1].hp=1
    s.hand={c,card(s,'defend')};s.player.statuses.dark_embrace=1;s.player.statuses.feel_no_pain=3
    play(s,c);eq(C.outcome(s),'victory');eq(#s.hand,0);eq(s.player.block,16)
end)
print('Warrior75: '..count..' independent execution/interaction groups passed; platform unverified.')
