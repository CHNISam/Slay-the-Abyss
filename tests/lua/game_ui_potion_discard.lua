package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map=require('abyss_run'),require('abyss_map')
local count,failures=0,{}
local function test(name,fn)local ok,why=pcall(fn);if ok then count=count+1;print('ok discard UI '..count..' - '..name)
else failures[#failures+1]=name..': '..tostring(why);print('not ok - '..failures[#failures])end end
local function equal(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function hit(root,panel,name)return assert(root:GetChild(panel):GetChild(name)):GetChild('hit')end
local function setup(cursor)
    local h,r=F.fixture(nil,nil,nil,cursor);assert(h:start())
    for _,id in ipairs({'fire_potion','block_potion','regen_potion'})do assert(Run.obtainPotion(h.run,id))end
    h.battleUI.run=h.run;h.nodeUI.run=h.run
    h:refresh();return h,r
end
local function click(r,p,n)return assert(hit(r,p,n).click,'unbound '..p..'/'..n)()end
local function open(r)assert(click(r,'potionEntry','open'));assert(r:GetChild('potionPanel').visible)end

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
    assert(Run.finishCombat(h.run));h:refresh();equal(h.run.rewards.potion.id,'dexterity_potion')
    open(r);assert(click(r,'potionPanel','slot2'));assert(click(r,'potionPanel','discard'));assert(click(r,'potionPanel','cancel'))
    assert(r:GetChild('battlePanel'):GetChild('claimPotion').listeners.click())
    equal(h.run.potions[1],'fire_potion');equal(h.run.potions[2],'dexterity_potion');equal(h.run.potions[3],'regen_potion')
end)

test('shop counter allows replacing a full belt without bypassing purchase price or stock',function()
    local h,r=setup();local found
    while not found do
        local choices=Map.available(h.map)
        for _,node in ipairs(choices)do if node.type=='shop' then assert(F.Nodes.enter(h.run,h.map,node.id));found=true;break end end
        if not found then assert(Map.choose(h.map,choices[1].id))end
    end
    h.run.gold=1000;h:refresh();open(r)
    assert(click(r,'potionPanel','slot2'));assert(click(r,'potionPanel','discard'));assert(click(r,'potionPanel','cancel'))
    local offer
    for _,p in ipairs(h.run.nodeFlow.potions)do if not p.unavailable then offer=p;break end end
    assert(offer);local gold=h.run.gold
    local tile=r:GetChild('nodePanel'):GetChild('shopView'):GetChild('potion'..offer.slot)
    assert(tile:GetChild('hit').click());equal(h.run.potions[2],offer.id);equal(h.run.gold,gold-offer.price)
    assert(h.run.nodeFlow.potions[offer.slot].sold)
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
