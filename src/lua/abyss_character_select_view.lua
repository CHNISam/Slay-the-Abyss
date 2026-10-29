-- Native selection presentation. All numbers and deck entries come from loadouts.
local Theme=require('abyss_theme')
local Select=require('abyss_character_select')
local number=require('abyss_numbers').integer
local M={}
local function selected(box,value)
    box:GetChild('selected'):SetVisible(value)
end
function M.render(panel,state,platform)
    local info=state.info
    panel:GetChild('hint').text=info and '查看初始信息，确认后开始冒险。' or '点击下方角色查看详情，再确认出发。'
    for i,id in ipairs(Select.characters)do
        local box=panel:GetChild(i==5 and 'traveler' or 'character'..i)
        local allowed=state:allowsCharacter(id)
        if box.visible~=allowed then box:SetVisible(allowed)end
        selected(box,state.character==id)
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
    local portrait=Theme.icon.characterPortraits[state.character]
    if platform.imageSource then details:GetChild('portrait'):SetImage(platform.imageSource,portrait.id)end
    details:GetChild('portraitNote').text=portrait.placeholder and info.name..' · 肖像待补' or info.name
end
return M
