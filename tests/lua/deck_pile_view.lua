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

local function checkDetailAndScroll(host,root,grid)
    local first=grid.items[0];local hit=first:GetChild('hit')
    local uid=host.deckUI.bindings[first].uid
    local order={};for i,card in ipairs(host.deckUI.cards)do order[i]=card.uid end
    assert(hit.visible,'bound pile cards keep their read-only detail tap target')
    assert(hit.listeners.drag==nil and hit.listeners.endDrag==nil,'pile details must not claim native drag handlers')
    -- The native Grid owns movement. Verify our click dispatch boundary, not
    -- unavailable official scrolling physics, including a released drag.
    grid.scrollProgress=.35
    assert(not hit.click({dragging=true}),'pile drag must not open detail')
    assert(not hit.click({dragging=false,GetPressUIPos=function()return 100,100 end,
        GetUIPos=function()return 100,180 end}),'released pile drag must not open detail')
    assert(not host.deckUI.detailPages and grid.visible and grid.scrollProgress==.35)
    assert(hit.click(),'ordinary pile tap must open detail')
    assert(host.deckUI.detailPages and not grid.visible)
    assert(host.deckUI.cardDetail.instance.uid==uid and host.deckUI.cardDetail.combat,
        'pile detail must use the selected combat instance')
    assert(root:GetChild('deckPanel'):GetChild('close'):GetChild('hit').click())
    host.deckUI:update()
    assert(not host.deckUI.detailPages and grid.visible and grid.scrollProgress==.35,
        'detail return must preserve the native scroll offset')
    assert(host.deckUI.bindings[grid.items[0]].uid==uid,'detail return changed selected pile UID')
    assert(#host.deckUI.cards==#order,'detail return changed the pile view count')
    for i,card in ipairs(host.deckUI.cards)do assert(card.uid==order[i],'detail return reordered the pile view')end
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
        checkDetailAndScroll(host,root,grid)
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
    checkDetailAndScroll(host,root,grid)
    assert(same(before,host.run),'discard detail changed rules or RNG')
    for i,c in ipairs(cards) do assert(host.deckUI.cards[i].uid==c.uid) end
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
