local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map=require('abyss_run'),require('abyss_map')
local count,failures=0,{}
local function test(name,fn)local ok,why=pcall(fn);if ok then count=count+1;print('ok discard UI '..count..' - '..name)
else failures[#failures+1]=name..': '..tostring(why);print('not ok - '..failures[#failures])end end
local function equal(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function hit(root,panel,name)return assert(root:GetChild(panel):GetChild(name)):GetChild('hit')end
local function setup(cursor)
    local h,r=F.fixture(nil,nil,nil,cursor);assert(testStart(h))
    for _,id in ipairs({'fire_potion','block_potion','regen_potion'})do assert(Run.obtainPotion(h.run,id))end
    h.battleUI.run=h.run;h.nodeUI.run=h.run
    h:refresh();return h,r
end
local function click(r,p,n)return assert(hit(r,p,n).click,'unbound '..p..'/'..n)()end
local function open(r)assert(click(r,'potionEntry','open'));assert(r:GetChild('potionPanel').visible)end
local function counter(r,amount)
    local entry=hit(r,'potionEntry','open')
    for _,state in ipairs({'normal','hover','pressed','disabled'})do
        equal(entry:GetChild(state):GetChild('label').text,'药水 '..amount..'/3')
    end
end

test('reward claim refreshes every counter state while Proceed preserves the pending bottle and rejects old input',function()
    for _,action in ipairs({'claimPotion','continue'})do
        local h,r=F.fixture();assert(testStart(h))
        h.run=Run.new(F.Data,42);h.battleUI.run=h.run;h.nodeUI.run=h.run
        assert(Run.startCombat(h.run,'cultist_solo'))
        for _,enemy in ipairs(h.run.combat.enemies)do enemy.hp=0 end
        assert(Run.finishCombat(h.run));assert(h.run.rewards.potion);h:refresh()
        local offered=h.run.rewards.potion
        counter(r,0)
        local panel=r:GetChild('battlePanel')
        equal(panel:GetChild('skipPotion'),nil)
        local control=panel:GetChild(action)
        control.listeners.click() -- Proceed is an event callback, not a Run command return value.
        local amount=action=='claimPotion' and 1 or 0
        equal(h.run.phase,action=='claimPotion' and 'reward' or 'map')
        equal(h.mode,action=='claimPotion' and 'battle' or 'map');equal(Run.potionCount(h.run),amount)
        counter(r,amount)
        assert(not control.listeners.click());equal(Run.potionCount(h.run),amount);counter(r,amount)
        if action=='continue' then
            assert(h.run.pendingCombatRewards and not offered.resolved)
            r:GetChild('combatRewards'):GetChild('hit').click()
            equal(h.run.phase,'reward');equal(Run.potionCount(h.run),0);counter(r,0)
            assert(panel:GetChild('claimPotion').listeners.click())
            equal(Run.potionCount(h.run),1);counter(r,1)
            assert(not panel:GetChild('claimPotion').listeners.click());counter(r,1)
        end
    end
end)

test('real generated counter opens three physical slots; selection and confirmation discard only the chosen bottle',function()
    local h,r=setup();local hp,gold,seed=h.run.hp,h.run.gold,h.run.seed
    open(r);equal(h.mapUI.navigationEnabled,false);equal(click(r,'potionPanel','discard'),false)
    assert(click(r,'potionPanel','slot2'));assert(click(r,'potionPanel','discard'))
    equal(h.run.potions[1],'fire_potion');equal(h.run.potions[2],nil);equal(h.run.potions[3],'regen_potion')
    equal(h.run.hp,hp);equal(h.run.gold,gold);equal(h.run.seed,seed)
    equal(click(r,'potionPanel','discard'),false);assert(click(r,'potionPanel','cancel'))
    assert(h.mapUI.navigationEnabled and not r:GetChild('potionPanel').visible)
end)

test('full reward can discard an old bottle then claim the offered bottle in its exact vacancy',function()
    local h,r=setup();h.run=Run.new(F.Data,42);h.battleUI.run=h.run;h.nodeUI.run=h.run
    for _,id in ipairs({'fire_potion','block_potion','regen_potion'})do assert(Run.obtainPotion(h.run,id))end
    assert(Run.startCombat(h.run,'cultist_solo'))
    for _,enemy in ipairs(h.run.combat.enemies)do enemy.hp=0 end
    -- Complete33-potion source vector seed42 selects Colorless Potion.
    assert(Run.finishCombat(h.run));h:refresh();equal(h.run.rewards.potion.id,'colorless_potion')
    counter(r,3)
    local claim=r:GetChild('battlePanel'):GetChild('claimPotion')
    local gold,seed,nextUid,offered=h.run.gold,h.run.seed,h.run.nextDeckUid,h.run.rewards.potion
    equal(claim.interactable,true);equal(claim.listeners.click(),false);counter(r,3)
    equal(h.run.gold,gold);equal(h.run.seed,seed);equal(h.run.nextDeckUid,nextUid);equal(h.run.rewards.potion,offered)
    assert(not h.run.rewards.potion.resolved)
    open(r);assert(click(r,'potionPanel','slot2'));assert(click(r,'potionPanel','discard'));assert(click(r,'potionPanel','cancel'))
    counter(r,2)
    assert(r:GetChild('battlePanel'):GetChild('claimPotion').listeners.click())
    equal(h.run.potions[1],'fire_potion');equal(h.run.potions[2],'colorless_potion');equal(h.run.potions[3],'regen_potion')
    equal(h.run.phase,'reward');counter(r,3)
end)

test('shop counter allows replacing a full belt without bypassing purchase price or stock',function()
    local h,r=setup()
    local path=dofile('tests/lua/support/map_routes.lua').to(h.map,function(node)return node.type=='shop'end)
    for i=1,#path-1 do assert(Map.choose(h.map,path[i]))end
    assert(F.Nodes.enter(h.run,h.map,path[#path]))
    h.run.gold=1000;h:refresh()
    local offer
    for _,p in ipairs(h.run.nodeFlow.potions)do if not p.unavailable then offer=p;break end end
    assert(offer);local gold=h.run.gold
    local tile=r:GetChild('nodePanel'):GetChild('shopView'):GetChild('potion'..offer.slot)
    equal(tile:GetChild('hit').click(),false);equal(h.run.gold,gold);counter(r,3)
    equal(h.run.potions[2],'block_potion');assert(not offer.sold)
    open(r)
    assert(click(r,'potionPanel','slot2'));assert(click(r,'potionPanel','discard'));assert(click(r,'potionPanel','cancel'))
    counter(r,2)
    -- A product click previews; neither preview nor cancelling replaces the bottle.
    assert(tile:GetChild('hit').click());equal(h.run.potions[2],nil);equal(h.run.gold,gold);assert(not offer.sold)
    local cancelled=h.nodeUI.actions.confirm.handler
    assert(click(r,'nodePanel','back'));equal(cancelled(),false)
    equal(h.run.potions[2],nil);equal(h.run.gold,gold);assert(not offer.sold);counter(r,2)
    assert(tile:GetChild('hit').click());local committed=h.nodeUI.actions.confirm.handler
    assert(click(r,'nodePanel','confirm'));equal(h.run.potions[2],offer.id);equal(h.run.gold,gold-offer.price)
    assert(h.run.nodeFlow.potions[offer.slot].sold);counter(r,3)
    equal(committed(),false);equal(tile:GetChild('hit').click(),false)
    equal(h.run.gold,gold-offer.price);equal(h.run.potions[1],'fire_potion');equal(h.run.potions[3],'regen_potion');counter(r,3)
end)

test('stale selected-slot confirmation refuses a replacement bottle and a new run with the same slot',function()
    local h,r=setup();open(r);assert(click(r,'potionPanel','slot2'))
    h.run.potions[2]='energy_potion';equal(click(r,'potionPanel','discard'),false);equal(h.run.potions[2],'energy_potion')
    assert(click(r,'potionPanel','slot2'));local old=h.run
    h.run=Run.new(F.Data,42);assert(Run.obtainPotion(h.run,'block_potion'))
    equal(click(r,'potionPanel','discard'),false);equal(h.run.potions[1],'block_potion');equal(old.potions[2],'energy_potion')
end)

test('closing reopening resize and terminal phases invalidate old confirmation pointers',function()
    local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorEndDrag='endDrag'}
    local function tap(box,touch)
        local e={touchId=touch};if box.listeners.down then box.listeners.down(e);box.listeners.up(e)end
        return box.click(e)
    end
    for _,change in ipairs({'reopen','resize','victory','defeat'})do
        local h,r=setup(cursor);assert(tap(hit(r,'potionEntry','open'),1));assert(tap(hit(r,'potionPanel','slot2'),2))
        local discard=hit(r,'potionPanel','discard');discard.listeners.down({touchId=3})
        if change=='reopen' then assert(h:closePotions());assert(h:openPotions())
        elseif change=='resize'then h:resize(1600,900)
        else h.run.phase=change;h:refresh()end
        discard.listeners.up({touchId=3});equal(discard.click({touchId=3}),false);equal(h.run.potions[2],'block_potion')
    end
end)

test('modal interrupts held direct-use pointers and preserves fresh short-tap use afterwards',function()
    local H=dofile('tests/lua/support/potion_gesture_fixture.lua')
    local h,u,p,e,t,d,deck,r,emit,potionTap=H.setup()
    emit('potion1','down',7);assert(h:openPotions());assert(h:closePotions())
    emit('potion1','up',7);emit('potion1','click',7);equal(h.run.potions[1],'energy_potion')
    potionTap(8);d();equal(h.run.potions[1],nil);equal(h.run.combat.energy,5)
end)

test('phase changes invalidate the old selection while a fresh enemy-phase selection may discard',function()
    local h,r=setup();open(r);assert(click(r,'potionPanel','slot2'))
    assert(Run.startCombat(h.run,'cultist_solo'))
    equal(click(r,'potionPanel','discard'),false);equal(h.run.potions[2],'block_potion')
    h.run.combat.phase='enemy';h:refresh()
    assert(click(r,'potionPanel','slot2'));assert(click(r,'potionPanel','discard'));equal(h.run.potions[2],nil)
end)

test('direct discard and same-ID refill cannot revive a pre-discard use pointer without a render',function()
    local H=dofile('tests/lua/support/potion_gesture_fixture.lua')
    local h,u,p,e,t,d,deck,r,emit=H.setup()
    emit('potion1','down',7);assert(Run.discardPotion(h.run,1));assert(Run.obtainPotion(h.run,'energy_potion'))
    emit('potion1','up',7);emit('potion1','click',7)
    equal(h.run.potions[1],'energy_potion');equal(h.run.combat.energy,3)
end)

test('selected bottle and held confirmation both reject a real same-ID discard and refill',function()
    local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorEndDrag='endDrag'}
    for _,pointer in ipairs({false,true})do
        local h,r=setup(pointer and cursor or nil);open(r);assert(click(r,'potionPanel','slot2'))
        local discard=hit(r,'potionPanel','discard')
        if pointer then discard.listeners.down({touchId=9})end
        assert(Run.discardPotion(h.run,2));local ok,slot=Run.obtainPotion(h.run,'block_potion');assert(ok);equal(slot,2)
        if pointer then discard.listeners.up({touchId=9})end
        equal(discard.click({touchId=9}),false);equal(h.run.potions[2],'block_potion')
    end
end)

if #failures>0 then error(table.concat(failures,'\n'))end
print('LUA_GAME_UI_POTION_DISCARD_PASS '..count)
