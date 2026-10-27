-- Read-only presentation of values already calculated by Combat.cardPreview.
local integer = require('abyss_numbers').integer
local Theme = require('abyss_theme')
local M = {}
-- Like a card-atlas region, artwork belongs to the stable card ID. A type
-- glyph remains an explicit placeholder until a production asset is bound.
function M.art(definition)
    local entry = (Theme.icon.cardPortraits or {})[definition.id]
    local image = entry and (type(entry) == 'table' and entry.id or entry)
        or Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status
    assert(type(image) == 'number' and image > 0 and image % 1 == 0, 'card artwork must be a native image ID')
    return image, entry and (type(entry) == 'table' and entry.status or 'native-card-asset') or 'placeholder-type-icon',
        type(entry) == 'table' and entry.size or nil
end
-- Native portraits opt in with their source dimensions. Type/legacy icons stay
-- square; a native ID alone is not evidence of a full-card illustration.
function M.writeArt(control,definition,picture)
    local image,status,source=M.art(definition)
    local card=Theme.layout.card
    local width,height=math.min(card.costDisc,card.art),math.min(card.costDisc,card.art)
    if source then
        assert(type(source)=='table' and #source==2 and type(source[1])=='number' and type(source[2])=='number'
            and source[1]>0 and source[2]>0 and source[1]<math.huge and source[2]<math.huge,
            'card portrait source size must contain two positive finite dimensions')
        if not tostring(status):find('^placeholder') then
            local scale=math.min((card.size[1]-Theme.space.border*2)/source[1],card.art/source[2])
            width,height=source[1]*scale,source[2]*scale
        end
    end
    picture(control,image)
    control:SetSizeDelta(width,height)
end
local eligible = {damage=true, damageAll=true, block=true,fiendFire=true,feed=true,reaper=true,damageRandom=true,secondWind=true,
    whirlwind=true,reaperDamage=true}
for _,op in ipairs({'barrageDamage','bowlingBash','ftlDamage','heelHook','nextBlock','xBlock','halt',
    'fearNoEvil','wallop','flowDamage','blizzardDamage','sunderDamage','randomEngineAttack','thunderStrike',
    'finisherDamage','flechettesDamage','skewer','glassKnife','stackBlock','autoShields','escapePlan',
    'watcherFinalRagnarok','watcherFinalExpungerHits','watcherFinalLessonLearned','watcherFinalSpiritShield'}) do eligible[op]=true end
-- Conservative visible-glyph budget. Native autoSize does not guarantee that
-- a dynamically replaced long name fits its original one-line heading.
local function units(text)
    local n=0
    for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        n=n+(#ch>1 and 1 or ch:match('[ilI.,:;! ]') and .35 or ch:match('[MW]') and .9 or .65)
    end
    return n
end
local function lines(text,width,font)
    local count,used=1,0
    text=text:gsub('<[^>]+>','')
    for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        if ch=='\n' then count=count+1;used=0
        else
            local advance=units(ch)*font
            if used+advance>width then count=count+1;used=0 end
            used=used+advance
        end
    end
    return count
end
function M.fit(text,maximum,width,height,lineScale)
    for font=maximum,Theme.font.minimum,-1 do
        if lines(text,width,font)*font*(lineScale or 1.3)<=height then return font,true end
    end
    return Theme.font.minimum,false
end
function M.title(name,upgraded,upgrades)
    local suffix=upgraded and ('＋'..(upgrades and integer(upgrades) or '')) or ''
    local card=Theme.layout.card
    local width=card.size[1]-card.costDisc-Theme.space.s
    local text=name..suffix
    local font,fits=M.fit(text,Theme.font.cardName,width,card.nameBand,1.65)
    -- Prefer a readable two-line full name to shrinking a complete English
    -- title into one line. The canonical presentation name is never changed.
    if units(text)*Theme.font.cardName>width then
        local best,score
        for pos in name:gmatch('() ') do
            local a,b=name:sub(1,pos-1),name:sub(pos+1)..suffix
            local size=math.max(units(a),units(b))
            if not score or size<score then best=a..'\n'..b;score=size end
        end
        if best then
            local candidate,ok=M.fit(best,Theme.font.cardName,width,card.nameBand,1.65)
            if ok then text,font,fits=best,candidate,true end
        end
    end
    -- Keep the approved one-line title band. Only an upgrade suffix that makes
    -- a complete readable name overflow moves to the existing type text slot.
    if not fits and upgraded then
        local plainFont,plainFits=M.fit(name,Theme.font.cardName,width,card.nameBand,1.65)
        if plainFits then return name,plainFont,true,suffix end
    end
    return text,font,fits,''
end
function M.writeTitle(control,name,upgraded,upgrades,typeControl,typeText)
    local text,font,fits,marker=M.title(name,upgraded,upgrades)
    control.adaptiveFontSize=false
    control.text,control.fontSize=text,font
    if typeControl then typeControl.text=typeText..(marker~='' and ' '..marker or '') end
    return fits
end
function M.writeBody(control,text)
    local box=Theme.layout.card.textBox
    local font,fits=M.fit(text,Theme.font.card,box[1],box[2])
    control.text,control.fontSize=text,font
    return fits
end
local valueStyles = {
    up = { arrow = '↑', colourKey = 'cardValueIncrease' },
    down = { arrow = '↓', colourKey = 'cardValueDecrease' },
    same = { arrow = '', colourKey = 'text' },
}
local function exactValue(effect, entry)
    return eligible[effect.op] and entry and entry.op == effect.op
        and type(effect.value) == 'number' and type(entry.low) == 'number' and entry.low == entry.high
end
local function valueDirection(base, current)
    if current > base then return 'up' end
    if current < base then return 'down' end
    return 'same'
end
function M.values(definition, preview)
    local result = {}
    for index, effect in ipairs(definition.effects) do
        local entry = preview[index]
        if exactValue(effect, entry) then
            local direction = valueDirection(effect.value, entry.low)
            local style = valueStyles[direction]
            result[index] = {effectIndex=index, op=effect.op, base=effect.value, current=entry.low,
                direction=direction, text=integer(entry.low) .. style.arrow, colourKey=style.colourKey}
        end
    end
    return result
end
-- Encodes only the numeric dynamic variable, never the surrounding sentence.
-- Native colour parsing verified by the independent 1849 probe (see evidence).
function M.format(template, definition, preview, palette)
    template=template:gsub('{expungerHits}',function()return integer(definition.expungerHits or 0)end)
    local values = M.values(definition, preview)
    template=template:gsub('{effects%.(%d+)%.then%.(%d+)%.value}',function(rawParent,rawChild)
        local parent,child=tonumber(rawParent)+1,tonumber(rawChild)
        local effect=assert(definition.effects[parent],'missing conditional definition')
        assert(effect.op=='conditional' and effect['then'],'invalid conditional token')
        local branch=preview[parent] and preview[parent]['then'] or {}
        return M.format('{effects.'..child..'.value}',{effects=effect['then']},branch,palette)
    end)
    -- These attacks keep damage separate from their fixed gold/growth value.
    -- Reuse the existing damage formatter, including its colour/arrow rules.
    template=template:gsub('{effects%.(%d+)%.damage}',function(rawIndex)
        local index=tonumber(rawIndex)+1
        local effect=assert(definition.effects[index],'missing colorless damage definition')
        assert(effect.op=='colorless'and (effect.kind=='ritual'or effect.kind=='greed'),'invalid colorless damage token')
        local entry=preview[index]
        return M.format('{effects.0.value}',{effects={{op='damage',value=effect.damage or effect.value}}},entry and {entry}or {},palette)
    end)
    return (template:gsub('{effects%.(%d+)%.value}', function(rawIndex)
        local index = tonumber(rawIndex) + 1
        local token, entry = values[index], preview[index]
        if token and token.direction ~= 'same' then
            local colour = assert(palette[token.colourKey])
            local hex = string.format('#%02X%02X%02X', colour.r, colour.g, colour.b)
            return '<color=' .. hex .. '>' .. token.text .. '</color>'
        end
        if entry then
            assert(entry.low == entry.high, 'card damage display must be exact')
            return integer(entry.low)
        end
        return integer(definition.effects[index].value)
    end))
end
function M.permanentText(display,definition,instance)
    if definition.originalV4 then return require('abyss_original_v4_display').brief(definition,instance.upgraded)end
    local text=instance.upgraded and display.upgradeText or display.text
    if definition.id=='mind_blast' then return text or '' end
    local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
    return live and M.format(live,definition,{},Theme.color) or text or ''
end
function M.combatText(display,definition,instance,preview)
    if definition.originalV4 then return require('abyss_original_v4_display').brief(definition,instance.upgraded,preview)end
    local text=instance.upgraded and display.upgradeText or display.text
    local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
    if live then text=M.format(live,definition,preview,Theme.color)end
    for _,entry in pairs(preview)do
        if entry.op=='damageEqualToBlock'then text=text..'（当前 '..integer(entry.low)..' 点）'end
    end
    return text
end
return M
