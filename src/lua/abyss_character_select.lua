-- Read-only loadout preview. Selection never owns a Run, map or RNG stream.
local M={}
local Admission=require('abyss_run_admission')
M.characters={'hutao','arlecchino','furina','raiden','traveler'}
M.elements={'ironclad','silent','defect','watcher'}
local names={hutao='胡桃',arlecchino='阿蕾奇诺',furina='芙宁娜',raiden='雷电将军',traveler='旅行者·荧'}
local elements={ironclad='岩',silent='风',defect='雷',watcher='草'}
local function contains(list,id)for _,value in ipairs(list)do if value==id then return true end end return false end
local profiles={dev='full-source',alpha='competition-two-act',['competition-candidate']='competition-two-act',
    production='competition-two-act',['competition-two-act']='competition-two-act',['full-source']='full-source'}
local function admissionProfile(profile)
    if profile==nil then return 'full-source' end
    return assert(profiles[profile],'unknown character admission profile')
end
function M.allowed(profile,id)
    if not profiles[profile] then return false end
    return (elements[id]~=nil or names[id]~=nil and id~='traveler') and Admission.allows(profiles[profile],id)
end
function M.options(id)
    if id=='ironclad' then return nil end -- preserve the production Geo loadout
    return {character=id,experimental=elements[id]~=nil}
end
-- 只为选角卡生成一句玩家可读效果；未覆盖的效果宁可留空，不编造。
function M.relicText(relic)
    if type(relic.description)=='string' and relic.description~='' then return relic.description end
    local effects=relic.effects or {}
    local e=effects[1]
    if #effects==1 and e.op=='heal' and relic.trigger=='combat_end' then return '每场战斗结束时，回复 '..e.value..' 点生命。' end
    return ''
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
    for _,card in ipairs(order)do local shown=display[card]
        deck[#deck+1]={id=card,name=shown.name,count=counts[card],type=defs[card].type,cost=shown.cost or defs[card].cost,text=shown.text or defs[card].text}end
    local relics={}
    for _,owned in ipairs(data.rules.player.startingRelics)do
        for _,relic in ipairs(data.relics.relics)do if relic.id==owned then
            relics[#relics+1]={id=owned,name=relic.name,text=M.relicText(relic)};break
        end end
    end
    local rules=data.rules.player
    return {id=id,name=names[id] or names.traveler..' · '..elements[id],
        maxHp=rules.maxHp,gold=rules.startingGold,relics=relics,deck=deck,
        deckSize=#data.cards.starter_deck.cards,profile=profile}
end
function M.new(source,presentation,profile)
    profile=admissionProfile(profile)
    local state={profile=profile}
    local function accepts(id)
        -- The visible choice is explicit even when Geo's Run options stay nil.
        return Admission.accepts(source,{campaignProfile=profile,character=id})
    end
    function state.allowsCharacter(_,id)
        return contains(M.characters,id) and Admission.allows(profile,id=='traveler' and 'ironclad' or id)
    end
    function state.allowsElement(_,id)return contains(M.elements,id) and Admission.allows(profile,id)end
    function state.allows(_,id)return id=='traveler' and state:allowsCharacter(id) or state:allowsElement(id) or state:allowsCharacter(id)end
    function state:canConfirm()
        local id=self.character=='traveler' and self.element or self.character
        return self.info~=nil and self.info.id==id and self:allowsCharacter(self.character)
            and (self.character~='traveler' or self:allowsElement(self.element)) and accepts(id)
    end
    function state:clear()
        self.character,self.element,self.info,self.deckOpen=nil,nil,nil,false
    end
    function state:select(id)
        if not contains(M.characters,id)then return false,'unknown_character' end
        if not self:allowsCharacter(id)then return false,'competition_character_unavailable'end
        if not accepts(id=='traveler' and (self.element or 'ironclad') or id)then
            return false,'competition_character_unavailable'
        end
        self.character=id
        if id=='traveler' then self.element=self.element or 'ironclad' end
        self.info=M.preview(source,presentation,id=='traveler' and self.element or id)
        return true
    end
    function state:selectElement(id)
        if self.character~='traveler' or not contains(M.elements,id)then return false,'element_unavailable'end
        if not self:allowsElement(id)then return false,'competition_character_unavailable'end
        if not accepts(id)then return false,'competition_character_unavailable'end
        self.element=id;self.info=M.preview(source,presentation,id);return true
    end
    return state
end
return M
