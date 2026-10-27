-- Track successful applications for the hooks this engine dispatches.
local Schedule=require('abyss_power_schedule')
local M={ids={beat_of_death=true,time_warp=true,nemesis_intangible=true,curiosity=true,slow=true,thorns=true,flame_barrier=true,block_return=true,sharp_hide=true,choked=true,
    shackled=true,blur=true,metallicize=true,plated_armor=true,like_water=true,combust=true,rage=true,study=true,
    rebound=true,equilibrium=true,amplify=true,echo_form=true,machine_learning=true,self_repair=true,buffer=true,static_discharge=true}}
for id in pairs(require('abyss_turn_powers').scheduledIds) do M.ids[id]=true end
local function absentGuardianHide(actor,id,value)
    return id=='sharp_hide' and value==0 and actor.ai and actor.ai.kind=='guardian'
end
function M.before(state,actor)
    -- One legacy fixture Power has an unambiguous position before this new
    -- application. Multiple unknown memberships remain an explicit error.
    local filter={};for id,value in pairs(M.ids) do filter[id]=value end
    -- Guardian's old data ABI uses zero for an absent Sharp Hide Power.
    if absentGuardianHide(actor,'sharp_hide',actor.statuses.sharp_hide) then filter.sharp_hide=false end
    for _,entry in ipairs(Schedule.list(actor,filter)) do
        if entry.fallback then Schedule.recordApplied(state,actor,entry.id,nil) end
    end
end
function M.applied(state,actor,id,before)
    -- This Guardian-only zero is an old absence sentinel, not an existing
    -- source Power object. A later real application is a new acquisition.
    if absentGuardianHide(actor,id,before) then
        Schedule.remove(state,actor,id)
        before=nil
    end
    if M.ids[id] then Schedule.recordApplied(state,actor,id,before) end
end
return M
