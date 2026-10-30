package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_card_actions')
local data=require('abyss_data')
local function eq(a,b,label) assert(a==b,'[HAND_MUTATION_CONTRACT] '..label..': '..tostring(a)..' ~= '..tostring(b)) end
local function battle()
    local s=C.new(data,{seed=42,deck={'strike'},enemies={'cultist'},cardRandomSeed='42'})
    s.hand={};s.draw={};s.discard={};s.exhaust={};s.cardActions=nil
    return s
end
local function card(uid,id) return {uid=uid,cardId=id,upgraded=false} end
local calls,upgrades={},{}
local random,upgrade=C.cardRandom,C.upgrade
C.cardRandom=function(s,max)
    local result=random(s,max)
    calls[#calls+1]={max=max,result=result,nextUid=s.nextUid}
    return result
end
C.upgrade=function(s,c)
    upgrades[#upgrades+1]=c.uid
    return upgrade(s,c)
end
local function apply(s,e) A.apply(C,s,{effect=e,source=s.player}) end
local function reset() calls={};upgrades={} end
local function snapshot(s)
    if not ABYSS_HAND_MUTATION_TRACE then return end
    local function pile(p)
        local out={};for _,c in ipairs(p)do out[#out+1]=table.concat({c.uid,c.cardId,tostring(c.upgraded),c.upgrades or 0,c.costForTurn or '-',c.costOverride or '-',c.costReduction or '-'},':')end
        return table.concat(out,',')
    end
    local rng={};for _,v in ipairs(calls)do rng[#rng+1]=v.max..':'..v.result..':'..v.nextUid end
    print('HAND_MUTATION_TRACE '..table.concat({pile(s.hand),pile(s.draw),pile(s.discard),s.nextUid,table.concat(rng,','),table.concat(upgrades,',')},'|'))
end
-- Constructors, double Master Reality hooks and overflow use real cards and
-- state; insertion RNG observes the already-advanced fresh UID.
for _,op in ipairs({'makeTempCardInHand','makeTempCardInDraw'})do
    for _,size in ipairs({0,9,10})do
        for _,reality in ipairs({0,1})do
            local s=battle();reset();s.player.statuses.master_reality=reality
            for i=1,size do s.hand[i]=card(100+i,'strike')end
            s.draw={card(201,'defend'),card(202,'bash')}
            local nextUid=s.nextUid
            apply(s,{op=op,card='searing_blow',value=2})
            eq(s.nextUid,nextUid+2,'fresh UID count')
            eq(#upgrades,reality*(op=='makeTempCardInHand' and 4 or 2),'constructor upgrade hooks')
            if op=='makeTempCardInDraw'then
                eq(#calls,2,'draw insertion RNG count');eq(calls[1].max,3,'first insertion range');eq(calls[2].max,4,'second insertion range')
                eq(calls[1].nextUid,nextUid+1,'constructor precedes first RNG');eq(calls[2].nextUid,nextUid+2,'constructor precedes second RNG')
                eq(#s.draw,4,'draw insertion count');eq(#s.hand,size,'draw preserves hand')
            else
                eq(#calls,0,'hand generation has no RNG');eq(#s.hand,math.min(10,size+2),'hand capacity');eq(#s.discard,math.max(0,size+2-10),'overflow discard')
            end
            snapshot(s)
        end
    end
end
for _,size in ipairs({0,10})do
    local s=battle();reset();s.player.statuses.master_reality=1
    for i=1,size do s.hand[i]=card(100+i,'strike')end
    local pool={}
    for _,rarity in ipairs({'common','uncommon','rare'})do
        for _,id in ipairs(s.sourcePools.src[rarity])do
            local d=s.catalog.cards[id];if d.type=='attack'and not d.healing then pool[#pool+1]=id end
        end
    end
    local uid=s.nextUid;apply(s,{op='generateAttack'})
    eq(#calls,1,'attack RNG count');eq(calls[1].max,#pool,'eligible ordered pool');eq(calls[1].nextUid,uid,'attack roll precedes constructor')
    local generated=size==0 and s.hand[1]or s.discard[1]
    eq(generated.cardId,pool[calls[1].result],'attack uses ordered rarity pool');eq(generated.costForTurn,0,'generated attack cost');eq(#upgrades,2,'attack double creation hook')
    snapshot(s)
end
local s=battle();reset()
for i,id in ipairs({'strike','defend','bash','blood_for_blood','whirlwind','dazed'})do s.hand[i]=card(100+i,id)end
local costs={};for i,c in ipairs(s.hand)do costs[i]=C.combatBaseCost(s,c)end
apply(s,{op='randomizeHandCost'})
local n=0
for i,c in ipairs(s.hand)do
    if costs[i]>=0 then
        n=n+1;eq(calls[n].max,4,'cost roll range')
        local rolled=calls[n].result-1
        eq(c.costForTurn,rolled~=costs[i] and rolled or nil,'only changed cost is assigned')
        eq(c.costOverride,c.costForTurn,'turn and combat costs agree')
        if c.cardId=='blood_for_blood'and rolled~=costs[i]then eq(c.costReduction,0,'blood for blood reduction reset')end
    else eq(c.costForTurn,nil,'negative base cost skipped')end
end
eq(#calls,n,'one RNG per nonnegative cost');snapshot(s)
-- All-hand upgrade remains separate from the UID selector fast/choice paths.
s=battle();reset();s.hand={card(101,'strike'),card(102,'searing_blow'),card(103,'dazed')}
apply(s,{op='upgradeHand',all=true});eq(s.pendingChoice,nil,'all upgrade avoids choice');eq(#upgrades,2,'all upgrades only eligible cards');snapshot(s)
print('LUA_HAND_MUTATION_PASS 16')
