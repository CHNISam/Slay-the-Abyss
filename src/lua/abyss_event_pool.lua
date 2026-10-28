-- Source-derived Act1 catalog and pool lifecycle. Full mode is an audit model;
-- launch explicitly uses seven complete event implementations, not the full pool.
-- Mirror fc379c875c11e008e9c10548ac8e394c301c532f, Exordium + AbstractDungeon.
local R = require('abyss_sts_random')
local M = {}
local act={'Big Fish','The Cleric','Dead Adventurer','Golden Idol','Golden Wing','World of Goop','Liars Game','Living Wall','Mushrooms','Scrap Ooze','Shining Light'}
local shrine={'Match and Keep!','Golden Shrine','Transmorgrifier','Purifier','Upgrade Shrine','Wheel of Change'}
local once={'Accursed Blacksmith','Bonfire Elementals','Designer','Duplicator','FaceTrader','Fountain of Cleansing','Knowing Skull','Lab',"N'loth",'SecretPortal','The Joust','WeMeetAgain','The Woman in Blue'}
local chapterEvents={
    [2]={'Addict','Back to Basics','Beggar','Colosseum','Cursed Tome','Drug Dealer','Forgotten Altar','Ghosts','Masked Bandits','Nest','The Library','The Mausoleum','Vampires'},
    [3]={'Falling','MindBloom','The Moai Head','Mysterious Sphere','SensoryStone','Tomb of Lord Red Mask','Winding Halls'},
    [4]={},
}
local chapterShrines={'Match and Keep!','Wheel of Change','Golden Shrine','Transmorgrifier','Purifier','Upgrade Shrine'}
M.contentId={['The Cleric']='cleric',Purifier='purifier',['World of Goop']='goop',['Upgrade Shrine']='upgrade_shrine',['Golden Wing']='golden_wing',['Shining Light']='shining_light',['Golden Shrine']='golden_shrine'}
local function copy(t) local r={};for i,v in ipairs(t) do r[i]=v end;return r end
M.contentId['Fountain of Cleansing']='fountain'
M.contentId['Liars Game']='sssserpent'
M.contentId['Big Fish']='big_fish'
M.contentId['Accursed Blacksmith']='accursed_blacksmith'
M.contentId['Bonfire Elementals']='bonfire'
M.contentId.Transmorgrifier='transmogrifier'
M.contentId['Living Wall']='living_wall'
M.contentId['Scrap Ooze']='scrap_ooze'
M.contentId['Wheel of Change']='wheel'
M.contentId.Lab='lab'
M.contentId['The Woman in Blue']='woman_in_blue'
M.contentId.WeMeetAgain='we_meet_again'
M.contentId.Beggar='beggar'
M.contentId['The Joust']='joust'
M.contentId['The Mausoleum']='mausoleum'
M.contentId.Addict='addict'
M.contentId['Back to Basics']='back_to_basics'
M.contentId['The Library']='the_library'
M.contentId.Falling='falling'
M.contentId['Golden Idol']='golden_idol'
M.contentId.Mushrooms='mushrooms'
M.contentId['Winding Halls']='winding_halls'
M.contentId.SensoryStone='sensory_stone'
M.contentId['The Moai Head']='moai_head'
M.contentId['Tomb of Lord Red Mask']='tomb_red_mask'
M.contentId.Ghosts='ghosts'
M.contentId.MindBloom='mind_bloom'
M.contentId['Mysterious Sphere']='mysterious_sphere'

function M.new(mode, noteAvailable, chapter)
    assert(mode=='full' or mode=='restricted-six' or mode=='restricted-seven','unknown event pool mode')
    if chapter==nil then chapter=1 end
    assert(chapter==1 or chapter==2 or chapter==3 or chapter==4,'invalid event act')
    assert(chapter==1 or mode=='full','later acts require full event pools')
    local p={mode=mode,act=copy(chapter==1 and act or chapterEvents[chapter]),
        shrine=copy(chapter==1 and shrine or chapter==4 and {} or chapterShrines),once=copy(once)}
    if chapter~=1 then p.actNumber=chapter end
    if noteAvailable then table.insert(p.once,10,'NoteForYourself') end
    if mode=='restricted-six' or mode=='restricted-seven' then
        p.act={'The Cleric','Golden Wing','World of Goop','Shining Light'}
        p.shrine={'Purifier','Upgrade Shrine'};p.once={}
        if mode=='restricted-seven' then table.insert(p.shrine,1,'Golden Shrine') end
    end
    return p
end
function M.nextAct(p,chapter)
    local fresh=M.new(p.mode,false,chapter or p.actNumber or 1)
    p.actNumber=fresh.actNumber
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
