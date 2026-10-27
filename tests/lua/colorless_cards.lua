package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local data=require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function battle(id,upgraded)
    local deck={{cardId=id,upgraded=upgraded}}
    for _=1,15 do deck[#deck+1]='defend'end
    local s=C.new(data,{deck=deck,enemies={'jaw_worm','jaw_worm'},seed=42})
    for _,p in ipairs({s.draw,s.hand,s.discard})do for i=#p,1,-1 do if p[i].cardId==id then s.testCard=table.remove(p,i)end end end
    s.hand[#s.hand+1]=assert(s.testCard);s.energy=20;s.player.hp=40
    for _,e in ipairs(s.enemies)do e.hp=500;e.maxHp=500;e.block=0 end
    return s,s.testCard
end
local simple={
    {'swift_strike',7,10},{'flash_of_steel',3,6},{'dramatic_entrance',8,12},
    {'good_instincts',6,9,'block'},{'finesse',2,4,'block'},
    {'bandage_up',4,6,'heal'}, {'panacea',1,2,'artifact'},
    {'blind',2,2,'weak'},{'trip',2,2,'vulnerable'},
    {'master_of_strategy',3,4,'draw'},
}
for _,v in ipairs(simple)do for n=1,2 do
    local s,c=battle(v[1],n==2);local before=#s.hand
    assert(C.play(s,c.uid,1));local kind=v[4]
    if kind=='block'then eq(s.player.block,v[n+1])
    elseif kind=='heal'then eq(s.player.hp,40+v[n+1])
    elseif kind=='artifact'then eq(s.player.statuses.artifact,v[n+1])
    elseif kind=='weak'or kind=='vulnerable'then
        eq(s.enemies[1].statuses[kind],v[n+1]);eq(s.enemies[2].statuses[kind]or 0,n==2 and v[n+1]or 0)
    elseif kind=='draw'then eq(#s.hand,before-1+v[n+1])
    else eq(s.enemies[1].hp,500-v[n+1]) end
end end
local s=C.new(data,{deck={},enemies={'jaw_worm'},seed=1})
eq(#s.sourcePools.srcColorless,35)
eq(s.sourcePools.srcColorless[1],'madness');eq(s.sourcePools.srcColorless[35],'dark_shackles')
eq(#s.sourcePools.colorlessShop.uncommon,20);eq(#s.sourcePools.colorlessShop.rare,15)
for _,id in ipairs(s.sourcePools.srcColorless)do assert(s.catalog.cards[id]);assert(C.canUpgrade(s,{cardId=id}))end
print('ok colorless base/upgraded production entry and complete source pools')
