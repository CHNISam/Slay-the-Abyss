-- Read-only presentation of values already calculated by Combat.cardPreview.
local integer = require('abyss_numbers').integer
local Theme = require('abyss_theme')
local M = {}
local eligible = {damage=true, damageAll=true, block=true,fiendFire=true,feed=true,reaper=true,damageRandom=true,secondWind=true}
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
    return text,font,fits
end
function M.writeTitle(control,name,upgraded,upgrades)
    local text,font,fits=M.title(name,upgraded,upgrades)
    control.adaptiveFontSize=false
    control.text,control.fontSize=text,font
    return fits
end
function M.writeBody(control,text)
    local box=Theme.layout.card.textBox
    local font,fits=M.fit(text,Theme.font.card,box[1],box[2])
    control.text,control.fontSize=text,font
    return fits
end
function M.values(definition, preview)
    local result = {}
    for index, effect in ipairs(definition.effects) do
        local entry = preview[index]
        if eligible[effect.op] and entry and entry.op == effect.op
            and type(effect.value) == 'number' and type(entry.low) == 'number' and entry.low == entry.high then
            local direction = entry.low > effect.value and 'up' or entry.low < effect.value and 'down' or 'same'
            result[index] = {effectIndex=index, op=effect.op, base=effect.value, current=entry.low,
                direction=direction, text=integer(entry.low) .. (direction=='up' and '↑' or direction=='down' and '↓' or ''),
                colourKey=direction=='up' and 'cardValueIncrease' or direction=='down' and 'cardValueDecrease' or 'text'}
        end
    end
    return result
end
-- Encodes only the numeric dynamic variable, never the surrounding sentence.
-- Native colour parsing verified by the independent 1849 probe (see evidence).
function M.format(template, definition, preview, palette)
    local values = M.values(definition, preview)
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
    local text=instance.upgraded and display.upgradeText or display.text
    local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
    return live and M.format(live,definition,{},Theme.color) or text or ''
end
function M.combatText(display,definition,instance,preview)
    local text=instance.upgraded and display.upgradeText or display.text
    local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
    if live then text=M.format(live,definition,preview,Theme.color)end
    for _,entry in pairs(preview)do
        if entry.op=='damageEqualToBlock'then text=text..'（当前 '..integer(entry.low)..' 点）'end
    end
    return text
end
return M
