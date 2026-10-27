-- Source 319009d5: StaticDischargePower.onAttacked adds TOP ChannelActions;
-- TheGuardian.damage adds BOTTOM DEFENSIVE_MODE after Fierce Bash sets Vent.
-- BlockReturnPower.onAttacked adds TOP Block; JuggernautPower.onGainedBlock
-- adds BOTTOM random damage, after the enemy's original completion and roll.
local C,D,P,A,O,AI,Run=require('abyss_combat'),require('abyss_data'),require('abyss_character_profiles'),
    require('abyss_actor'),require('abyss_orbs'),require('abyss_enemy_ai'),require('abyss_run')
local passed,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1 else failed=failed+1 end
    print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function observeShift(s,fn)
    local original,seen=AI.flush,{}
    AI.flush=function(state,owner)
        if state==s and s.enemies[1].aiShiftPending then
            seen[#seen+1]={owner=owner,phase=state.phase}
            for _,item in ipairs(state.cardActions or {})do
                assert(item.effect.op~='enemyAction' or item.effect.stage~='effectsComplete',
                    'reaction stole the pending enemy completion')
            end
        end
        return original(state,owner)
    end
    local ok,why=pcall(fn)
    AI.flush=original
    assert(ok,why)
    eq(#seen,1,'one mode shift flush')
    eq(seen[1].phase,'enemy','shift settles before player input')
    return seen[1].owner
end
test('Static TOP evocations retain Fierce Bash completion ownership',function()
    local s=C.new(P.prepare(D,'defect'),{deck={'defend_blue'},enemies={'guardian'},seed=42,
        cardRandomSeed='42',orbSlots=3,orbRandomSeed='42'})
    local e=s.enemies[1];eq(s.player.hp,75);eq(e.hp,240);eq(e.statuses.mode_shift,30)
    A.applyPower(s,s.player,'static_discharge',3,s.player)
    while #s.orbs.balls<3 do O.channel(s,'lightning',C)end
    local seed=s.seed
    assert(C.endTurn(s));eq(C.intent(s,1).id,'guardian_2');eq(e.statuses.mode_shift,21);eq(e.block,9)
    local owner=observeShift(s,function()assert(C.endTurn(s))end)
    eq(owner,e,'enemy completion owns TOP reactions');eq(C.intent(s,1).id,'guardian_5')
    eq(e.hp,207);eq(e.block,20);eq(e.aiShiftPending,nil);eq(e.aiSkipAdvance,nil)
    eq(s.player.hp,43);eq(s.seed,seed,'no extra AI roll');eq(s.phase,'player');eq(s.cardActions,nil)
end)
test('Juggernaut BOTTOM damage flushes after completed enemy roll',function()
    local data=Run.new(D,'42',{character='watcher',experimental=true}).data
    local s=C.new(data,{deck={'defend_purple'},enemies={'guardian'},seed=42,
        cardRandomSeed='42',enableStances=true})
    local e=s.enemies[1];C.damage(s,s.player,e,29,true)
    assert(C.endTurn(s));eq(C.intent(s,1).id,'guardian_2')
    A.applyPower(s,s.player,'juggernaut',5,s.player)
    A.applyPower(s,s.player,'block_return',2,e)
    local seed=s.seed
    local owner=observeShift(s,function()assert(C.endTurn(s))end)
    eq(owner,nil,'BOTTOM damage has no outstanding enemy owner')
    eq(C.intent(s,1).id,'guardian_5');eq(e.hp,206);eq(e.block,20)
    eq(e.aiShiftPending,nil);eq(e.aiSkipAdvance,nil);eq(s.phase,'player');eq(s.cardActions,nil)
    eq(s.seed,seed,'no extra AI roll')
end)
print('Guardian reaction completion: '..passed..' passed, '..failed..' failed')
assert(failed==0,'Guardian reaction completion failures')
