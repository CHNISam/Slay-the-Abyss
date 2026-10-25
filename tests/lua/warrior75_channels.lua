package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local data=require('abyss_data')
local seeds=dofile('tests/fixtures/warrior75-shop-seeds.lua')
local Routes=dofile('tests/lua/support/map_routes.lua')
local function enterNext(run,map,kind)
    -- Navigation prefix only: these are node transaction fixtures, explicitly
    -- not a natural full run or per-item platform acceptance.
    if run.nodeFlow and run.nodeFlow.complete then run.nodeFlow=nil end -- discard completed navigation fixture only
    local path=Routes.to(map,function(node)return node.type==kind end)
    for i=1,#path-1 do assert(Map.choose(map,path[i]))end
    assert(Nodes.enter(run,map,path[#path]))
end
local n=0
-- Separate original rarity groups retain every transaction under the unchanged
-- per-fixture budget after the source six-column map/encounter integration.
local group=WARRIOR75_CHANNEL_RARITY or 'common'
local expected=WARRIOR75_CHANNEL_CARD and 1 or assert(({common=23,uncommon=36,rare=16})[group])
for _,definition in ipairs(data.cards.cards) do
    if definition.type~='status' and definition.type~='curse'
        and (not WARRIOR75_CHANNEL_CARD or definition.id==WARRIOR75_CHANNEL_CARD)
        and (definition.rarity==group or group=='common' and definition.rarity=='basic') then
        local seed=seeds[definition.id] and seeds[definition.id].seed or 1
        local run,map=Run.new(data,seed),Map.generate(data,seed)
        local instance
        if definition.rarity=='basic' then
            for _,c in ipairs(run.deck) do if c.cardId==definition.id then instance=c;break end end
        else
            enterNext(run,map,'shop')
            local offer=run.nodeFlow.cards[seeds[definition.id].slot]
            assert(offer.id==definition.id and not offer.unavailable,'real source shop did not offer '..definition.id)
            run.gold=offer.price -- exact-price fixture, payment is still public/atomic.
            assert(Nodes.buyCardSlot(run,offer.slot));assert(run.gold==0)
            instance=run.deck[#run.deck];assert(instance.cardId==definition.id)
            assert(not Nodes.buyCardSlot(run,offer.slot),'duplicate purchase')
            assert(Nodes.leaveShop(run))
        end
        assert(instance and not instance.upgraded)
        enterNext(run,map,'camp');assert(Nodes.upgrade(run,instance.uid));assert(instance.upgraded)
        enterNext(run,map,'boss')
        assert(run.phase=='combat')
        local found=false
        for _,pile in ipairs({run.combat.hand,run.combat.draw}) do
            for _,c in ipairs(pile) do if c.cardId==definition.id and c.upgraded then found=true end end
        end
        assert(found,'permanent upgrade lost on next battle: '..definition.id)
        n=n+1;print('ok channel '..n..' - '..definition.id..' public acquisition / camp / next battle')
    end
end
assert(n==expected)
print(group..': '..n..' public acquisition and upgrade transactions passed; fixture navigation/funding, not natural platform evidence.')
