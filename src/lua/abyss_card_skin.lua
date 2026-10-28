-- Shared read-only native card decoration. All colours and dimensions come from Theme.
local Theme=require('abyss_theme')
local M={}
local config=Theme.cardSkin
local roundNames={'vertical','horizontal','corner-1_-1','corner-1_1','corner1_-1','corner1_1'}
local windowNames={skill=roundNames,power={'arch','base'},attack={'upper','point'}}
local emblemNames={HT={'petal0','petal1','petal2','petal3','petal4'},AR={'moon'},FR={'water','tip'},RD={'bolt','tail'},curse={'slash','backslash'}}
local phases=setmetatable({},{__mode='k'})
local activeHalos=setmetatable({},{__mode='k'})
local decorations=setmetatable({},{__mode='k'})
function M.tick(box,dt)
    if not activeHalos[box] then return end
    local phase=(phases[box] or 0)+math.max(0,dt);phases[box]=phase
    local scale=.985+.065*math.sin(phase*math.pi*2/1.8)
    box:GetChild('costHalo'):SetLocalScale(scale,scale,1)
end
local function mix(a,b,k)
    local function channel(x,y)return math.floor(x+(y-x)*k+.5)end
    return {r=channel(a.r,b.r),g=channel(a.g,b.g),b=channel(a.b,b.b),a=255}
end
local function painter(platform)
    return function(control,c)control.imageColor=platform.color(c.r,c.g,c.b,c.a or 255)end
end
local function paint(group,names,c,tint)
    for _,name in ipairs(names)do tint(group:GetChild(name),c)end
end
local function identity(definition)
    if definition.originalV4 then return definition.originalV4.role end
    if definition.type=='curse' then return 'curse' end
    if definition.color=='colorless' then return 'colorless' end
    return 'traveler'
end
local function frame(box,definition,look,tint)
    local rarity=config.rarities[definition.rarity] or config.rarities.basic
    local edge=rarity[1]
    if look.selected then edge=Theme.color.goldBright elseif look.dim then edge=Theme.color.line end
    tint(box:GetChild('border'),edge);paint(box:GetChild('roundFrame'),roundNames,edge,tint)
    tint(box:GetChild('nameRule'),rarity[4])
    local skin=box:GetChild('skin');tint(skin:GetChild('gloss'),rarity[4])
    for i=1,config.bandSteps do tint(skin:GetChild('band'..i),mix(rarity[2],rarity[3],(i-1)/(config.bandSteps-1)))end
end
local function window(box,definition,look,accent,tint)
    local shape=definition.type
    if not windowNames[shape] then shape='attack' end
    box:GetChild('artPlate'):SetVisible(false);box:GetChild('artWell'):SetVisible(false)
    for kind,names in pairs(windowNames)do
        local group=box:GetChild('skin'):GetChild(kind);group:SetVisible(kind==shape)
        if kind==shape then
            paint(group:GetChild('edge'),names,look.dim and Theme.color.line or accent,tint)
            paint(group:GetChild('well'),names,mix(Theme.color.cardWell,accent,.05),tint)
        end
    end
    paint(box:GetChild('tagEdge'),roundNames,accent,tint)
    tint(box:GetChild('typeEdge'),accent)
end
local function emblem(box,role,accent,tint)
    for key in pairs(config.roles)do
        local symbol=box:GetChild('roleMark'):GetChild(key);symbol:SetVisible(key==role)
        paint(symbol,emblemNames[key] or {'symbol'},accent,tint)
    end
end
local function costTone(current,base,dim,accent)
    if dim then return Theme.color.danger end
    if current<base then return Theme.color.positive end
    if current>base then return Theme.color.danger end
    return accent
end
local function costState(look)
    local current,base=look.cost,look.baseCost
    if type(current)~='number' or type(base)~='number' then return false,0,0 end
    return current>=0 and base>=0 and current~=base,current,base
end
local function costs(box,definition,look,accent,platform,tint)
    local changed,current,base=costState(look)
    local tone=accent
    if changed or look.dim then tone=costTone(current,base,look.dim,accent)end
    tint(box:GetChild('costDisc'),tone);tint(box:GetChild('costHalo'),tone)
    box:GetChild('cost').fontColor=platform.color(tone.r,tone.g,tone.b,255)
    local hasCost=definition.cost~=-2
    for _,name in ipairs({'costCore','costDisc','cost'})do box:GetChild(name):SetVisible(hasCost)end
    activeHalos[box]=changed and hasCost
    box:GetChild('costHalo'):SetVisible(changed and hasCost)
    local direction=box:GetChild('costDirection');direction:SetVisible(changed and hasCost)
    direction.text=changed and (current<base and '↓' or '↑') or ''
    direction.fontColor=platform.color(tone.r,tone.g,tone.b,255)
end
function M.apply(box,definition,platform,look)
    look=look or {}
    local role=identity(definition)
    local accent=(config.roles[role] or config.roles.traveler).accent
    local tint=painter(platform)
    local key=table.concat({role,definition.rarity or 'basic',definition.type or 'status',tostring(look.dim),tostring(look.selected)},':')
    if decorations[box]~=key then
        frame(box,definition,look,tint);window(box,definition,look,accent,tint)
        emblem(box,role,accent,tint);decorations[box]=key
    end
    tint(box:GetChild('nameRule'),(config.rarities[definition.rarity] or config.rarities.basic)[4])
    costs(box,definition,look,accent,platform,tint)
    box:GetChild('type').fontColor=platform.color(accent.r,accent.g,accent.b,255)
    local reason=box:GetChild('blockedReason');reason:SetVisible(look.dim==true)
    reason.text=look.reason or '当前不可打出'
end
return M
