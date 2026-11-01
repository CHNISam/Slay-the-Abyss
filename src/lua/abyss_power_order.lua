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
-- Verified source presentation facts, sts@319009d5. AbstractPower defaults:
-- priority=5, amount=-1, isTurnBased=false, canGoNegative=false.
M.sourceFacts={
    choked={priority=5,isTurnBased=false,canGoNegative=false}, -- ChokePower
    mark={priority=5,isTurnBased=false,canGoNegative=false}, -- watcher.MarkPower (ID PathToVictoryPower)
    lock_on={priority=5,isTurnBased=true,canGoNegative=false}, -- LockOnPower
    focus={priority=5,isTurnBased=false,canGoNegative=true}, -- FocusPower
    block_return={priority=5,isTurnBased=false,canGoNegative=false}, -- BlockReturnPower
    draw_reduction={priority=5,isTurnBased=true,canGoNegative=false}, -- DrawReductionPower
    no_block={priority=5,isTurnBased=true,canGoNegative=false}, -- NoBlockPower
    generic_strength_up={priority=5,isTurnBased=false,canGoNegative=false}, -- GenericStrengthUpPower
    shifting={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- ShiftingPower
    reactive={priority=50,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- ReactivePower
    split={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- SplitPower
    strength={priority=5,isTurnBased=false,canGoNegative=true}, -- StrengthPower
    dexterity={priority=5,isTurnBased=false,canGoNegative=true}, -- DexterityPower
    weak={priority=99,isTurnBased=true,canGoNegative=false}, -- WeakPower
    frail={priority=10,isTurnBased=true,canGoNegative=false}, -- FrailPower
    vulnerable={priority=5,isTurnBased=true,canGoNegative=false}, -- VulnerablePower
    poison={priority=5,isTurnBased=true,canGoNegative=false}, -- PoisonPower
    curl_up={priority=5,isTurnBased=false,canGoNegative=false}, -- CurlUpPower
    spore_cloud={priority=5,isTurnBased=false,canGoNegative=false}, -- SporeCloudPower
    metallicize={priority=5,isTurnBased=false,canGoNegative=false}, -- MetallicizePower
    angry={priority=5,isTurnBased=false,canGoNegative=false}, -- AngryPower
    enrage={priority=5,isTurnBased=false,canGoNegative=false}, -- AngerPower
    thievery={priority=5,isTurnBased=false,canGoNegative=false}, -- ThieveryPower
    ritual={priority=5,isTurnBased=false,canGoNegative=false}, -- RitualPower
    mode_shift={priority=5,isTurnBased=false,canGoNegative=false}, -- ModeShiftPower
    sharp_hide={priority=5,isTurnBased=false,canGoNegative=false}, -- SharpHidePower
    artifact={priority=5,isTurnBased=false,canGoNegative=false}, -- ArtifactPower
    barricade={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- BarricadePower
    flight={priority=50,isTurnBased=false,canGoNegative=false}, -- FlightPower
    malleable={priority=5,isTurnBased=false,canGoNegative=false}, -- MalleablePower
    plated_armor={priority=5,isTurnBased=false,canGoNegative=false}, -- PlatedArmorPower
    painful_stabs={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- PainfulStabsPower
    hex={priority=5,isTurnBased=false,canGoNegative=false}, -- HexPower
    confusion={priority=0,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- ConfusionPower
    minion={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- MinionPower
    stasis={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- StasisPower
    thorns={priority=5,isTurnBased=false,canGoNegative=false}, -- ThornsPower
    entangled={priority=5,isTurnBased=true,canGoNegative=false}, -- EntanglePower
    corpse_explosion={priority=5,isTurnBased=false,canGoNegative=false}, -- CorpseExplosionPower
    slow={priority=5,isTurnBased=false,canGoNegative=false}, -- SlowPower
    time_warp={priority=5,isTurnBased=false,canGoNegative=false}, -- TimeWarpPower
    shackled={priority=5,isTurnBased=false,canGoNegative=false}, -- GainStrengthPower
    invincible={priority=99,isTurnBased=false,canGoNegative=false}, -- InvinciblePower
    curiosity={priority=5,isTurnBased=false,canGoNegative=false}, -- CuriosityPower
    unawakened={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- UnawakenedPower
    regrow={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- RegrowPower
    regenerate_monster={priority=5,isTurnBased=false,canGoNegative=false}, -- RegenerateMonsterPower
    fading={priority=5,isTurnBased=false,canGoNegative=false}, -- FadingPower
    explosive={priority=5,isTurnBased=false,canGoNegative=false}, -- ExplosivePower
    nemesis_intangible={priority=75,isTurnBased=false,canGoNegative=false}, -- IntangiblePower
    intangible={priority=75,isTurnBased=false,canGoNegative=false}, -- IntangiblePlayerPower
    constricted={priority=105,isTurnBased=false,canGoNegative=false}, -- ConstrictedPower
    back_attack={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- BackAttackPower
    surrounded={priority=5,isTurnBased=false,canGoNegative=false,sourceAmount=-1}, -- SurroundedPower
    beat_of_death={priority=5,isTurnBased=false,canGoNegative=false}, -- BeatOfDeathPower
}
-- AbstractCreature.addPower appends; ApplyPowerAction sorts only a new Power.
-- Copy-on-write preserves detached event frames. powerScheduleOrder remains
-- the separate hook scheduling ABI, not another display-order registry.
local function copyOrder(actor,removed)
    local out={}
    for _,id in ipairs(actor.powerOrder or {})do if id~=removed then out[#out+1]=id end end
    return out
end
function M.remove(actor,id)
    actor.powerOrder=copyOrder(actor,id)
end
function M.contains(actor,id)
    for _,old in ipairs(actor.powerOrder or {})do if old==id then return true end end
    return false
end
function M.directAdd(actor,id)
    if M.contains(actor,id)then return false end
    local order=copyOrder(actor);order[#order+1]=id;actor.powerOrder=order
    return true
end
local function priority(actor,id)
    -- Synthetic original Powers live in primitive fields in this engine.
    if id=='no_draw' or id=='lose_strength' or id=='lose_dexterity' then return 5 end
    local definition=assert(actor.statusDefinitions[id],'unknown Power: '..id)
    local source=M.sourceFacts[id]
    if source then return source.priority end
    -- Not ported: retain the existing engine metadata/default contract for
    -- powers outside the verified roster/incoming-card set, not source proof.
    return definition.priority or 5
end
function M.applyNew(actor,id)
    if not M.directAdd(actor,id)then return false end
    local order=actor.powerOrder
    -- Collections.sort is stable: ties retain the current list position.
    for i=2,#order do
        local id0,j=order[i],i-1
        while j>=1 and priority(actor,order[j])>priority(actor,id0)do order[j+1]=order[j];j=j-1 end
        order[j+1]=id0
    end
    return true
end
return M
