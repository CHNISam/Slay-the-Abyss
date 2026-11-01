-- Source-derived lifecycle through actual Combat/Run; TASK-15.15.
-- SPLIT_FAMILY=spike runs the same shared contract against the merged reference.
-- No replacement AI, mock Combat, invented enemy data, or injected split intent.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, D, Run = require('abyss_combat'), require('abyss_data'), require('abyss_run')
local family = os.getenv('SPLIT_FAMILY') or 'acid'
assert(family == 'acid' or family == 'spike')
local large, medium = family .. '_slime_l', family .. '_slime_m'
local passed, failed = 0, 0
local function eq(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(why)))
end
local function battle(ids)
    return C.new(D, {enemies=ids or {large}, deck={'strike'}, seed=42})
end
local function hit(s, n) return C.damage(s, s.player, s.enemies[1], n, true) end
local function lower(s, hp) hit(s, s.enemies[1].hp - hp); return s.enemies[1] end
local function force(e, id)
    for i, intent in ipairs(e.intents) do if intent.id == id then e.intentIndex = i; return end end
    error('missing existing intent ' .. id)
end
local function count(s, id)
    local n=0
    for _, pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do
        for _, card in ipairs(pile) do if card.cardId == id then n=n+1 end end
    end
    return n
end
local function observe(fn, mainRolls)
    local old, trace, primary = C.random, {}, 0
    C.random = function(s, n)
        trace[#trace+1] = {range=n, count=#s.enemies, first=s.enemies[1] and s.enemies[1].hp}
        local result=old(s,n) -- Preserve the real production seed advance.
        if n==100 then primary=primary+1;return mainRolls and mainRolls[primary] or 1 end
        return result
    end
    local ok, why=pcall(fn,trace)
    C.random=old
    assert(ok,why)
end

test('exact half for every A0 maxHP interrupts once and does not spawn immediately',function()
    for maximum=65,69 do
        local s=battle();local p=s.enemies[1];p.hp=maximum;p.maxHp=maximum
        hit(s,maximum-math.floor(maximum/2)-1)
        assert(C.intent(s,1).kind~='split','one HP above half must not split')
        hit(s,1);eq(C.intent(s,1).kind,'split','at half');eq(#s.enemies,1)
        hit(s,1);local n=0
        for _,event in ipairs(s.events) do if event.kind=='enemy_interrupt' then n=n+1 end end
        eq(n,1,'one interruption');eq(s.phase,'player')
    end
end)

test('action-time remaining HP becomes both children HP without attacking',function()
    local s=battle();local parent=lower(s,30);hit(s,7)
    assert(C.endTurn(s));eq(#s.enemies,3,'expanded group');eq(s.enemies[2],parent)
    eq(parent.hp,0);eq(s.player.hp,80,'split cannot use old attack payload')
    for _,i in ipairs({1,3}) do
        local child=s.enemies[i];eq(child.definitionId,medium);eq(child.hp,23);eq(child.maxHp,23)
    end
    eq(count(s,'slimed'),0);eq(s.phase,'player');eq(s.turn,2)
end)

test('only child init requests for Acid; Spike retains its distinct parent roll',function()
    local s=battle();local parent=lower(s,30)
    observe(function(trace)
        assert(C.endTurn(s))
        eq(#trace,family=='acid' and 2 or 3,'source action RNG request count')
        for i,row in ipairs(trace) do
            eq(row.range,100,'no medium HP or fallback sampling')
            eq(row.count,i,'init must occur before each insertion')
        end
        eq(trace[1].first,0,'parent destroyed before first child init')
        eq(s.enemies[2],parent);eq(C.intent(s,1).id,medium..'_1');eq(C.intent(s,3).id,medium..'_2')
    end,{1,71,30})
end)

test('Acid split does not invent a parent roll when an original teammate survives',function()
    local s=battle({large,'sneaky_gremlin'});lower(s,30)
    observe(function(trace)
        assert(C.endTurn(s));eq(#trace,family=='acid' and 2 or 3)
        for i,row in ipairs(trace) do eq(row.range,100);eq(row.count,i+1) end
        eq(s.player.hp,71);eq(#s.enemies,4)
    end,{1,71,30})
end)

test('new identities and clean powers preserve old actor and detached frame',function()
    local s=battle({large,'sneaky_gremlin'});local parent=lower(s,30);local ally=s.enemies[2]
    C.addStatus(parent,'strength',6);C.addStatus(parent,'weak',3);C.addStatus(parent,'poison',2)
    local statuses=parent.statuses;local frame=s.events[#s.events].frame;local original=frame.enemies[1].id
    assert(C.endTurn(s));eq(#s.enemies,4,'expanded group with retained teammate')
    eq(s.enemies[2],parent);eq(parent.statuses,statuses);eq(s.enemies[4],ally)
    local seen={}
    for _,actor in ipairs(s.enemies) do assert(not seen[actor.id]);seen[actor.id]=true end
    for _,i in ipairs({1,3}) do
        local child=s.enemies[i];eq(child.hp,28);eq(child.block,0);eq(next(child.statuses),nil)
        assert(child.statuses~=statuses and child~=parent and child~=ally)
        eq(child.acidLast,nil);eq(child.spikeLast,nil)
    end
    assert(s.enemies[1].statuses~=s.enemies[3].statuses)
    eq(#frame.enemies,2);eq(frame.enemies[1].id,original);eq(frame.enemies[1].hp,30)
    eq(s.player.hp,71,'original teammate acts exactly once; newborns do not act')
end)

test('pre-action poison crossing threshold splits this turn at post-poison HP',function()
    local s=battle();local parent=s.enemies[1];parent.hp=40;parent.maxHp=68
    C.addStatus(parent,'poison',7);C.addStatus(parent,'spore_cloud',2)
    assert(C.endTurn(s));eq(#s.enemies,3);eq(s.enemies[1].hp,33);eq(s.enemies[3].hp,33)
    eq(s.player.hp,80);eq(s.player.statuses.vulnerable or 0,0,'Suicide(false) has no death power')
    eq(C.outcome(s),nil,'no premature victory')
end)

test('Thorns interrupt keeps queued Slimed and roll then restores split',function()
    observe(function(trace)
        local s=battle();local parent=s.enemies[1];parent.hp=40;parent.maxHp=68
        force(parent,large..'_1');parent[family..'Last']=large..'_1';C.addStatus(s.player,'thorns',6)
        local before=#trace;assert(C.endTurn(s));eq(parent.hp,34);eq(count(s,'slimed'),2)
        local rolls=0;for i=before+1,#trace do if trace[i].range==100 then rolls=rolls+1 end end
        eq(rolls,1,'already queued attack roll survives interrupt')
        eq(C.intent(s,1).kind,'split','queued SetMove restores split after roll')
        eq(parent[family..'Last'],large..'_split','interrupted history prevents obsolete fallback')
        eq(#s.enemies,1,'interrupt does not execute split early')
        local hp=s.player.hp;assert(C.endTurn(s));eq(#s.enemies,3);eq(s.player.hp,hp)
    end)
end)

test('real Run withholds reward until two children die and settles exactly once',function()
    local r=Run.new(D,42);r.floor=4;assert(Run.startCombat(r,'large_'..family))
    local s=r.combat;lower(s,23);local gold,victories=r.gold,r.victories
    assert(Run.endTurn(r));eq(#s.enemies,3,'real encounter split');eq(r.phase,'combat')
    eq(r.gold,gold);eq(r.victories,victories)
    for _,i in ipairs({1,3}) do
        s.hand={{uid=s.nextUid,cardId='bludgeon'}};s.nextUid=s.nextUid+1;s.energy=3
        assert(Run.play(r,s.hand[1].uid,i))
        eq(r.phase,i==1 and 'combat' or 'reward')
        if i==1 then eq(r.gold,gold) end
    end
    eq(r.victories,victories+1);eq(r.gold,gold,'victory offers gold without claiming it')
    eq(r.rewards.gold,D.rules.rewards.normalGold);eq(r.rewards.goldClaimed,false)
    assert(Run.claimGoldReward(r));eq(r.gold,gold+D.rules.rewards.normalGold)
    eq(r.rewards.goldClaimed,true)
    local claimed=C.copy(r)
    local ok,why=Run.claimGoldReward(r);eq(ok,false);eq(why,'no_pending_gold')
    eq(r.gold,claimed.gold);eq(r.rewards.goldClaimed,claimed.rewards.goldClaimed)
    eq(r.phase,'reward');eq(r.victories,claimed.victories);eq(r.nextDeckUid,claimed.nextDeckUid)
    local after=r.gold;assert(not Run.endTurn(r));eq(r.gold,after)
end)

test('real targeted fire potion then card damage uses committed combat identity',function()
    local r=Run.new(D,42);r.floor=4;assert(Run.startCombat(r,'large_'..family))
    local old=r.combat;old.enemies[1].hp=40;old.enemies[1].maxHp=68
    assert(Run.obtainPotion(r,'fire_potion'));assert(Run.usePotion(r,1,1))
    eq(r.combat.enemies[1].hp,20);eq(C.intent(r.combat,1).kind,'split')
    hit(r.combat,5);assert(Run.endTurn(r));eq(#r.combat.enemies,3);eq(r.combat.enemies[1].hp,15)
end)

test('lethal hit and lethal poison cancel spawn without any child init draws',function()
    observe(function(trace)
        for _,poison in ipairs({false,true}) do
            local s=battle();local parent=lower(s,30)
            if poison then C.addStatus(parent,'poison',99) else hit(s,99) end
            local before=#trace;assert(C.endTurn(s));eq(s.phase,'victory');eq(#s.enemies,1);eq(#trace,before)
        end
    end)
end)

test('plain below-half endTurn and dead-source attack are not damage callbacks',function()
    local s=battle({large,medium});local parent=s.enemies[1];parent.hp=30;parent.maxHp=68
    force(parent,large..'_2');assert(C.endTurn(s));assert(not parent.splitTriggered)
    s.enemies[2].hp=0;C.damage(s,s.enemies[2],parent,0)
    assert(not parent.splitTriggered,'dead source cannot manufacture damage()')
end)

test('zero and fully blocked damage callbacks still interrupt below half',function()
    for _,blocked in ipairs({false,true}) do
        local s=battle();local parent=s.enemies[1];parent.hp=34;parent.maxHp=68
        if blocked then parent.block=7 end
        hit(s,blocked and 7 or 0);eq(parent.hp,34);eq(C.intent(s,1).kind,'split')
    end
end)

local function same(actual, expected)
    if type(expected) ~= 'table' then return eq(actual, expected) end
    assert(type(actual) == 'table')
    for key, value in pairs(expected) do same(actual[key], value) end
    for key in pairs(actual) do assert(expected[key] ~= nil, 'unexpected field ' .. tostring(key)) end
end

test('both original teammates act once across five retained slots',function()
    local s=battle({'sneaky_gremlin',large,'sneaky_gremlin'})
    local left,parent,right=s.enemies[1],s.enemies[2],s.enemies[3]
    C.damage(s,s.player,parent,parent.hp-30,true);s.events={}
    assert(C.endTurn(s));eq(#s.enemies,5);eq(s.enemies[1],left);eq(s.enemies[3],parent);eq(s.enemies[5],right)
    eq(s.player.hp,62,'only two old teammates attack')
    local actions={};for _,event in ipairs(s.events) do if event.kind=='intent' then actions[#actions+1]=event.detail.enemy end end
    same(actions,{left.id,parent.id,right.id})
end)

test('failed card restores half-HP interrupt and original references before retry',function()
    local s=battle();local parent=s.enemies[1];parent.hp=36;parent.maxHp=68
    s.catalog.cards.strike.effects={{op='damage',value=6},{op='block',value=5}}
    local before=C.copy(s);local enemies,statuses,events=s.enemies,parent.statuses,s.events
    local block=C.block;C.block=function() error('SPLIT_CARD_FAILURE') end
    local ok,why=pcall(C.play,s,s.hand[1].uid,1);C.block=block
    assert(not ok and tostring(why):find('SPLIT_CARD_FAILURE',1,true));same(s,before)
    eq(s.enemies,enemies);eq(s.enemies[1],parent);eq(parent.statuses,statuses);eq(s.events,events)
    assert(C.play(s,s.hand[1].uid,1));eq(C.intent(s,1).kind,'split')
end)

test('failed potion leaves run and original combat untouched before retry',function()
    local r=Run.new(D,42);r.floor=4;assert(Run.startCombat(r,'large_'..family))
    local s=r.combat;local parent=s.enemies[1];parent.hp=40;parent.maxHp=68
    assert(Run.obtainPotion(r,'fire_potion'))
    local before=C.copy(r);local damage=C.damage
    C.damage=function(...) local lost=damage(...);error('SPLIT_POTION_FAILURE') end
    local ok,why=Run.usePotion(r,1,1);C.damage=damage
    eq(ok,false);eq(why,'potion_effect_failed');same(r,before)
    eq(r.combat,s);eq(s.enemies[1],parent)
    assert(Run.usePotion(r,1,1));eq(C.intent(r.combat,1).kind,'split')
end)

print(family..' split contract: '..passed..' passed; '..failed..' failed')
assert(failed==0,'unimplemented '..family..' split contract: '..failed..' failing groups')
