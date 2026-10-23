-- Source-derived Act1 catalog and pool lifecycle. Full mode is an audit model;
-- launch explicitly uses the user-approved six complete event implementations.
-- Mirror fc379c875c11e008e9c10548ac8e394c301c532f, Exordium + AbstractDungeon.
local R = require('abyss_sts_random')
local M = {}
local act={'Big Fish','The Cleric','Dead Adventurer','Golden Idol','Golden Wing','World of Goop','Liars Game','Living Wall','Mushrooms','Scrap Ooze','Shining Light'}
local shrine={'Match and Keep!','Golden Shrine','Transmorgrifier','Purifier','Upgrade Shrine','Wheel of Change'}
local once={'Accursed Blacksmith','Bonfire Elementals','Designer','Duplicator','FaceTrader','Fountain of Cleansing','Knowing Skull','Lab',"N'loth",'SecretPortal','The Joust','WeMeetAgain','The Woman in Blue'}
M.contentId={['The Cleric']='cleric',Purifier='purifier',['World of Goop']='goop',['Upgrade Shrine']='upgrade_shrine',['Golden Wing']='golden_wing',['Shining Light']='shining_light'}
local function copy(t) local r={};for i,v in ipairs(t) do r[i]=v end;return r end
function M.new(mode, noteAvailable)
    assert(mode=='full' or mode=='restricted-six','unknown event pool mode')
    local p={mode=mode,act=copy(act),shrine=copy(shrine),once=copy(once)}
    if noteAvailable then table.insert(p.once,10,'NoteForYourself') end
    if mode=='restricted-six' then
        p.act={'The Cleric','Golden Wing','World of Goop','Shining Light'}
        p.shrine={'Purifier','Upgrade Shrine'};p.once={}
    end
    return p
end
function M.nextAct(p)
    local fresh=M.new(p.mode)
    p.act,p.shrine=fresh.act,fresh.shrine -- once retains its run-wide lifecycle
end
function M.isEligible(id,c)
    if id=='The Cleric' then return c.gold>=35 end
    if id=='Dead Adventurer' or id=='Mushrooms' then return c.floor>6 end
    if id=='Fountain of Cleansing' then return c.cursed==true end
    if id=='Designer' then return c.act>=2 and c.gold>=75 end
    if id=='Duplicator' then return c.act>=2 end -- mirror; Wiki Act1 conflict remains unresolved
    if id=='FaceTrader' then return c.act<=2 end
    if id=='Knowing Skull' then return c.act==2 and c.hp>12 end
    if id=="N'loth" then return c.act==2 and c.relicCount>=2 end
    if id=='The Joust' then return c.act==2 and c.gold>=50 end
    if id=='The Woman in Blue' then return c.gold>=50 end
    if id=='SecretPortal' then return c.act==3 and c.elapsedSeconds>=800 end
    return true
end
function M.eligible(p,c)
    local result={act={},rare={}}
    for _,kind in ipairs({'act','shrine','once'}) do
        for _,id in ipairs(p[kind]) do
            if M.isEligible(id,c) then
                local list=kind=='act' and result.act or result.rare
                list[#list+1]=id
            end
        end
    end
    return result
end
function M.draw(p,c,rng,roll)
    local e=M.eligible(p,c)
    if #e.act==0 and #e.rare==0 then return nil,'event_pool_exhausted' end
    if roll==nil then roll=R.randomFloatRange(rng,1.0) end
    assert(type(roll)=='number' and roll>=0 and roll<1,'invalid pool roll')
    local candidates=roll<.25 and e.rare or e.act
    if #candidates==0 then candidates=roll<.25 and e.act or e.rare end
    local id=candidates[R.randomInt(rng,#candidates-1)+1]
    for _,kind in ipairs({'act','shrine','once'}) do
        for i,value in ipairs(p[kind]) do if value==id then table.remove(p[kind],i);return id,kind end end
    end
    error('selected event not in source pool')
end
return M
