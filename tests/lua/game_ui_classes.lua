package.path="tests/lua/?.lua;"..package.path
local F=require('support.game_ui_fixture')
local Run=require('abyss_run')
local Select=require('abyss_character_select')
local cursor={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='enddrag',CursorDrag='drag'}
local function hit(root,path)
    for part in path:gmatch('[^/]+')do root=assert(root:GetChild(part),part)end
    return root:GetChild('hit') or root
end
local n=0
local function test(name,fn)fn();n=n+1;print('ok formal selection '..n..' - '..name)end
local function tap(c,id)c.listeners.down({touchId=id});c.listeners.up({touchId=id});return c.click({touchId=id})end
for _,id in ipairs({'hutao','arlecchino','furina','raiden','ironclad','silent','defect','watcher'})do
 test(id..' previews its actual loadout and creates one Run only on final confirm',function()
    local ui,root=F.fixture();local before=F.Combat.copy(F.Data)
    local real,calls=Run.new,0
    Run.new=function(...)calls=calls+1;return real(...)end
    assert(ui:start());assert(not ui.run and not ui.map and calls==0)
    assert(not ui:confirmCharacter())
    local traveler=id=='ironclad' or id=='silent' or id=='defect' or id=='watcher'
    assert(ui:selectCharacter(traveler and 'traveler' or id))
    if traveler then assert(ui:selectElement(id))end
    local info=ui.characterSelection.info
    assert(info and info.id==id and not ui.run and not ui.map and calls==0 and ui.seed==1)
    local panel=root:GetChild('characterPanel')
    assert(panel:GetChild('details'):GetChild('name').text==info.name)
    assert(panel:GetChild('confirm'):GetChild('hit').interactable)
    for i,value in ipairs(Select.characters)do
        assert(panel:GetChild(i==5 and 'traveler' or 'character'..i):GetChild('selected').visible==(value==(traveler and 'traveler' or id)))
    end
    assert(hit(root,'characterPanel/confirm').click());assert(calls==1 and not ui.characterOpen and ui.mode=='map')
    assert(not hit(root,'characterPanel/confirm').click() and not ui:confirmCharacter() and calls==1)
    Run.new=real
    local run=ui.run
    assert(run.maxHp==info.maxHp and run.hp==info.maxHp and run.gold==info.gold and #run.deck==info.deckSize)
    assert((run.character or 'ironclad')==id)
    local counts={};for _,card in ipairs(run.deck)do counts[card.cardId]=(counts[card.cardId] or 0)+1 end
    for _,card in ipairs(info.deck)do assert(counts[card.id]==card.count and card.name:find('[\128-\255]'))end
    for i,relic in ipairs(info.relics)do assert(run.relics[i]==relic.id)end
    assert(F.Data.rules.player.maxHp==before.rules.player.maxHp and #F.Data.cards.cards==#before.cards.cards)
    assert(ui:openDeck());ui.deckUI:update();assert(ui:closeDeck())
    assert(Run.startCombat(run,'cultist_solo'));ui:refresh();assert(ui.mode=='battle' and #run.combat.hand>0)
    for i=1,#run.combat.hand do
        local card=root:GetChild('battlePanel'):GetChild('card'..i)
        assert(card:GetChild('name').text~='' and card:GetChild('label').text~='')
    end
 end)
end
test('cancel clears choice, consumes no seed and retires old menu and confirm presses',function()
 local ui,root=F.fixture(nil,nil,nil,cursor);local start=hit(root,'menuPanel/start')
 start.listeners.down({touchId=1});assert(ui:start());assert(not ui:confirmCharacter())
 assert(ui:selectCharacter('hutao'));local confirm=hit(root,'characterPanel/confirm')
 confirm.listeners.down({touchId=2});assert(ui:closeCharacters());assert(ui.characterSelection.info==nil)
 start.listeners.up({touchId=1});assert(not start.click({touchId=1}))
 assert(ui:start());confirm.listeners.up({touchId=2});assert(not confirm.click({touchId=2}))
 assert(not ui.run and ui.seed==1 and not ui:confirmCharacter());assert(ui:closeCharacters())
end)
test('switch, resize, foreign pointer and drag cannot reuse final confirmation',function()
 local ui,root=F.fixture(nil,nil,nil,cursor);assert(ui:start());assert(ui:selectCharacter('hutao'))
 local confirm=hit(root,'characterPanel/confirm')
 confirm.listeners.down({touchId=1});assert(ui:selectCharacter('traveler'));assert(ui:selectElement('silent'))
 confirm.listeners.up({touchId=1});assert(not confirm.click({touchId=1}) and not ui.run)
 confirm.listeners.down({touchId=2});ui:resize(1600,900);confirm.listeners.up({touchId=2});assert(not confirm.click({touchId=2}))
 confirm.listeners.down({touchId=3});confirm.listeners.up({touchId=4});assert(not confirm.click({touchId=4}))
 confirm.listeners.up({touchId=3});confirm.listeners.enddrag({touchId=3});assert(not confirm.click({touchId=3}))
 assert(tap(confirm,5));assert(ui.run.character=='silent');assert(not confirm.click({touchId=5}))
end)
test('class modal blocks underlying start, speed, exit and settlement and rejects invalid choices',function()
 local ui=F.fixture();assert(ui:start());assert(not ui:openExit() and not ui:start() and not ui:settle() and not ui:setFastMode(true))
 assert(not ui:selectCharacter('unknown') and not ui:selectElement('silent') and not ui:confirmCharacter())
 assert(ui:selectCharacter('traveler'));assert(ui.characterSelection.element=='ironclad')
 assert(ui:selectElement('watcher'));assert(ui:selectCharacter('furina'));assert(not ui:selectElement('defect'))
 assert(ui:selectCharacter('traveler'));assert(ui.characterSelection.element=='watcher' and not ui.run)
end)
test('all five native role buttons and four native element buttons only select',function()
 local ui,root=F.fixture();assert(ui:start())
 for i,id in ipairs(Select.characters)do
  assert(hit(root,'characterPanel/'..(i==5 and 'traveler' or 'character'..i)).click())
  assert(ui.characterSelection.character==id and not ui.run and not ui.map and ui.seed==1)
 end
 for i,id in ipairs(Select.elements)do
  assert(hit(root,'characterPanel/elements/element'..i).click())
  assert(ui.characterSelection.element==id and ui.characterSelection.info.id==id and not ui.run)
 end
 assert(ui:closeCharacters());assert(not ui.characterSelection.info and not ui.run)
end)
print('GAME_UI_CLASSES_PASS '..n)
