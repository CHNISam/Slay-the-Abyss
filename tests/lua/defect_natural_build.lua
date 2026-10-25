-- Natural Run-entry harness for the current56-card experimental Defect Profile.
-- floor += 1 after real rewards is the only progress shortcut. No HP, energy,
-- deck, enemy, power or RNG injection; not Map/PC probability/platform proof.
-- Old35-card seeds15/45 failed exact first offers before choosing new seeds.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run')
local Combat=require('abyss_combat')
local Actors=require('abyss_actor')
local data=require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local prepared=require('abyss_character_profiles').prepare(data,'defect')
local normalCount=0
for _,card in ipairs(prepared.cards.cards) do
    if card.type~='status' and card.type~='curse' and card.rarity~='special' then normalCount=normalCount+1 end
end
eq(normalCount,56)
local priority={
    loop=105,electrodynamics=110,defragment=100,cold_snap=85,ball_lightning=80,coolheaded=65,zap=60,
    dualcast=90,sweeping_beam=95,beam_cell=98,fusion=-1,capacitor=8,consume=12,biased_cognition=75,
    darkness=-1,reprogram=-1,boot_sequence=95,glacier=95,charge_battery=30,barrage=70,compile_driver=85,
    go_for_the_eyes=98,turbo=100,overclock=100,core_surge=95,rainbow=45,hyperbeam=-1,reinforced_body=0,
    double_energy=100,ftl=98,storm=110,heat_sinks=105,claw=80,stack=25,steam_barrier=70,
    streamline=85,aggregate=80,auto_shields=30,blizzard=85,chaos=70,chill=95,doom_and_gloom=92,
    lock_on=85,melter=88,rip_and_tear=85,skim=100,sunder=105,tempest=0,meteor_strike=95,
    multi_cast=0,thunder_strike=35,hologram=-1,seek=-1,
}
local cases={
 {seed=5,sources={'Jaw Worm','Cultist','Small Slimes','Gremlin Gang'},
  rewards={'cold_snap','loop','defragment','stack'},hp={62,58,50,33},turns={3,3,3,4},cardRng={5,5,2,9},shuffleRng={2,2,2,2},aiRng={4,3,5,6},
  offers={{'consume','cold_snap','reinforced_body'},{'loop','rainbow','glacier'},{'defragment','chill','charge_battery'},{'meteor_strike','capacitor','stack'}},
  plays={cold_snap=4,loop=2,defragment=1},focusedFrost=1,loopHooks=2,aoeActions=0,multiAoe=0,
  focusEffects={{room=4,turn=3,focus=1,block=3}},
  loopEffects={{room=4,turn=3,kind='lightning',amount=4,actual=3,lost=3},{room=4,turn=4,kind='lightning',amount=4,actual=4,lost=4}},
  focusFrost=true,focusCard='cold_snap',loop=true,resetAfterFour=true},
 {seed=53,sources={'Small Slimes','2 Louse','Jaw Worm','Exordium Wildlife'},
  rewards={'electrodynamics','chill','doom_and_gloom','streamline'},hp={58,58,47,47},turns={3,1,2,2},cardRng={5,0,0,0},shuffleRng={2,1,1,1},aiRng={5,2,2,4},
  offers={{'electrodynamics','streamline','go_for_the_eyes'},{'blizzard','boot_sequence','chill'},{'doom_and_gloom','meteor_strike','multi_cast'},{'seek','streamline','auto_shields'}},
  plays={electrodynamics=3,chill=2},focusedFrost=0,loopHooks=0,aoeActions=9,multiAoe=4,electro=true,multi=true,resetAfterFour=true},
}
local function scenario(spec)
    local run=Run.new(data,tostring(spec.seed),{experimental=true,character='defect'})
    eq(run.character,'defect');eq(run.hp,75);eq(run.maxHp,75);eq(#run.deck,10)
    local counts={}
    for _,card in ipairs(run.deck) do counts[card.cardId]=(counts[card.cardId] or 0)+1 end
    eq(counts.strike_blue,4);eq(counts.defend_blue,4);eq(counts.zap,1);eq(counts.dualcast,1)
    eq(#run.relics,1);eq(run.relics[1],'cracked_core')
    local played,focusedFrost,loopHooks,aoeActions,multiAoe={},{},0,0,0
    local previousHp,previousBattle=75,nil
    for room=1,4 do
        local ok,reason=Run.startRoomCombat(run,'normal');assert(ok,reason)
        local battle=run.combat
        eq(run.encounterSource,spec.sources[room]);eq(battle.player.hp,previousHp)
        eq(battle.orbs.slots,3);eq(battle.orbs.focus,0);eq(battle.player.statuses.focus,nil)
        eq(battle.player.statuses.bias,nil);eq(battle.player.statuses.loop,nil)
        eq(battle.player.statuses.electrodynamics,nil);eq(battle.player.statuses.energized_blue,nil)
        eq(battle.player.statuses.heat_sinks,nil);eq(battle.player.statuses.storm,nil)
        eq(battle.cardRandomRng.counter,0);eq(#battle.cardsPlayedThisTurn,0)
        eq(#battle.orbs.balls,1);eq(battle.orbs.balls[1].kind,'lightning')
        eq(battle.orbChannelCounts.lightning,1);eq(battle.orbChannelCounts.frost,0)
        eq(battle.orbChannelCounts.dark,0);eq(battle.orbChannelCounts.plasma,0)
        if previousBattle then assert(battle~=previousBattle,'battle state must be reconstructed') end
        local actions=0
        while run.phase=='combat' do
            actions=actions+1;assert(actions<=200,'bounded natural battle did not finish')
            local s=run.combat;local target
            for i,enemy in ipairs(s.enemies) do
                if Actors.isActive(enemy) and (not target or enemy.hp<s.enemies[target].hp) then target=i end
            end
            local best,score
            for _,card in ipairs(s.hand) do
                if Combat.canPlay(s,card.uid,target) then
                    local rank=priority[card.cardId] or (card.cardId=='strike_blue' and 50 or 15)
                    if card.cardId=='dualcast' and #s.orbs.balls==0 then rank=-1 end
                    if card.cardId=='auto_shields' and s.player.block>0 then rank=-1 end
                    if card.cardId=='blizzard' and (s.orbChannelCounts.frost or 0)==0 then rank=-1 end
                    if card.cardId=='aggregate' and #s.draw<4 then rank=-1 end
                    if card.cardId=='sunder' and s.enemies[target].hp>24 then rank=40 end
                    if rank>=0 and (not score or rank>score) then best,score=card,rank end
                end
            end
            local before=#s.events
            local beforeRng,legacy,turnBefore=s.cardRandomRng.counter,s.seed,s.turn
            local hadElectro=(s.player.statuses.electrodynamics or 0)>0
            local actionId=best and best.cardId or 'endTurn'
            if best then
                assert(Run.play(run,best.uid,target));played[actionId]=(played[actionId] or 0)+1
                if actionId=='defragment' or actionId=='loop' or actionId=='electrodynamics' then
                    print('NATURAL_DEFECT_ACQUIRED_POWER seed='..spec.seed..' room='..room..' turn='..s.turn..' card='..actionId)
                end
            else assert(Run.endTurn(run)) end
            local hadLightning,damaged=false,{}
            local loopEffects={}
            local damageAmount,damageLost=0,0
            local actionMulti=false
            for i=before+1,#s.events do
                local event=s.events[i];local detail=event.detail
                if event.kind=='damage' and detail.source=='player' and detail.amount>0 then
                    damaged[detail.target]=true
                    if event.frame.turn>turnBefore then damageAmount=damageAmount+detail.amount+(detail.blocked or 0);damageLost=damageLost+detail.amount end
                end
                if event.kind=='orb_effect' then
                    if detail.orb=='frost' then
                        local focus=event.frame.player.statuses.focus or 0
                        local previous=s.events[i-1]
                        if focus>0 and previous and previous.kind=='block' and previous.detail.amount==detail.amount
                            and (detail.amount==2+focus or detail.amount==5+focus) then
                            focusedFrost[#focusedFrost+1]={focus=focus,block=detail.amount}
                            local expected=assert(spec.focusEffects and spec.focusEffects[#focusedFrost],'unexpected focused Frost')
                            eq(room,expected.room);eq(event.frame.turn,expected.turn);eq(focus,expected.focus);eq(detail.amount,expected.block)
                            print('NATURAL_DEFECT_FROST seed='..spec.seed..' room='..room..' focus='..focus..' block='..detail.amount)
                        end
                    elseif detail.orb=='lightning' and (event.frame.player.statuses.electrodynamics or 0)>0 then
                        hadLightning=true
                        local affected=0;for _ in pairs(damaged) do affected=affected+1 end
                        if affected>=2 and (actionId=='dualcast' or actionId=='endTurn' or actionId=='zap' or actionId=='electrodynamics') then actionMulti=true end
                    end
                    if event.frame.turn>turnBefore and (event.frame.player.statuses.loop or 0)>0 then
                        assert(detail.orb=='frost' or detail.orb=='lightning','unexpected ordinary start orb in Loop proof')
                        eq(#event.frame.hand,0);eq(event.frame.orbs.balls[1].kind,detail.orb)
                        local actual=damageAmount
                        if detail.orb=='lightning' then assert(damageLost>0,'Loop Lightning must lose real enemy HP')end
                        if detail.orb=='frost' then
                            local prior=assert(s.events[i-1]);eq(prior.kind,'block');eq(prior.detail.amount,detail.amount);actual=prior.detail.amount
                        end
                        assert(actual>0,'Loop passive must cause actual damage/block')
                        loopEffects[#loopEffects+1]={kind=detail.orb,amount=detail.amount,actual=actual,lost=damageLost,turn=event.frame.turn}
                    end
                    damageAmount,damageLost=0,0
                end
            end
            if #loopEffects>0 then
                loopHooks=loopHooks+1;eq(#loopEffects,s.player.statuses.loop)
                local expected=assert(spec.loopEffects and spec.loopEffects[loopHooks],'unexpected Loop start effect')
                eq(room,expected.room)
                for _,effect in ipairs(loopEffects) do
                    eq(effect.turn,expected.turn);eq(effect.kind,expected.kind);eq(effect.amount,expected.amount)
                    eq(effect.actual,expected.actual);eq(effect.lost,expected.lost)
                    print('NATURAL_DEFECT_LOOP seed='..spec.seed..' room='..room..' turn='..effect.turn
                        ..' kind='..effect.kind..' amount='..effect.amount..' actual='..effect.actual..' hp_lost='..effect.lost)
                end
            end
            if (hadElectro or actionId=='electrodynamics') and hadLightning then
                eq(s.cardRandomRng.counter,beforeRng);eq(s.seed,legacy)
                aoeActions=aoeActions+1
                if actionMulti then multiAoe=multiAoe+1 end
                print('NATURAL_DEFECT_ELECTRO seed='..spec.seed..' room='..room..' action='..actionId
                    ..' card_rng='..beforeRng..'->'..s.cardRandomRng.counter..' multi='..tostring(actionMulti))
            end
        end
        eq(run.phase,'reward');eq(run.lastResult.outcome,'victory')
        eq(run.hp,battle.player.hp);eq(run.hp,spec.hp[room]);eq(battle.turn,spec.turns[room]);assert(run.hp>0)
        eq(battle.cardRandomRng.counter,spec.cardRng[room]);eq(battle.shuffleRng.counter,spec.shuffleRng[room]);eq(battle.aiRng.counter,spec.aiRng[room])
        local choice;local options=Run.rewardOptions(run)
        eq(table.concat(options,','),table.concat(spec.offers[room],','))
        print('NATURAL_DEFECT_OFFER seed='..spec.seed..' room='..room..' cards='..table.concat(options,','))
        for i,id in ipairs(options) do if id==spec.rewards[room] then choice=i;break end end
        assert(choice,'fixed naturally offered card missing: '..spec.rewards[room])
        local deckBefore=#run.deck
        assert(Run.claimCardReward(run,choice));eq(#run.deck,deckBefore+1)
        eq(run.deck[#run.deck].cardId,spec.rewards[room])
        if run.rewards.goldClaimed==false then assert(Run.claimGoldReward(run)) end
        assert(Run.leaveCombatRewards(run));eq(run.phase,'map')
        print('NATURAL_DEFECT_ROOM seed='..spec.seed..' room='..room..' source='..spec.sources[room]
            ..' hp='..run.hp..' turns='..battle.turn..' reward='..spec.rewards[room]
            ..' card_rng='..battle.cardRandomRng.counter..' shuffle_rng='..battle.shuffleRng.counter..' ai_rng='..battle.aiRng.counter)
        previousHp,previousBattle=run.hp,battle
        -- Explicit Run boundary harness, not map navigation or a resource reset.
        run.floor=run.floor+1
    end
    if spec.electro then
        assert((played.electrodynamics or 0)>0,'acquired Electro was not naturally drawn and played')
        assert(aoeActions>0,'no actual Electro Lightning effect observed')
    end
    if spec.focusFrost then
        assert((played.defragment or 0)>0 and (played[spec.focusCard] or 0)>0)
        assert(#focusedFrost>0,'no actual Frost block used naturally acquired Focus')
    end
    if spec.loop then assert((played.loop or 0)>0 and loopHooks>0,'no actual acquired Loop extra passive') end
    if spec.multi then assert(multiAoe>0,'no Lightning effect actually damaged multiple targets') end
    for id,expected in pairs(spec.plays) do eq(played[id] or 0,expected) end
    eq(#focusedFrost,spec.focusedFrost);eq(loopHooks,spec.loopHooks)
    eq(aoeActions,spec.aoeActions);eq(multiAoe,spec.multiAoe)
    eq(#run.deck,14)
    if spec.resetAfterFour then
        if spec.focusFrost then assert((previousBattle.player.statuses.focus or 0)>0,'last completed battle must carry nonzero Focus') end
        if spec.loop then assert((previousBattle.player.statuses.loop or 0)>0,'last battle must contain acquired Loop') end
        if spec.electro then assert((previousBattle.player.statuses.electrodynamics or 0)>0,'last battle must contain acquired Electro') end
        local ok,reason=Run.startRoomCombat(run,'normal');assert(ok,reason)
        eq(run.combat.player.hp,previousHp);eq(run.combat.player.statuses.focus,nil)
        eq(run.combat.player.statuses.loop,nil);eq(run.combat.player.statuses.electrodynamics,nil)
        eq(run.combat.player.statuses.bias,nil);eq(run.combat.orbs.focus,0)
        eq(run.combat.orbs.slots,3);eq(#run.combat.orbs.balls,1);eq(run.combat.orbs.balls[1].kind,'lightning')
        eq(run.combat.orbChannelCounts.lightning,1);eq(run.combat.orbChannelCounts.frost,0)
        eq(run.combat.orbChannelCounts.dark,0);eq(run.combat.orbChannelCounts.plasma,0)
        print('NATURAL_DEFECT_NEXT_OPENING seed='..spec.seed..' hp='..run.hp..' powers_reset=true focus_reset=true fifth_victory=false')
    end
    print('DEFECT_NATURAL_SCENARIO_PASS seed='..spec.seed..' wins=4 hp='..previousHp
        ..' electro_plays='..(played.electrodynamics or 0)..' loop_plays='..(played.loop or 0)
        ..' defrag_plays='..(played.defragment or 0)..' cold_snap_plays='..(played.cold_snap or 0)..' chill_plays='..(played.chill or 0)
        ..' loop_hooks='..loopHooks..' aoe_actions='..aoeActions..' multi_aoe='..multiAoe..' focused_frost='..#focusedFrost)
end
for _,spec in ipairs(cases) do scenario(spec) end
print('DEFECT_NATURAL_BUILD_PASS 2 restricted_pool=true profile_cards=56 run_entry_harness=true')
