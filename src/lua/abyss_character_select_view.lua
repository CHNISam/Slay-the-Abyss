-- Native selection presentation. All numbers and deck entries come from loadouts.
local Theme=require('abyss_theme')
local Select=require('abyss_character_select')
local number=require('abyss_numbers').integer
local M={}
-- 选角只做一眼扫读（对标 STS 选角页）：牌组按 攻击→技能→能力→其它 排好直接列出，不提供筛选。
local typeOrder={attack=1,skill=2,power=3,status=4,curse=5}
local function renderStarterDeck(details,info)
    local cards={}
    for i,card in ipairs(info.deck)do cards[i]=card end
    table.sort(cards,function(a,b)
        local x,y=typeOrder[a.type] or 9,typeOrder[b.type] or 9
        if x~=y then return x<y end
        if a.count~=b.count then return a.count>b.count end
        return a.id<b.id
    end)
    details:GetChild('deckTitle').text='初始牌组 · '..number(info.deckSize)..' 张'
    local slots=6
    for i=1,slots do
        local card=cards[i]
        local text=card and card.name..'  × '..number(card.count) or ''
        -- 超出槽位时最后一格汇总剩余，绝不静默丢牌。
        if i==slots and #cards>slots then
            local rest=0;for k=slots,#cards do rest=rest+cards[k].count end
            text='其余 '..number(#cards-slots+1)..' 种 · '..number(rest)..' 张'
        end
        details:GetChild('card'..i).text=text
    end
end
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
    details:GetChild('stats').text='生命  '..number(info.maxHp)..' / '..number(info.maxHp)
    details:GetChild('gold').text='金币  '..number(info.gold)
    local relics,texts={},{}
    for _,r in ipairs(info.relics)do relics[#relics+1]=r.name;if r.text and r.text~='' then texts[#texts+1]=r.text end end
    details:GetChild('relic').text=#relics>0 and table.concat(relics,'、') or '无'
    details:GetChild('relicText').text=table.concat(texts,' ')
    renderStarterDeck(details,info)
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
