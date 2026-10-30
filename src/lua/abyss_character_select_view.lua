-- Native selection presentation. All numbers and deck entries come from loadouts.
local Theme=require('abyss_theme')
local Select=require('abyss_character_select')
local number=require('abyss_numbers').integer
local M={}
local function selected(box,value)
    box:GetChild('selected'):SetVisible(value)
end
local function paintBust(box,entry,platform)
    if not entry or not platform.imageSource then return end
    local hit=box:GetChild('hit')
    for _,state in ipairs({'normal','hover','pressed','disabled'}) do
        local face=hit:GetChild(state)
        local bust=face and face:GetChild('bust')
        if bust then bust:SetImage(platform.imageSource,entry.id) end
    end
end
local function largeSlot(character,element)
    local slots=Theme.icon.heroSlots
    if character=='traveler' then return slots.large.traveler[element or 'ironclad'], slots.bust.traveler[element or 'ironclad'] end
    return slots.large[character], slots.bust[character]
end
function M.render(panel,state,platform)
    local info=state.info
    panel:GetChild('hint').text=state.notice or (info and '查看初始信息，确认后开始冒险。' or '点击下方角色查看详情，再确认出发。')
    for i,id in ipairs(Select.characters)do
        local box=panel:GetChild(i==5 and 'traveler' or 'character'..i)
        local allowed=state:allowsCharacter(id)
        if box.visible~=allowed then box:SetVisible(allowed)end
        selected(box,state.character==id)
        local _,bust=largeSlot(id,id=='traveler' and (state.element or 'ironclad') or nil)
        paintBust(box,bust,platform)
    end
    local traveler=state.character=='traveler'
    -- Theme layers are prebuilt per character/element; only visibility changes.
    local theme=traveler and state.element or state.character
    for _,layer in ipairs({'themes','accents'})do
        local group=panel:GetChild(layer)
        for _,id in ipairs(Select.characters)do if id~='traveler' then group:GetChild(id):SetVisible(id==theme)end end
        for _,id in ipairs(Select.elements)do group:GetChild(id):SetVisible(id==theme)end
    end
    panel:GetChild('elements'):SetVisible(traveler)
    for i,id in ipairs(Select.elements)do
        local box=panel:GetChild('elements'):GetChild('element'..i)
        local allowed=state:allowsElement(id)
        if box.visible~=allowed then box:SetVisible(allowed)end
        selected(box,state.element==id)
        paintBust(box,Theme.icon.heroSlots.bust.traveler[id],platform)
    end
    local details=panel:GetChild('details');details:SetVisible(info~=nil)
    local confirm=panel:GetChild('confirm'):GetChild('hit')
    confirm.interactable,confirm.raycastTarget=state:canConfirm(),state:canConfirm()
    if not info then return end
    details:GetChild('name').text=info.name
    details:GetChild('stats').text='初始生命 '..number(info.maxHp)..' / '..number(info.maxHp)..'    金币 '..number(info.gold)
    local relics={};for _,r in ipairs(info.relics)do relics[#relics+1]=r.name end
    details:GetChild('relic').text='初始遗物：'..table.concat(relics,'、')
    details:GetChild('deckTitle').text='初始牌组 · '..number(info.deckSize)..' 张'
    for i=1,6 do
        local card=info.deck[i]
        details:GetChild('card'..i).text=card and card.name..' × '..number(card.count) or ''
    end
    local large=largeSlot(state.character,state.element)
    local portraits=details:GetChild('portraits')
    local key=state.character=='traveler' and ('traveler_'..(state.element or 'ironclad')) or state.character
    for _,id in ipairs(Select.characters)do
        if id=='traveler' then
            for _,element in ipairs(Select.elements)do
                portraits:GetChild('traveler_'..element):SetVisible(key=='traveler_'..element)
            end
        else portraits:GetChild(id):SetVisible(id==key) end
    end
    if platform.imageSource and large then portraits:GetChild(key):SetImage(platform.imageSource,large.id) end
    local note=info.name
    local native=platform.portraits and platform.portraits.status and platform.portraits:status().selection
    if key=='traveler_ironclad' and native then portraits:GetChild(key):SetVisible(false)end
    if (not large or large.status=='placeholder') and not native then note=note..' · 肖像待补' end
    if large and large.playable==false then note=note..' · 非本次正式角色' end
    details:GetChild('portraitNote').text=note
end
return M
