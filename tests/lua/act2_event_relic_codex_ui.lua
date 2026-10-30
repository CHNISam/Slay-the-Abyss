-- Generated native-control mock, not device/native acceptance.
local H=dofile('tests/helpers/act2_event_relics.lua')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local eq,same,test=H.eq,H.same,H.test
local function fixture()
 local ui,root=F.fixture();assert(F.start(ui));assert(H.Run.obtainRelic(ui.run,"Nilry's Codex"))
 assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id));local r=ui.run
 assert(H.Run.endTurn(r));ui:refresh();local p=assert(r.combat.pendingChoice);eq(p.op,'codex')
 local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
 grid:flush();ui:update(0);grid:flush()
 return ui,r,p,panel,grid
end
local function drain(ui)
 for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end;ui:refresh()
end
test('Codex native controls show3 optional normally-costed cards and true Skip without renderer RNG',function()
 local ui,r,p,panel,grid=fixture();eq(grid.itemCount,3);assert(ui.deckUI.visible)
 assert(panel:GetChild('title').text:find('洗入抽牌堆',1,true));assert(not panel:GetChild('title').text:find('费用为0',1,true))
 local close=panel:GetChild('close');assert(close.visible and close:GetChild('hit').interactable)
 eq(close:GetChild('hit'):GetChild('normal'):GetChild('label').text,'跳过')
 local rng=H.R.snapshot(r.combat.cardRandomRng);for _=1,3 do ui:update(0)end;same(H.R.snapshot(r.combat.cardRandomRng),rng)
 close:GetChild('hit').click();drain(ui);eq(r.combat.pendingChoice,nil);eq(r.combat.turn,2);assert(not ui.deckUI.visible)
 assert(not close:GetChild('hit').click());same(H.R.snapshot(r.combat.cardRandomRng),rng)
end)
test('Codex displayed card click executes one real pick and rejects stale selection after continuation',function()
 local ui,r,p,_,grid=fixture();local id=p.cards[1].cardId;local uid=r.combat.nextUid
 local stale=grid.items[0]:GetChild('hit').click;stale();drain(ui);eq(r.combat.pendingChoice,nil);eq(r.combat.turn,2)
 local card;for _,pile in ipairs({r.combat.hand,r.combat.draw,r.combat.discard})do for _,c in ipairs(pile)do if c.uid==uid then card=c end end end
 assert(card);eq(card.cardId,id);eq(card.costForTurn,nil);assert(not stale())
end)
H.finish('ACT2_EVENT_RELIC_CODEX_UI')
