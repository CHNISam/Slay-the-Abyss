-- Read-only presentation of values already calculated by Combat.cardPreview.
local integer = require('abyss_numbers').integer
local Theme = require('abyss_theme')
local NativeArtRuntime = require('abyss_card_art_runtime')
local M = {}
-- Install presentation-only art metadata atomically after real native binding.
function M.bindNativeAssets(presentation, assets)
    assert(type(presentation)=='table' and type(assets)=='table','native artwork registry required')
    for id,metadata in pairs(assets) do
        assert(type(presentation[id])=='table' and type(metadata)=='table'
            and metadata.cardId==id and metadata.runtime==true,'invalid native artwork identity')
    end
    for id,metadata in pairs(assets) do presentation[id].nativeArt=metadata end
end
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
    local width,height=math.min(card.artIcon,card.art),math.min(card.artIcon,card.art)
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
-- Candidate-only binding into controls already owned by the real card face.
-- Weak keys do not keep recycled native controls alive. Failed versions wait
-- for explicit clear/rebind rather than retrying thousands of writes per frame.
local appliedArt = setmetatable({}, {__mode='k'})
local function nativePool(box)
    local ok,pool=pcall(box.GetChild,box,'artSamples')
    return ok and pool or nil
end
local function hideNative(control)
    if not control or control.alive==false then return true end
    local ok,result=pcall(control.SetVisible,control,false)
    return ok and result~=false
end
local function invalidateStatic(box,pool,controls)
    local retained,seen={},{}
    local previous=appliedArt[pool]
    for _,list in ipairs({previous and previous.controls or {},controls})do
        for _,control in ipairs(list)do
            if not seen[control]then retained[#retained+1]=control;seen[control]=true end
        end
    end
    -- Keep cleanup ownership, but no successful geometry cache. A nested newer
    -- render during reconciliation can replace this tombstone without clobbering.
    appliedArt[pool]={controls=retained}
    NativeArtRuntime.invalidatePublication(box,pool)
end
function M.clearNativeArt(box,fallback)
    local pool=box.alive~=false and nativePool(box) or nil
    local intent=NativeArtRuntime.release(box,fallback,pool)
    if box.alive==false or intent and not NativeArtRuntime.owns(intent) then return intent,false end
    if pool then
        if not intent then hideNative(pool)end
        local previous=appliedArt[pool]
        if previous then
            local clean=true
            for _,control in ipairs(previous.controls)do
                if not hideNative(control)then clean=false end
                if intent and not NativeArtRuntime.owns(intent)then
                    invalidateStatic(box,pool,previous.controls);return intent,false
                end
            end
            if not clean then invalidateStatic(box,pool,previous.controls);return intent,false end
        end
        appliedArt[pool]=nil
    end
    return intent,true
end
local function nativeSlot(pool,index)
    local group=assert(pool:GetChild(string.format('group%03d',math.floor((index-1)/60))),'missing native art group')
    return assert(group:GetChild(string.format('shape%04d',index-1)),'missing native art slot')
end
local function writeNativeSlot(control,slot,platform)
    control:SetImage(platform.imageSource,slot.image)
    local imageType=assert(platform.imageTypes and platform.imageTypes[slot.imageType],'missing native image type enum')
    control.imageType=imageType
    assert(control.imageType==imageType,'native image type rejected')
    control:SetAnchorMin(slot.anchorMin[1],slot.anchorMin[2])
    control:SetAnchorMax(slot.anchorMax[1],slot.anchorMax[2])
    control:SetPivot(slot.pivot[1],slot.pivot[2])
    control:SetSizeDelta(slot.size[1],slot.size[2])
    control:SetLocalScale(slot.scale[1],slot.scale[2],1)
    assert(control:SetLocalRotation(slot.rotation[1],slot.rotation[2],slot.rotation[3])~=false,'native XYZ rotation rejected')
    control:SetAnchoredPosition(slot.position[1],slot.position[2])
    control.imageColor=platform.color(slot.colour[1],slot.colour[2],slot.colour[3],slot.colour[4])
    control:SetVisible(true)
end
local function writeStaticNativeArt(box,pool,definition,metadata,platform,fallback)
    local intent=NativeArtRuntime.release(box,fallback,pool)
    if not NativeArtRuntime.owns(intent)then return false end
    local previous=appliedArt[pool]
    if not previous or previous.metadata~=metadata then
        local controls={}
        local ok,reason=pcall(function()
            for index=1,metadata.capacity do
                controls[index]=nativeSlot(pool,index);NativeArtRuntime.guardPublication(intent,controls[index]):SetVisible(false)
            end
            for index,slot in ipairs(metadata.slots)do
                writeNativeSlot(NativeArtRuntime.guardPublication(intent,controls[index]),slot,platform)
            end
        end)
        if not ok then
            for _,control in ipairs(controls)do
                if not NativeArtRuntime.owns(intent)then break end
                hideNative(control)
            end
        end
        if not NativeArtRuntime.owns(intent)then
            invalidateStatic(box,pool,controls)
            return false,'native static publication superseded'
        end
        previous={metadata=metadata,ok=ok,reason=reason,controls=controls}
        appliedArt[pool]=previous
        if not ok then
            print('ABYSS_NATIVE_ART rejected card_id='..tostring(definition.id)..' lua_sha256='..tostring(metadata.luaSha256)..' reason='..tostring(reason))
        end
    end
    if not previous.ok then return false,previous.reason end
    return NativeArtRuntime.publish(intent,true)
end
function M.writeNativeArt(box,definition,metadata,platform,fallback,identity)
    if box.alive==false or fallback.alive==false then NativeArtRuntime.release(box,fallback);return false end
    local pool=nativePool(box)
    if not pool or pool.alive==false then NativeArtRuntime.release(box,fallback,pool);return false end
    if not metadata or metadata.cardId~=definition.id then
        M.clearNativeArt(box,fallback);return false
    end
    if metadata.runtime==true then
        if appliedArt[pool]then
            local intent,clean=M.clearNativeArt(box,fallback)
            if not clean or not NativeArtRuntime.owns(intent)then return false end
        end
        return NativeArtRuntime.request(box,pool,metadata,platform,fallback,identity,writeNativeSlot)
    end
    return writeStaticNativeArt(box,pool,definition,metadata,platform,fallback)
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
-- Mirror native wrapping: Latin/digit runs break only at spaces, closing CJK
-- punctuation never starts a line and opening punctuation never ends one.
-- Treating every glyph as a free break point under-counted lines, so long
-- dynamic bodies (e.g. 格挡反击「（当前 N 点）」) passed fit and were clipped.
local closing={['，']=1,['。']=1,['、']=1,['；']=1,['：']=1,['）']=1,['」']=1,['！']=1,['？']=1,['》']=1,
    [',']=1,['.']=1,[')']=1,[';']=1,[':']=1,['!']=1,['?']=1}
local opening={['（']=1,['「']=1,['《']=1,['(']=1}
local function atoms(text)
    local out,glue={},false
    for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        local word=#ch==1 and ch:match('[%w%+%-%%]')
        local last=out[#out]
        if ch=='\n' or ch==' ' then out[#out+1]=ch;glue=false
        elseif type(last)=='table' and (glue or closing[ch] or word and last.word) then
            last.text=last.text..ch;last.word=word and last.word;glue=opening[ch]~=nil
        else out[#out+1]={text=ch,word=word};glue=opening[ch]~=nil end
    end
    return out
end
local function lines(text,width,font)
    local count,used=1,0
    for _,atom in ipairs(atoms(text:gsub('<[^>]+>',''))) do
        if atom=='\n' then count=count+1;used=0
        elseif atom==' ' then used=used+units(' ')*font
        else
            local advance=units(atom.text)*font
            if used>0 and used+advance>width then count=count+1;used=0 end
            while advance>width do count=count+1;advance=advance-width end
            used=used+advance
        end
    end
    return count
end
function M.fit(text,maximum,width,height,lineScale,advance)
    for font=maximum,Theme.font.minimum,-1 do
        if lines(text,width/(advance or 1),font)*font*(lineScale or 1.3)<=height then return font,true end
    end
    return Theme.font.minimum,false
end
function M.title(name,upgraded,upgrades)
    local suffix=upgraded and ('＋'..(upgrades and integer(upgrades) or '')) or ''
    local card=Theme.layout.card
    local width=card.title.width
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
    -- Fit plain glyphs first; native inline colour belongs only to the upgrade
    -- marker, even when the readable full name moves that marker to the type.
    if upgraded then
        local suffix='＋'..(upgrades and integer(upgrades) or '')
        local c=Theme.cardSkin.text.upgrade
        local ink=string.format('<color=#%02X%02X%02X>',c.r,c.g,c.b)..suffix..'</color>'
        if marker~='' then marker=ink else text=text:sub(1,#text-#suffix)..ink end
    end
    control.adaptiveFontSize=false
    control.text,control.fontSize=text,font
    if typeControl then typeControl.text=typeText..(marker~='' and ' '..marker or '') end
    return fits
end
local bodyFrames=setmetatable({},{__mode='k'})
local function bodyFrame(box,compact)
    if bodyFrames[box]==compact or not compact and bodyFrames[box]==nil then return end
    bodyFrames[box]=compact
    local card,S=Theme.layout.card,Theme.space
    local height=compact and card.longTextArt or card.art
    local y=card.size[2]/2-card.nameBand-height/2-S.border
    for _,name in ipairs({'artPlate','artWell','art','art_attack','art_skill','art_power','art_status','art_curse'})do
        local ok,part=pcall(box.GetChild,box,name)
        if not ok then part=nil end
        if part and part.alive~=false then
            part:SetAnchoredPosition(0,y)
            if name=='artPlate' or name=='artWell' then
                part:SetSizeDelta(card.size[1]-S.border*2,height)
            else part:SetLocalScale(height/card.art,height/card.art,1)end
        end
    end
    for _,kind in ipairs({'attack','skill','power'})do
        local part=box:GetChild('skin'):GetChild(kind)
        part:SetAnchoredPosition(0,y);part:SetLocalScale(1,height/card.art,1)
    end
    local typeY=card.size[2]/2-card.nameBand-height-card.typeLine/2-S.border
    for _,name in ipairs({'type','typeEdge','typeTag','tagEdge','tagBody'})do box:GetChild(name):SetAnchoredPosition(0,typeY)end
end
-- Body budget keeps the reviewed 1.3x line step; wrapping itself now follows
-- native kinsoku/Latin-run breaks (see lines above).
local bodyLine,bodyAdvance=1.3,1
function M.fitBody(text,box)
    return M.fit(text,Theme.font.card,box[1],box[2],bodyLine,bodyAdvance)
end
function M.writeBody(control,text,face)
    local card=Theme.layout.card
    local box=card.textBox
    local font,fits=M.fitBody(text,box)
    local compact=not fits
    if compact then box=card.longTextBox;font,fits=M.fitBody(text,box)end
    if control.SetSizeDelta then
        control:SetSizeDelta(box[1],box[2])
        control:SetAnchoredPosition(0,-card.size[2]/2+box[2]/2+(compact and Theme.space.xs or Theme.space.border))
    end
    if face then bodyFrame(face,compact)end
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
    if definition.originalV4 then return require('abyss_original_v4_display').faceText(definition,instance.upgraded,nil,
        {gold=Theme.color.goldBright,dim=Theme.color.textMuted})end
    local text=instance.upgraded and display.upgradeText or display.text
    if definition.id=='mind_blast' then return text or '' end
    local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
    return live and M.format(live,definition,{},Theme.color) or text or ''
end
local function originalReference(definition,upgraded,kind)
    local raw=definition.originalV4
    local version=raw[upgraded and 'upgrade' or 'base']
    local value,count=0,0
    for _,e in ipairs(version.effects)do
        if e.op=='when' or e.op=='damage_spent' then return end
        if e.op==kind then
            if kind=='damage' and e.target=='all' then return end
            value=value+e.n*(e.hits or 1);count=count+1
        end
    end
    return count>0 and value or nil
end
local function originalLive(value,reference)
    local direction=reference and valueDirection(reference,value) or 'same'
    local style=valueStyles[direction]
    if direction=='same' then return integer(value)end
    local c=Theme.color[style.colourKey]
    return '<color='..string.format('#%02X%02X%02X',c.r,c.g,c.b)..'>'..integer(value)..style.arrow..'</color>'
end
local function originalCombatText(definition,instance,preview,battle,target)
        local context
        if battle and battle.originalV4 and battle.originalV4.role=='RD' then
            context={snapshot=require('abyss_original_v4').snapshot(battle,battle.enemies[target])}
        end
        local text=require('abyss_original_v4_display').faceText(definition,instance.upgraded,context,
            {gold=Theme.color.goldBright,dim=Theme.color.textMuted})
        local damage,block=0,0
        for _,entry in ipairs(preview)do
            if entry.op=='block' then block=block+entry.low else damage=damage+(entry.actual or 0)end
        end
        local parts={}
        if damage>0 then parts[#parts+1]='扣血'..originalLive(damage,originalReference(definition,instance.upgraded,'damage'))end
        if block>0 then parts[#parts+1]='格挡'..originalLive(block,originalReference(definition,instance.upgraded,'block'))end
        if #parts>0 then text=text..table.concat(parts,'/')..'。'end
        return text
end
function M.combatText(display,definition,instance,preview,battle,target)
    if definition.originalV4 then return originalCombatText(definition,instance,preview,battle,target)end
    local text=instance.upgraded and display.upgradeText or display.text
    local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
    if live then text=M.format(live,definition,preview,Theme.color)end
    for _,entry in pairs(preview)do
        if entry.op=='damageEqualToBlock'then text=text..'（当前 '..integer(entry.low)..' 点）'end
    end
    return text
end
return M
