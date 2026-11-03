-- Faults occur after REAL reward preparation, including resource consumption,
-- RNG, source card disposal and both command ledgers. No replacement game engine.
local F=assert(loadfile('tests/lua/support/raiden_v4_public_commands.lua'))('fixture')
local Run=require('abyss_run')
local count=0
for _,action in ipairs({'Q','normal'})do
    for _,mode in ipairs({'refuse','throw'})do
        local r,s=(action=='Q' and F.readyQ or F.readyNormal)()
        local card=F.held(s,action=='Q' and 'RD2-004' or 'RD2-001')
        local command='rollback-'..action..'-'..mode
        -- Leave 2 HP after direct damage: the REAL eye follow-up must consume
        -- its charge and kill, so late rollback cannot pass without restoring it.
        s.enemies[1].hp=action=='Q' and 18 or 11
        local check=F.unchanged(r);local finish=Run.finishCombat;local reached=false
        local marker={action=action,mode=mode}
        Run.finishCombat=function(...)
            local ok,why=finish(...);assert(ok,why);reached=true
            F.eq(r.phase,'reward');assert(r.rewards.cards and #r.rewards.cards==3)
            assert(r.originalCommands[command] and s.originalV4.commands[command])
            F.eq(s.originalV4.eye.uses,action=='Q' and 1 or 0)
            if action=='Q'then
                F.eq(s.originalV4.resolve,0);F.eq(s.originalV4.musou.uses,3)
            else
                F.eq(s.originalV4.musou.uses,2);F.eq(s.originalV4.nextEnergy,1)
            end
            if mode=='throw'then error(marker,0)end
            return false,'raiden_verification_late_refusal'
        end
        local called,ok,why=pcall(Run.play,r,card.uid,1,command)
        Run.finishCombat=finish
        assert(reached,'fault did not reach real reward preparation')
        if mode=='throw'then F.eq(called,false);F.eq(ok,marker)
        else F.eq(called,true);F.eq(ok,false);F.eq(why,'raiden_verification_late_refusal')end
        check()
        F.eq(r.originalCommands[command],nil);F.eq(s.originalV4.commands[command],nil)
        assert(Run.play(r,card.uid,1,command));F.eq(r.phase,'reward')
        local committed=F.unchanged(r)
        local accepted,reason=Run.play(r,card.uid,1,command)
        F.eq(accepted,true);F.eq(reason,'already_committed');committed()
        count=count+1
        print('PASS '..action..' late '..mode..' restores complete graph/resources/ledgers; same-ID retry then replay')
    end
end
F.eq(count,4);print('RAIDEN_V4_ROLLBACK_PASS '..count)
