package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local Actions=require('abyss_card_actions')
local data=require('abyss_data')
local N=0
local function eq(a,b,label) assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();N=N+1;print('ok edge '..N..' - '..name) end
local function newCard(s,id,up)
    local c={uid=s.nextUid,cardId=id,upgraded=up==true};s.nextUid=s.nextUid+1;return c
end
local function battle(ids)
    local s=C.new(data,{deck={},hp=50,enemies={'cultist'},seed=99})
    s.hand={};s.draw={};s.discard={};s.exhaust={};s.events={};s.energy=20
    s.enemies[1].hp=500;s.enemies[1].maxHp=500;s.enemies[1].ai=nil;s.enemies[1].statuses={}
    s.enemies[1].intents={{id='hit',kind='attack',effects={{op='damage',value=1}}}};s.enemies[1].intentIndex=1
    for _,id in ipairs(ids or {}) do s.hand[#s.hand+1]=newCard(s,type(id)=='table' and id[1] or id,type(id)=='table' and id[2]) end
    return s
end
local function play(s,index,target)
    local c=s.hand[index or 1];assert(C.play(s,c.uid,target or 1));return c
end
test('Heavy Blade multiplies signed Strength before Weak and Vulnerable rounding',function()
    for _,up in ipairs({false,true}) do
        local s=battle({{'heavy_blade',up}});s.player.statuses.strength=3;s.player.statuses.weak=1;s.enemies[1].statuses.vulnerable=1
        play(s);eq(s.enemies[1].hp,500-(up and 32 or 25))
    end
    local s=battle({'heavy_blade'});s.player.statuses.strength=-4;play(s);eq(s.enemies[1].hp,498)
end)
test('Perfected Strike uses Strike tags in hand draw discard, includes itself, excludes exhaust',function()
    local s=battle({'perfected_strike','pommel_strike','twin_strike','wild_strike','anger'})
    s.draw={newCard(s,'strike')};s.discard={newCard(s,'perfected_strike')};s.exhaust={newCard(s,'strike')}
    play(s);eq(s.enemies[1].hp,482)
end)
test('Clash rejects every non-Attack without paying or moving any UID',function()
    for _,id in ipairs({'defend','inflame','wound','regret'}) do
        local s=battle({'clash',id});local seed=s.seed
        eq(C.play(s,s.hand[1].uid,1),false);eq(s.energy,20);eq(#s.hand,2);eq(s.seed,seed)
    end
end)
test('Armaments choice upgrades only the requested eligible instance',function()
    local s=battle({'armaments','strike','defend'});local strike,defend=s.hand[2],s.hand[3]
    play(s);eq(s.player.block,5);local p=assert(s.pendingChoice)
    assert(C.chooseCard(s,p.token,defend.uid));eq(defend.upgraded,true);eq(strike.upgraded,false)
end)
test('Armaments+ upgrades all eligible hand cards including repeated Searing Blow',function()
    local s=battle({{'armaments',true},'searing_blow',{'strike',true},'wound'})
    local searing=s.hand[2];searing.upgraded=true;searing.upgrades=2
    play(s);eq(C.cardDefinition(s,searing).effects[1].value,27);eq(searing.upgrades,3)
    eq(s.hand[3].upgraded,false);eq(s.pendingChoice,nil)
end)
test('Headbutt pauses for discard choice and keeps played card out of candidates',function()
    local s=battle({'headbutt'});local a,b=newCard(s,'anger'),newCard(s,'defend');s.discard={a,b}
    local c=play(s);local p=assert(s.pendingChoice);eq(C.chooseCard(s,p.token,c.uid),false)
    assert(C.chooseCard(s,p.token,b.uid));eq(s.draw[#s.draw],b);eq(s.discard[2],c)
end)
test('Warcry chooses after drawing and does not put its own card on top',function()
    local s=battle({{'warcry',true},'defend'});s.draw={newCard(s,'strike'),newCard(s,'anger')}
    local c=play(s);local p=assert(s.pendingChoice);eq(#p.uids,3);eq(C.chooseCard(s,p.token,c.uid),false)
    local uid=s.hand[2].uid;assert(C.chooseCard(s,p.token,uid));eq(s.draw[#s.draw].uid,uid);eq(s.exhaust[1],c)
end)
test('Dual Wield+ preserves upgrade growth and temporary cost in two fresh copies',function()
    local s=battle({{'dual_wield',true},{'rampage',true}});local original=s.hand[2]
    original.damageBonus=8;original.costForTurn=0
    play(s);eq(#s.hand,3)
    for i=2,3 do local c=s.hand[i];assert(c~=original);eq(c.damageBonus,8);eq(c.upgraded,true);eq(C.cardDefinition(s,c).cost,0) end
    assert(s.hand[2].uid~=s.hand[3].uid)
end)

test('Anger stat-equivalent copy preserves instance damage and temporary cost with a fresh UID',function()
    for _,up in ipairs({false,true}) do
        local s=battle({{'anger',up}});local original=s.hand[1]
        original.damageBonus=4;original.costForTurn=1
        play(s);local generated=s.discard[1]
        assert(generated~=original and generated.uid~=original.uid)
        eq(generated.upgraded,up);eq(C.cardDefinition(s,generated).cost,1)
        eq(C.cardDefinition(s,generated).effects[1].value,up and 12 or 10)
        generated.damageBonus=7;eq(original.damageBonus,4)
        assert(C.endTurn(s));eq(C.cardDefinition(s,generated).cost,0)
    end
end)

test('Dual Wield selected-card path replaces the selection with fresh stat-equivalent instances',function()
    for _,up in ipairs({false,true}) do
        local s=battle({{'dual_wield',up},'rampage','defend','anger'})
        local selected,defend,anger=s.hand[2],s.hand[3],s.hand[4]
        selected.damageBonus=5;selected.costForTurn=0
        play(s);local p=assert(s.pendingChoice)
        assert(C.chooseCard(s,p.token,selected.uid))
        eq(#s.hand,up and 5 or 4);eq(s.hand[1],anger);eq(s.hand[2],defend)
        local seen={}
        for i=3,#s.hand do
            local c=s.hand[i];assert(c~=selected and c.uid~=selected.uid and not seen[c.uid]);seen[c.uid]=true
            eq(c.cardId,'rampage');eq(c.damageBonus,5);eq(c.costForTurn,0)
        end
    end
end)
test('Rupture is queued before later effects but cannot increase already calculated Hemokinesis damage',function()
    local s=battle({'hemokinesis'});s.player.statuses.rupture=2
    play(s);eq(s.player.hp,48);eq(s.player.statuses.strength,2);eq(s.enemies[1].hp,485)
    local loss,strength,hit
    for i,e in ipairs(s.events) do if e.kind=='hp_loss' then loss=i elseif e.kind=='status' and e.detail.status=='strength' then strength=i elseif e.kind=='damage' then hit=i end end
    assert(loss<strength and strength<hit)
end)
test('lethal self-payment interrupts Offering energy draw and Rupture',function()
    local s=battle({'offering'});s.player.hp=6;s.player.statuses.rupture=3;s.draw={newCard(s,'strike')}
    local c=play(s);eq(s.phase,'defeat');eq(s.energy,20);eq(#s.hand,0);eq(s.player.statuses.strength,nil)
    eq(#s.exhaust,0);eq(#s.discard,0);eq(s.cardInUse,c)
end)
test('Blood for Blood reduces per HP-loss event, not damage points or blocked damage',function()
    local s=battle({'blood_for_blood'});local c=s.hand[1]
    C.damage(s,s.enemies[1],s.player,5,true);eq(C.cardDefinition(s,c).cost,3)
    s.player.block=20;C.damage(s,s.enemies[1],s.player,5,true);eq(C.cardDefinition(s,c).cost,3)
    s.player.block=0;C.applyEffects(s,{{op='loseHp',value=2}},s.player);eq(C.cardDefinition(s,c).cost,2)
    C.upgrade(s,c);eq(C.cardDefinition(s,c).cost,1)
end)
test('Limit Break doubles negative Strength and preserves Artifact gate',function()
    local s=battle({'limit_break'});s.player.statuses.strength=-4;play(s);eq(s.player.statuses.strength,-8)
    s=battle({{'limit_break',true}});s.player.statuses.strength=-4;s.player.statuses.artifact=1
    play(s);eq(s.player.statuses.strength,-4);eq(s.player.statuses.artifact,0);eq(#s.exhaust,0)
end)
test('X-cost consumes all energy; zero still uses the attack without a hit',function()
    for _,up in ipairs({false,true}) do
        local s=battle({{'whirlwind',up}});s.energy=0;play(s);eq(s.energy,0);eq(s.enemies[1].hp,500);eq(#s.discard,1)
        s=battle({{'whirlwind',up}});s.energy=2;s.player.statuses.strength=2;play(s);eq(s.enemies[1].hp,up and 480 or 486)
    end
end)
test('Double Tap repeats an attack and disposes the physical card only once',function()
    local s=battle({'double_tap','strike'});play(s);play(s)
    eq(s.enemies[1].hp,488);eq(#s.discard,2);eq(s.energy,18)
    local plays=0;for _,e in ipairs(s.events) do if e.kind=='play' then plays=plays+1 end end;eq(plays,3)
end)
test('Double Tap+ applies to the next two attacks; Rage triggers for duplicate uses',function()
    local s=battle({{'double_tap',true},'strike','strike','strike'});s.player.statuses.rage=3
    play(s);play(s);play(s);play(s);eq(s.enemies[1].hp,470);eq(s.player.block,15);eq(#s.discard,4)
end)
test('Feed gains permanent max HP on a killing blow including the final enemy',function()
    for _,up in ipairs({false,true}) do
        local s=battle({{'feed',up}});s.enemies[1].hp=1;play(s)
        eq(s.player.maxHp,up and 84 or 83);eq(s.player.hp,up and 54 or 53);eq(s.phase,'victory')
    end
end)
test('Feed cannot trigger from a nonfatal hit or a Minion',function()
    local s=battle({'feed'});play(s);eq(s.player.maxHp,80)
    s=battle({'feed'});s.enemies[1].hp=1;s.enemies[1].minion=true;play(s);eq(s.player.maxHp,80)
end)
test('Reaper heals actual unblocked HP loss and cannot revive a thorns-killed player',function()
    local s=battle({'reaper'});s.enemies[1].hp=2;s.enemies[1].block=1;play(s);eq(s.player.hp,52)
    s=battle({'reaper'});s.player.hp=1;s.enemies[1].statuses.thorns=2;play(s);eq(s.player.hp,0);eq(s.phase,'defeat')
end)
test('Evolve and Fire Breathing trigger only on draw, fixed damage ignores Strength Weak Vulnerable',function()
    local s=battle({});s.draw={newCard(s,'strike'),newCard(s,'wound')}
    s.player.statuses.evolve=1;s.player.statuses.fire_breathing=6;s.player.statuses.strength=10;s.player.statuses.weak=1;s.enemies[1].statuses.vulnerable=1
    C.draw(s,1);Actions.drain(C,s);eq(#s.hand,2);eq(s.enemies[1].hp,494)
    Actions.toHand(s,newCard(s,'wound'));Actions.drain(C,s);eq(s.enemies[1].hp,494)
end)
test('No Draw and full hand suppress Evolve without moving piles or RNG',function()
    local s=battle({});s.draw={newCard(s,'wound')};s.player.statuses.evolve=2;s.player.noDraw=true
    local seed=s.seed;C.draw(s,3);Actions.drain(C,s);eq(#s.hand,0);eq(#s.draw,1);eq(s.seed,seed)
    s.player.noDraw=false;for _=1,10 do s.hand[#s.hand+1]=newCard(s,'strike') end
    C.draw(s,3);Actions.drain(C,s);eq(#s.draw,1);eq(s.seed,seed)
end)
test('Ethereal exhaust keeps nonethereal hand capacity until Dark Embrace resolves; all draws then discard',function()
    local s=battle({'dazed'});for _=1,9 do s.hand[#s.hand+1]=newCard(s,'strike') end
    s.draw={newCard(s,'strike'),newCard(s,'strike'),newCard(s,'strike')};s.player.statuses.dark_embrace=3
    s.rules.player.drawPerTurn=0;s.rules.player.energyPerTurn=0
    assert(C.endTurn(s));eq(#s.exhaust,1);eq(#s.hand,0);eq(#s.discard,10);eq(#s.draw,2)
end)
test('Metallicize precedes Burn so its fixed Block absorbs end-turn damage',function()
    local s=battle({'burn'});s.player.statuses.metallicize=3;s.player.statuses.dexterity=10;s.player.statuses.frail=1
    assert(C.endTurn(s));eq(s.player.hp,50)
end)
test('Combust stacks damage and HP payments separately; fixed area damage ignores attack modifiers',function()
    local s=battle({'combust',{'combust',true}});play(s);play(s)
    s.player.statuses.strength=9;s.player.statuses.weak=1;s.player.statuses.rupture=2
    assert(C.endTurn(s));eq(s.enemies[1].hp,488);eq(s.player.hp,47);eq(s.player.statuses.strength,11)
end)
test('Demon Form Berserk Brutality use the correct next-turn phases',function()
    local s=battle({'demon_form','berserk','brutality'});play(s);play(s);play(s)
    for _=1,10 do s.draw[#s.draw+1]=newCard(s,'strike') end
    assert(C.endTurn(s));eq(s.player.statuses.strength,2);eq(s.energy,4);eq(#s.hand,6);eq(s.player.hp,48)
end)
test('Flame Barrier retaliates per normal hit and expires at the next player start',function()
    local s=battle({'flame_barrier'});play(s)
    s.enemies[1].intents[1].effects={{op='damage',value=1,times=2}}
    assert(C.endTurn(s));eq(s.enemies[1].hp,492);eq(s.player.statuses.flame_barrier,nil)
end)
test('Juggernaut triggers for positive Block including FNP but not zero Block',function()
    local s=battle({'true_grit','dazed'});s.player.statuses.juggernaut=5;s.player.statuses.feel_no_pain=3
    play(s);eq(s.enemies[1].hp,490);eq(s.player.block,10)
    C.block(s,s.player,0,true);Actions.drain(C,s);eq(s.enemies[1].hp,490)
end)
test('Exhume full hand returns nothing and exhausts itself normally',function()
    local s=battle({'exhume'});for _=1,10 do s.hand[#s.hand+1]=newCard(s,'strike') end
    local d=newCard(s,'defend');s.exhaust={d};play(s);eq(#s.hand,10);eq(#s.exhaust,2);eq(s.exhaust[1],d)
end)
test('Sever Soul exhausts only the original non-Attacks, then hits before exhaust-draw tails',function()
    local s=battle({'sever_soul','dazed','defend','anger'});s.player.statuses.dark_embrace=1
    s.draw={newCard(s,'strike'),newCard(s,'strike')};play(s)
    eq(#s.hand,3);eq(#s.exhaust,2);eq(s.enemies[1].hp,484)
end)
test('generated temporary zero cost survives discard and redraw within the same turn',function()
    local s=battle({'bludgeon'});local c=s.hand[1];c.costForTurn=0
    play(s);eq(s.energy,20);C.draw(s,1);eq(s.hand[1],c);eq(C.cardDefinition(s,c).cost,0)
    s.hand={};s.discard={c};assert(C.endTurn(s));eq(C.cardDefinition(s,c).cost,3)
end)

test('a temporary free attack in exhaust retains its cost across turns and Exhume',function()
    local s=battle({{'true_grit',true},'bludgeon'});local attack=s.hand[2];attack.costForTurn=0
    play(s);eq(s.exhaust[1],attack);eq(C.cardDefinition(s,attack).cost,0)
    assert(C.endTurn(s));eq(C.cardDefinition(s,attack).cost,0)
    s.hand={newCard(s,'exhume')};play(s)
    eq(s.hand[1],attack);eq(C.cardDefinition(s,attack).cost,0)
    local energy=s.energy;play(s);eq(s.energy,energy)
end)
test('repeated Corruption does not emit a second zero-stack power application',function()
    local s=battle({'corruption','corruption'});play(s);local count=0
    for _,e in ipairs(s.events) do if e.kind=='status' and e.detail.status=='corruption' then count=count+1 end end
    eq(count,1);play(s);local after=0
    for _,e in ipairs(s.events) do if e.kind=='status' and e.detail.status=='corruption' then after=after+1 end end
    eq(after,1);eq(#s.exhaust,0)
end)
test('Havoc disposes before its queued card draws, allowing that draw to reshuffle Havoc',function()
    local s=battle({'havoc'});local havoc=s.hand[1];s.draw={newCard(s,'pommel_strike')}
    play(s);eq(#s.hand,1);eq(s.hand[1],havoc);eq(s.exhaust[1].cardId,'pommel_strike');eq(s.enemies[1].hp,491)
end)
test('Double Tap Fiend Fire waits for exhaust draw tails before the repeated hand snapshot',function()
    local s=battle({'fiend_fire','defend','strike'});s.player.statuses.double_tap=1;s.player.statuses.dark_embrace=1
    for _=1,6 do s.draw[#s.draw+1]=newCard(s,'strike') end
    play(s);eq(s.enemies[1].hp,465);eq(#s.hand,3);eq(#s.exhaust,6)
end)
test('Juggernaut still triggers a positive Block request at the 999 Block cap',function()
    local s=battle({'defend'});s.player.block=999;s.player.statuses.juggernaut=5
    play(s);eq(s.player.block,999);eq(s.enemies[1].hp,495)
end)
test('Double Tap keeps its original target when the first hit kills it',function()
    local s=battle({'strike'});local other=C.copy(s.enemies[1]);other.id='other';s.enemies[2]=other
    s.player.statuses.double_tap=1;s.enemies[1].hp=6
    play(s);eq(other.hp,500);eq(#s.discard,1);eq(#s.exhaust,0)
end)
test('exhaust Power hooks preserve application order, not a fixed Dark Embrace first order',function()
    for _,first in ipairs({'dark_embrace','feel_no_pain'}) do
        local s=battle({'true_grit','defend'});s.draw={newCard(s,'strike')}
        local second=first=='dark_embrace' and 'feel_no_pain' or 'dark_embrace'
        C.applyEffects(s,{{op='gainStatus',status=first,value=1},{op='gainStatus',status=second,value=1}},s.player)
        play(s)
        local blocks={};for _,e in ipairs(s.events) do if e.kind=='block' then blocks[#blocks+1]=e end end
        eq(#blocks,2);eq(#blocks[2].frame.hand,first=='dark_embrace' and 1 or 0)
    end
end)
test('draw Power hooks preserve application order across Evolve and Fire Breathing',function()
    for _,first in ipairs({'evolve','fire_breathing'}) do
        local s=battle({});s.draw={newCard(s,'strike'),newCard(s,'wound')}
        local second=first=='evolve' and 'fire_breathing' or 'evolve'
        C.applyEffects(s,{{op='gainStatus',status=first,value=1},{op='gainStatus',status=second,value=1}},s.player)
        C.draw(s,1);Actions.drain(C,s)
        local hit;for _,e in ipairs(s.events) do if e.kind=='damage' then hit=e end end
        assert(hit);eq(#hit.frame.hand,first=='evolve' and 2 or 1)
    end
end)
test('Double Tap Rampage shares growth with the queued copy and the original after disposal',function()
    local s=battle({'rampage'});s.player.statuses.double_tap=1
    local c=play(s);eq(s.enemies[1].hp,479);eq(c.damageBonus,10);eq(#s.discard,1)
    C.draw(s,1);eq(s.hand[1],c);play(s);eq(s.enemies[1].hp,461);eq(c.damageBonus,15)
end)
test('copying a suspended card transaction preserves its actor and instance aliases',function()
    local s=battle({'burning_pact','strike','defend'});s.draw={newCard(s,'anger'),newCard(s,'strike')}
    play(s);assert(s.pendingChoice)
    local clone=C.copy(s);eq(clone.pendingChoice.item.source,clone.player)
    eq(clone.cardActions[#clone.cardActions].instance,clone.cardInUse)
    local uid=clone.pendingChoice.uids[1];assert(C.chooseCard(clone,clone.pendingChoice.token,uid))
    eq(clone.cardInUse,nil);eq(clone.pendingChoice,nil);eq(#clone.exhaust,1);eq(#clone.hand,3)
    assert(s.pendingChoice);eq(#s.hand,2);eq(#s.exhaust,0)
end)
test('Burn and Regret auto-use in hand order and preserve the lethal card in use',function()
    for _,ids in ipairs({{'burn','regret'},{'regret','burn'}}) do
        local s=battle(ids);s.player.hp=3
        assert(C.endTurn(s));eq(s.player.hp,0);eq(#s.discard,1);eq(s.discard[1].cardId,ids[1])
        eq(s.cardInUse.cardId,ids[2]);eq(#s.hand,0);eq(s.phase,'defeat')
    end
end)
test('blocked Flame Barrier still invokes both large slime damage overrides',function()
    for _,id in ipairs({'spike_slime_l','acid_slime_l'})do
        local s=C.new(data,{enemies={id},deck={'defend'},seed=42});local enemy=s.enemies[1]
        enemy.hp=32;enemy.maxHp=64;enemy.block=5
        C.addStatus(s.player,'flame_barrier',1);C.damage(s,enemy,s.player,16)
        eq(enemy.hp,32);eq(enemy.block,4);eq(C.intent(s,1).kind,'split')
    end
end)

test('Thorns and Flame Barrier remain distinct reverse-TOP damage actions',function()
    for _,first in ipairs({'thorns','flame_barrier'})do
        local s=battle({});local second=first=='thorns'and'flame_barrier'or'thorns'
        local amounts={thorns=3,flame_barrier=4}
        C.applyEffects(s,{{op='gainStatus',status=first,value=amounts[first]},
            {op='gainStatus',status=second,value=amounts[second]}},s.player)
        C.addStatus(s.enemies[1],'thorns',9)
        C.damage(s,s.enemies[1],s.player,1)
        local hits={};for _,e in ipairs(s.events)do
            if e.kind=='status_damage'and e.detail.target==s.enemies[1].id then hits[#hits+1]=e.detail.amount end
        end
        eq(#hits,2);eq(hits[1],amounts[second]);eq(hits[2],amounts[first])
        eq(s.player.hp,49,'no recursive reflection');eq(s.enemies[1].hp,493)
    end
end)

test('Guardian Sharp Hide notifies Blood for Blood once per actual HP-loss event',function()
    for _,up in ipairs({false,true})do
        local s=battle({'strike',{'blood_for_blood',up}});local held=s.hand[2]
        C.addStatus(s.enemies[1],'sharp_hide',3);s.player.statuses.rupture=2
        play(s);eq(s.player.hp,47);eq(C.cardDefinition(s,held).cost,up and 2 or 3)
        eq(s.player.damagedThisCombat,1);eq(s.player.statuses.strength,nil)
        s.hand={newCard(s,'strike'),held};s.player.block=3;play(s)
        eq(s.player.hp,47);eq(C.cardDefinition(s,held).cost,up and 2 or 3)
        eq(s.player.damagedThisCombat,1,'fully blocked Sharp Hide is no HP-loss event')
    end
end)

test('fresh Blood for Blood inherits prior HP-loss count, including Infernal Blade generation',function()
    local s=battle({'infernal_blade'})
    C.applyEffects(s,{{op='loseHp',value=2},{op='loseHp',value=1}},s.player)
    local fresh=Actions.fresh(C,s,'blood_for_blood');eq(C.cardDefinition(s,fresh).cost,2)
    local old=C.cardRandom
    C.cardRandom=function(state,n)
        local count=0
        for _,rarity in ipairs({'common','uncommon','rare'})do
            for _,id in ipairs(state.sourcePools.src[rarity])do
                local d=state.catalog.cards[id]
                if d.type=='attack'and not d.healing then count=count+1;if id=='blood_for_blood'then return count end end
            end
        end
        error('source generation pool must include Blood for Blood')
    end
    local ok,why=pcall(play,s);C.cardRandom=old;assert(ok,why)
    local generated=s.hand[1];eq(generated.cardId,'blood_for_blood');eq(C.cardDefinition(s,generated).cost,0)
    s.rules.player.drawPerTurn=0;s.player.block=1;assert(C.endTurn(s))
    eq(C.cardDefinition(s,generated).cost,2,'temporary free cost resets to original discounted cost')
end)
test('Brutality post-draw actions are queued before Fire Breathing draw-hook tails',function()
    local s=battle({});s.player.hp=1;s.enemies[1].hp=1
    s.enemies[1].intents[1].effects={{op='damage',value=0}}
    s.player.statuses.brutality=1;s.player.statuses.fire_breathing=6
    s.draw={newCard(s,'strike'),newCard(s,'wound')};s.rules.player.drawPerTurn=1
    assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.enemies[1].hp,1)
    eq(#s.hand,2,'both normal and Brutality draws precede its lethal payment')
end)

test('queued LoseHP is a retained DAMAGE action after victory, but stops on defeat',function()
    for _,hp in ipairs({5,1})do
        local s=battle({});s.player.hp=hp;s.enemies[1].hp=1
        Actions.enqueue(s,{op='damageAll',value=1,fixed=true},s.player)
        Actions.enqueue(s,{op='loseHp',value=2},s.player)
        Actions.drain(C,s)
        eq(s.player.hp,hp==5 and 3 or 0);eq(C.outcome(s),hp==5 and 'victory'or'defeat')
    end
end)
print('Warrior75 edges: '..N..' groups passed; not platform acceptance.')
