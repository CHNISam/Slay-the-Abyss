local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Combat=H.F.Combat
local count=0
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function test(name,fn) fn();count=count+1;print('ok pile view '..count..' - '..name) end
local function instance(uid,id,upgraded) return {uid=uid,cardId=id,upgraded=upgraded==true} end
local function open(host,root,kind)
    assert(host.deckUI:openPile(host.run,kind));host.deckUI:update()
    return root:GetChild('deckPanel'):GetChild('grid')
end
local function scrollAndInspect(host,root,grid)
    local hit=grid.items[0]:GetChild('hit')
    assert(hit.visible,'read-only pile card must allow detail inspection')
    assert(not hit.listeners.drag and not hit.listeners.endDrag,'pile details must leave native scrolling unclaimed')
    grid.scrollProgress=.4
    assert(not hit.click({touchId=11,dragging=true}),'dragging must not inspect a pile card')
    assert(not hit.click({touchId=11,dragging=false,GetPressUIPos=function()return 0,0 end,
        GetUIPos=function()return 0,100 end}),'released scroll must not inspect a pile card')
    assert(grid.visible and not host.deckUI.cardDetail and grid.scrollProgress==.4)
    assert(hit.click({touchId=12,dragging=false}),'ordinary tap must inspect a pile card')
    assert(root:GetChild('deckPanel'):GetChild('details').visible and not grid.visible)
    assert(not host.deckUI.choiceToken and not host.deckUI.onPick,'pile inspection cannot dispatch a choice')
    assert(host.deckUI:back());host.deckUI:update()
    assert(grid.visible and grid.scrollProgress==.4,'returning from pile detail must retain native scroll')
end

test('draw and exhaust views sort copies by source rarity and status last without revealing draw order',function()
    for _,kind in ipairs({'draw','exhaust'}) do
        local host,ui,panel,event,tap,drain,close,root=H.setup()
        local b=host.run.combat
        b[kind]={instance(91,'burn'),instance(92,'anger'),instance(93,'bash'),instance(94,'defend'),instance(95,'anger')}
        local before=Combat.copy(host.run)
        local grid=open(host,root,kind)
        local expected={93,94,95,92,91}
        assert(grid.itemCount==5)
        for i,uid in ipairs(expected) do assert(host.deckUI.cards[i].uid==uid) end
        assert(root:GetChild('deckPanel'):GetChild('title').text:find(kind=='draw' and '抽牌堆' or '消耗堆',1,true))
        scrollAndInspect(host,root,grid)
        assert(same(before,host.run),'opening changed rules or RNG')
        host.deckUI:close();assert(same(before,host.run))
    end
end)

test('discard view keeps group order and Frozen Eye permits the original reversed draw copy',function()
    local host,ui,panel,event,tap,drain,close,root=H.setup()
    local cards={instance(71,'anger'),instance(72,'bash'),instance(73,'defend')}
    host.run.combat.discard=Combat.copy(cards)
    local before=Combat.copy(host.run)
    local grid=open(host,root,'discard')
    for i,c in ipairs(cards) do assert(host.deckUI.cards[i].uid==c.uid) end
    scrollAndInspect(host,root,grid);assert(same(before,host.run),'discard inspection changed rules or RNG')
    host.deckUI:close();host.run.relics[#host.run.relics+1]='frozen_eye'
    host.run.combat.draw=Combat.copy(cards)
    open(host,root,'draw')
    for i=1,#cards do assert(host.deckUI.cards[i].uid==cards[#cards-i+1].uid) end
    host.deckUI:close()
end)

test('combat pile faces retain temporary cost and growth while permanent deck remains unchanged',function()
    local host,ui,panel,event,tap,drain,close,root=H.setup()
    local card=instance(98,'rampage');card.costForTurn=0;card.damageBonus=17
    host.run.combat.discard={card}
    local before=Combat.copy(host.run)
    local face=open(host,root,'discard').items[0]:GetChild('face')
    assert(face:GetChild('cost').text=='0')
    assert(face:GetChild('label').text:find('25',1,true),'combat growth missing from pile face')
    assert(same(before,host.run),'combat preview changed state')
    host.deckUI:close();assert(host.deckUI:open(host.run));host.deckUI:update()
    assert(not host.deckUI.pileKind,'permanent deck retained combat context')
    host.deckUI:close()
end)

test('empty piles open and invalid contexts cannot replace a visible snapshot',function()
    local host,ui,panel,event,tap,drain,close,root=H.setup()
    host.run.combat.exhaust={}
    assert(open(host,root,'exhaust').itemCount==0)
    assert(not host.deckUI:openPile(host.run,'discard'))
    host.deckUI:close()
    assert(not host.deckUI:openPile(host.run,'hand'))
    host.run.combat.phase='enemy';assert(not host.deckUI:openPile(host.run,'draw'))
    host.run.phase='map';assert(not host.deckUI:openPile(host.run,'draw'))
end)
print('LUA_DECK_PILE_VIEW_PASS '..count)
