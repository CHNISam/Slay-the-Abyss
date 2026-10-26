local M={}
local C=require('abyss_combat')
local Profiles=require('abyss_original_v4_profiles')
local data=require('abyss_data')
function M.state(role,hp,count)
    local prepared=Profiles.prepare(data,role)
    local enemies={};for _=1,count or 1 do enemies[#enemies+1]='cultist'end
    local s=C.new(prepared,{seed=79,deck={},hp=hp,enemies=enemies})
    for _,e in ipairs(s.enemies)do e.hp=500;e.maxHp=500 end
    return s
end
function M.card(s,id,up)
    local c={uid=s.nextUid,cardId=id,upgraded=up==true};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=c;return c
end
function M.play(s,id,up,target,command)
    local card=M.card(s,id,up);s.energy=20
    local ok,why=C.play(s,card.uid,target,command)
    assert(ok,id..': '..tostring(why));return card
end
function M.eq(a,b,label)assert(a==b,(label or '')..' expected '..tostring(b)..' got '..tostring(a))end
M.combat=C;M.data=data
local Run=require('abyss_run')
local Original=require('abyss_original_v4')
function M.naturalBattle(run)
    local actions=0
    while run.phase=='combat' and run.combat.turn<=30 do
        local state=run.combat
        local best,score=nil,-1
        for _,card in ipairs(state.hand)do
            local definition=C.cardDefinition(state,card)
            for target=0,#state.enemies do
                local aimed=target>0 and target or nil
                if C.canPlay(state,card.uid,aimed)then
                    local rank=0
                    if definition.originalV4 then
                        local raw=definition.originalV4
                        local v=state.originalV4
                        if raw.id:sub(-3)=='003'then
                            local deploy=v.role=='HT' and v.infuse==0
                                or v.role=='AR' and not Original.snapshot(state,state.enemies[1]).has_directive
                                or v.role=='FR' and v.guests.usher+v.guests.chevalmarin+v.guests.crabaletta==0
                                or v.role=='RD' and (v.eye.uses==0 or v.eye.ends==0)
                            if deploy then rank=rank+30 end
                        end
                    end
                    for _,entry in ipairs(C.cardPreview(state,card,aimed))do
                        if entry.op=='damage' or entry.op=='derived'then rank=rank+entry.low
                        else rank=rank+entry.low*.35 end
                    end
                    if rank>score then
                        best={uid=card.uid,target=aimed,cardId=card.cardId}
                        score=rank
                    end
                end
            end
        end
        if best then
            actions=actions+1
            local ok,why=Run.play(run,best.uid,best.target,'natural-'..tostring(run.roomGeneration)..'-'..actions)
            assert(ok,tostring(why))
        else
            local ok,why=Run.endTurn(run)
            assert(ok,tostring(why))
        end
    end
    return actions
end
return M
