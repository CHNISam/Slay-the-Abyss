-- Decision policies only. The caller owns the one mandatory roll and move history.
local A=require('abyss_actor')
local ER=require('abyss_enemy_random')
local M={}
local function twice(e,id)return e.act2Last==id and e.act2Previous==id end
local function alive(state)
    local count=0;for _,e in ipairs(state.enemies)do if A.isActive(e)then count=count+1 end end
    return count
end
function M.automaton(c)
    local e=c.enemy
    if not e.act2Last then return 'spawn_orbs' end
    if e.act2AutoTurns==4 then e.act2AutoTurns=0;return 'hyper_beam' end
    if e.act2Last=='hyper_beam'then return 'stunned' end
    e.act2AutoTurns=e.act2AutoTurns+1
    return (e.act2Last=='stunned' or e.act2Last=='boost' or e.act2Last=='spawn_orbs') and 'flail' or 'boost'
end
function M.orb(c)
    local e=c.enemy
    local n=c.roll
    if not e.act2StasisUsed and n>=25 then e.act2StasisUsed=true;return 'stasis' end
    if n>=70 and not twice(e,'support')then return 'support' end
    return not twice(e,'beam') and 'beam' or 'support'
end
local function torchDead(state,e)
    local dead=false
    for _,id in pairs(e.act2TorchSlots or {})do
        for _,ally in ipairs(state.enemies)do if ally.id==id and ally.hp<=0 then dead=true end end
    end
    return dead
end
function M.collector(c)
    local state=c.state
    local e=c.enemy
    local n=c.roll
    if not e.act2Last then return 'spawn' end
    if e.act2TurnsTaken>=3 and not e.act2UltUsed then return 'mega_debuff' end
    local dead=torchDead(state,e)
    if n<=25 and dead and e.act2Last~='revive'then return 'revive' end
    if n<=70 and not twice(e,'fireball')then return 'fireball' end
    return e.act2Last~='buff' and 'buff' or 'fireball'
end
local function leaderPair(state,e,n,random)
    while true do
        if n<50 then
            if e.act2Last~='rally'then return 'rally' end
            n=random(state,50)+49
        elseif n<80 then return e.act2Last~='encourage' and 'encourage' or 'stab'
        elseif e.act2Last~='stab'then return 'stab'
        else n=random(state,81)-1 end
    end
end
function M.leader(c)
    local state,e,n=c.state,c.enemy,c.roll
    local allies=alive(state)-(A.isActive(e) and 1 or 0)
    if allies==0 then
        if n<75 then return e.act2Last~='rally' and 'rally' or 'stab' end
        return e.act2Last~='stab' and 'stab' or 'rally'
    end
    if allies==1 then return leaderPair(state,e,n,c.random) end
    if n<66 then return e.act2Last~='encourage' and 'encourage' or 'stab' end
    return e.act2Last~='stab' and 'stab' or 'encourage'
end
function M.snecko(c)
    local e=c.enemy
    local n=c.roll
    if not e.act2Last then return 'glare' end
    if n<40 or twice(e,'bite')then return 'tail' end
    return 'bite'
end
local function airborneMove(state,e,n,random)
    if n<50 then
        if twice(e,'peck')then return ER.float(state,random)<0.4000000059604645 and 'swoop' or 'caw' end
        return 'peck'
    elseif n<70 then
        if e.act2Last=='swoop'then return ER.float(state,random)<0.375 and 'caw' or 'peck' end
        return 'swoop'
    elseif e.act2Last=='caw'then return ER.float(state,random)<0.2856999933719635 and 'swoop' or 'peck' end
    return 'caw'
end
function M.byrd(c)
    local state=c.state
    local e=c.enemy
    local n=c.roll
    local random=c.random
    if not e.act2Last then return ER.float(state,random)<0.375 and 'caw' or 'peck' end
    if (e.statuses.flight or 0)<=0 then return 'headbutt' end
    return airborneMove(state,e,n,random)
end
function M.parasite(c)
    local state=c.state
    local e=c.enemy
    local n=c.roll
    local random=c.random
    if not e.act2Last then return ER.boolean(state,random) and 'double_strike' or 'life_suck' end
    if n<20 then
        if e.act2Last~='fell'then return 'fell' end
        n=random(state,80)+19
    end
    if n<60 then return twice(e,'double_strike') and 'life_suck' or 'double_strike' end
    return twice(e,'life_suck') and 'double_strike' or 'life_suck'
end
function M.chosen(c)
    local e=c.enemy
    local n=c.roll
    if not e.act2Last then return 'poke' end
    if not e.act2HexUsed then e.act2HexUsed=true;return 'hex' end
    if e.act2Last~='drain' and e.act2Last~='debilitate'then return n<50 and 'debilitate' or 'drain' end
    return n<40 and 'zap' or 'poke'
end
function M.snake(c)
    local e=c.enemy
    local n=c.roll
    if n<65 then return twice(e,'chomp') and 'spores' or 'chomp' end
    return e.act2Last=='spores' and 'chomp' or 'spores'
end
local function championPhase(e)
    e.act2Turns=e.act2Turns+1
    if e.hp<e.maxHp/2 and not e.act2Enraged then e.act2Enraged=true;return 'anger' end
    if e.act2Enraged and e.act2Last~='execute' and e.act2Previous~='execute'then return 'execute' end
    if e.act2Turns==4 and not e.act2Enraged then e.act2Turns=0;return 'taunt' end
end
function M.champ(c)
    local e,n=c.enemy,c.roll
    local phase=championPhase(e)
    if phase then return phase end
    if e.act2Last~='defensive_stance' and e.act2Forges<2 and n<=15 then
        e.act2Forges=e.act2Forges+1;return 'defensive_stance'
    end
    if e.act2Last~='gloat' and e.act2Last~='defensive_stance' and n<=30 then return 'gloat' end
    if e.act2Last~='face_slap' and n<=55 then return 'face_slap' end
    return e.act2Last~='heavy_slash' and 'heavy_slash' or 'face_slap'
end
function M.taskmaster()
    return 'whip'
end
function M.book(c)
    local e=c.enemy
    local n=c.roll
    if n<15 then return e.act2Last=='big_stab' and 'multi_stab' or 'big_stab' end
    return twice(e,'multi_stab') and 'big_stab' or 'multi_stab'
end
function M.sphere(c)
    local e=c.enemy
    if not e.act2Last then return 'activate' end
    if e.act2Last=='activate' then return 'frail_attack' end
    return e.act2Last=='slam' and 'harden' or 'slam'
end
function M.centurion(c)
    local state=c.state
    local e=c.enemy
    local n=c.roll
    if (n>=65 and not twice(e,'protect') and not twice(e,'fury')) or twice(e,'slash') then
        return alive(state)>1 and 'protect' or 'fury'
    end
    return 'slash'
end
function M.mystic(c)
    local state=c.state
    local e=c.enemy
    local n=c.roll
    local missing=0
    for _,ally in ipairs(state.enemies)do if A.isActive(ally)then missing=missing+ally.maxHp-ally.hp end end
    if missing>15 and not twice(e,'heal') then return 'heal' end
    if n>=40 and not twice(e,'attack')then return 'attack' end
    return not twice(e,'buff') and 'buff' or 'attack'
end
return M
