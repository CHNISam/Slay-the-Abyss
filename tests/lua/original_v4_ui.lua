local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
package.path='tests/lua/?.lua;'..package.path
local F=require('support.game_ui_fixture')
local D=require('abyss_original_v4_display')
local Map=require('abyss_map')
local cursor={CursorDown='down',CursorUp='up',CursorEnter='enter',CursorExit='exit',CursorDrag='drag',CursorEndDrag='endDrag'}
local function colour(r,g,b,a)return {r=r,g=g,b=b,a=a}end
local function fixture()
    local canvas=F.control({children=F.Layout})
    local root=F.Viewport.apply(canvas,1280,720)
    local calls=0
    local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',color=colour,
        originalCharacters=true,prologue=false,cursorEvents=cursor,settle=function()calls=calls+1 end})
    root.ui=ui
    return ui,root,function()return calls end
end
local function path(root,key)
    for part in key:gmatch('[^/]+')do root=assert(root:GetChild(part),key)end
    return root
end
local total=0
for i,role in ipairs({'hutao','arlecchino','furina','raiden'})do
    local ui,root=fixture()
    assert(ui:start());assert(ui.characterOpen and not ui.run)
    assert(path(root,'characterPanel/character'..i..'/hit').click());assert(not ui.run);assert(ui:confirmCharacter())
    assert(ui.run.character==role and ui.mode=='map')
    assert(ui:openDeck());ui.deckUI:update()
    local grid=path(root,'deckPanel/grid')
    local slot=assert(grid.items[0]);local before=F.Combat.copy(ui.run)
    assert(slot:GetChild('hit').click())
    assert(ui.deckUI.detailPages and not grid.visible)
    local text={}
    for _=1,#ui.deckUI.detailPages do
        text[#text+1]=path(root,'deckPanel/details').text
        assert(path(root,'deckPanel/detailHit').click())
    end
    assert(table.concat(text):find('普攻',1,true))
    assert(ui.run.gold==before.gold and ui.run.hp==before.hp and #ui.run.deck==#before.deck)
    assert(path(root,'deckPanel/close/hit').click());assert(grid.visible and ui.deckUI.visible)
    assert(ui:closeDeck())
    total=total+1
end
-- All 600 faces retain their complete full rules in the shared paginated inspector.
local ui=fixture();assert(testStart(ui,'raiden'))
local frozen=require('abyss_original_v4_data')
local count=0
for _,raw in ipairs(frozen.cards)do for _,up in ipairs({false,true})do
    local definition={name=raw.name,originalV4=raw}
    assert(ui.deckUI:inspect(ui.run,definition,up))
    local full=table.concat(ui.deckUI.detailPages,''):gsub('\n','')
    assert(full==(D.describe(definition,up)..D.keywordDefinitions(definition,up)):gsub('\n',''),'full rules or keyword definitions were truncated: '..raw.id)
    for _,page in ipairs(ui.deckUI.detailPages)do
        local _,breaks=page:gsub('\n','')
        assert((breaks+4)*F.Theme.layout.nativeText.lineHeight<=F.Theme.layout.deckView.viewport[4],raw.id..' page overflows')
    end
    assert(ui.deckUI:close());count=count+1
end end
assert(count==600)
-- Fixture map positioning isolates the real shop/picker cursor adapter. No purchase
-- or upgrade command is issued by holding or closing the rules inspector.
local run,map=ui.run,ui.map
assert(Map.choose(map,'f1_l4'));assert(Map.choose(map,'f2_l5'))
assert(F.Nodes.enter(run,map,'f3_l5'))
ui:refresh();assert(ui.mode=='node')
assert(path(ui.root,'nodePanel/shopView/page').text=='') -- all seven offers are displayed together
for i=1,7 do assert(path(ui.root,'nodePanel/shopView/card'..i).visible) end
local hit=path(ui.root,'nodePanel/shopView/card1/hit')
local offer=run.nodeFlow.cards[1];local gold,n=run.gold,#run.deck
hit.listeners.down({touchId=4});ui.nodeUI:update(F.Theme.layout.statusInfo.delay)
assert(ui.deckUI.visible and ui.deckUI.detailOnly)
hit.listeners.up({touchId=4});assert(not hit.click({touchId=4}))
assert(not offer.sold and run.gold==gold and #run.deck==n)
assert(ui:closeDeck());assert(ui.mode=='node')
-- A drag cancels holding and its resulting click cannot buy the new shelf.
hit.listeners.down({touchId=5,GetUIPos=function()return 200,200 end})
hit.listeners.drag({touchId=5,GetUIPos=function()return 300,200 end})
ui.nodeUI:update(1);assert(not ui.deckUI.visible)
hit.listeners.endDrag({touchId=5});assert(not hit.click({touchId=5}))
assert(run.gold==gold and #run.deck==n)
-- The existing Traveler still starts through its own unchanged native data.
local native=fixture();assert(testStart(native,'traveler'));assert(not native.run.data.originalV4Role)
assert(native.run.data.rules.player.maxHp==F.Data.rules.player.maxHp)
-- Natural defeat and voluntary exit reuse the host's one-shot settlement path.
local failed,_,settlements=fixture();assert(testStart(failed,'raiden'))
assert(F.Nodes.enter(failed.run,failed.map,F.Nodes.available(failed.run,failed.map)[1].id))
local turn=0
while failed.run.phase=='combat' and turn<30 do
    assert(require('abyss_run').endTurn(failed.run));turn=turn+1
end
assert(failed.run.phase=='defeat');failed:refresh();assert(failed.mode=='defeat')
assert(failed:settle());assert(not failed:settle());assert(settlements()==1)
local leaving,_,exits=fixture();assert(testStart(leaving,'hutao'))
assert(leaving:openExit());assert(leaving:confirmExit());assert(not leaving:confirmExit());assert(exits()==1)
print('ORIGINAL_V4_UI_PASS '..total..' roles 600 full faces shop hold/drag traveler')
