-- Read-only loadout preview. Selection never owns a Run, map or RNG stream.
local M={}
M.characters={'hutao','arlecchino','furina','raiden','traveler'}
M.elements={'ironclad','silent','defect','watcher'}
local names={hutao='胡桃',arlecchino='阿蕾奇诺',furina='芙宁娜',raiden='雷电将军',traveler='旅行者·荧'}
local elements={ironclad='岩',silent='风',defect='雷',watcher='草'}
local function contains(list,id)for _,value in ipairs(list)do if value==id then return true end end return false end
function M.options(id)
    if id=='ironclad' then return nil end -- preserve the production Geo loadout
    return {character=id,experimental=elements[id]~=nil}
end
function M.preview(source,presentation,id)
    local data,profile=source,nil
    if names[id] and id~='traveler' then
        data,profile=require('abyss_original_v4_profiles').prepare(source,id)
    elseif elements[id] then
        if id~='ironclad' then data,profile=require('abyss_run_card_catalog').prepareSelected(source,id)end
    else return nil end
    local cards,defs,counts,order={},{},{},{}
    for _,card in ipairs(data.cards.cards)do defs[card.id]=card end
    for _,card in ipairs(data.cards.starter_deck.cards)do
        if not counts[card] then order[#order+1]=card;cards[#cards+1]=assert(defs[card],'missing starter definition')end
        counts[card]=(counts[card] or 0)+1
    end
    -- Use the existing Chinese display adapter for only the starter definitions.
    local display=require('abyss_character_presentation').prepare(presentation,{
        cards={cards=cards,sourcePools=data.cards.sourcePools},originalV4Role=data.originalV4Role,
        experimentalCharacter=data.experimentalCharacter,runCardCatalog=data.runCardCatalog})
    local deck={}
    for _,card in ipairs(order)do deck[#deck+1]={id=card,name=display[card].name,count=counts[card]}end
    local relics={}
    for _,owned in ipairs(data.rules.player.startingRelics)do
        for _,relic in ipairs(data.relics.relics)do if relic.id==owned then
            relics[#relics+1]={id=owned,name=relic.name};break
        end end
    end
    local rules=data.rules.player
    return {id=id,name=names[id] or names.traveler..' · '..elements[id],
        maxHp=rules.maxHp,gold=rules.startingGold,relics=relics,deck=deck,
        deckSize=#data.cards.starter_deck.cards,profile=profile}
end
function M.new(source,presentation)
    local state={}
    function state:clear()self.character,self.element,self.info=nil,nil,nil end
    function state:select(id)
        if not contains(M.characters,id)then return false,'unknown_character' end
        self.character=id
        if id=='traveler' then self.element=self.element or 'ironclad' end
        self.info=M.preview(source,presentation,id=='traveler' and self.element or id)
        return true
    end
    function state:selectElement(id)
        if self.character~='traveler' or not contains(M.elements,id)then return false,'element_unavailable'end
        self.element=id;self.info=M.preview(source,presentation,id);return true
    end
    return state
end
return M
