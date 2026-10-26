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
return M
