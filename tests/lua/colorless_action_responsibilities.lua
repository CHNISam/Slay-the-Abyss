package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Colorless,Random=require('abyss_combat'),require('abyss_card_actions'),require('abyss_colorless_cards'),require('abyss_sts_random')
local base=C.new(require('abyss_data'),{deck={},enemies={'jaw_worm','jaw_worm'},seed=37,shuffleSeed='41',cardRandomSeed='43'})
local count=0
local trace=ABYSS_COLORLESS_TRACE and print or function()end
local function eq(a,b,label)assert(a==b,'[COLORLESS_ACTION] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function serialize(v,seen)
    if type(v)=='function'then return 'function'end
    if type(v)~='table'then return type(v)..':'..tostring(v)end
    seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
    seen.n=seen.n+1;seen[v]=seen.n
    local keys={}
    for k in pairs(v)do if k~='catalog'and k~='rules'and k~='sourcePools'then keys[#keys+1]=k end end
    table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
    local out={};for _,k in ipairs(keys)do out[#out+1]=serialize(k,seen)..'='..serialize(v[k],seen)end
    return '{'..table.concat(out,';')..'}'
end
local function fresh(s,id,pile,extra)
    local c=A.fresh(C,s,id)
    for k,v in pairs(extra or {})do c[k]=v end
    if pile then s[pile][#s[pile]+1]=c end
    return c
end
local function state()
    local s=C.copy(base);s.events={};s.energy=10
    for _,enemy in ipairs(s.enemies)do enemy.hp=100;enemy.maxHp=100;enemy.block=0 end
    return s
end
local function apply(s,kind,extra,options,combat)
    local effect={op='colorless',kind=kind,value=2}
    for k,v in pairs(extra or {})do effect[k]=v end
    local item={effect=effect,source=s.player,target=s.enemies[1]}
    for k,v in pairs(options or {})do item[k]=v end
    local result=table.pack(Colorless.apply(combat or C,s,item))
    if ABYSS_COLORLESS_TRACE then trace('COLORLESS_TRACE '..kind..' '..serialize({state=s,item=item,result=result,anchors=s.anchors}))end
    return item,result
end
local function test(name,fn)
    fn(state());count=count+1;print('COLORLESS_CASE '..name)
end
local group=ABYSS_COLORLESS_GROUP or 'all'
if group=='random'or group=='all'then
test('madness rejects a zero-cost sample before selecting a positive-cost object',function(s)
    local zero=fresh(s,'anger','hand');local paid=fresh(s,'bash','hand');s.anchors={zero,paid}
    local calls=0;local combat=setmetatable({cardRandom=function(st,n)
        eq(st,s);eq(n,2);calls=calls+1;return calls==1 and 1 or 2
    end},{__index=C})
    apply(s,'madness',nil,nil,combat);eq(calls,2,'Madness rejection RNG calls');eq(zero.costOverride,nil);eq(paid.costOverride,0)
end)
test('madness base-cost fallback consumes real RNG and keeps zero-only hands untouched',function(s)
    fresh(s,'anger','hand');local paid=fresh(s,'bash','hand',{costForTurn=0});s.anchors={paid}
    apply(s,'madness');eq(paid.costOverride,0)
    s.hand={fresh(s,'anger')};local counter=s.cardRandomRng.counter;apply(s,'madness');eq(s.cardRandomRng.counter,counter)
end)
test('Deep Breath queues held relic callbacks before shuffle and consumes two shuffle longs',function(s)
    s.relics={'the_abacus','sundial'};s.sundialCounter=2
    local x=fresh(s,'strike','draw');local y=fresh(s,'defend','discard');fresh(s,'bash','discard');s.anchors={x,y}
    local before=s.shuffleRng.counter;apply(s,'deepBreath');eq(s.cardActions[1].effect.op,'block','relic callback order')
    A.drain(C,s);eq(s.shuffleRng.counter,before+2,'Deep Breath two shuffles');eq(#s.draw,3);eq(#s.discard,0)
    if ABYSS_COLORLESS_TRACE then trace('COLORLESS_TRACE deepBreath-drained '..serialize({state=s,anchors=s.anchors}))end
end)
test('empty Deep Breath does not queue a shuffle',function(s)apply(s,'deepBreath');eq(s.cardActions,nil)end)
test('Violence uses candidate insertion RNG and repeated shuffle while keeping identities',function(s)
    for _,id in ipairs({'strike','defend','bash','anger','defend'})do fresh(s,id,'draw')end
    s.anchors={s.draw[1],s.draw[3],s.draw[4]};local before=s.shuffleRng.counter
    apply(s,'violence',{value=2});eq(#s.hand,2);eq(s.shuffleRng.counter,before+2,'Violence shuffle count')
    for _,c in ipairs(s.hand)do eq(s.catalog.cards[c.cardId].type,'attack')end
end)
test('Violence empty candidates do not spend shuffle RNG',function(s)
    fresh(s,'defend','draw');local before=s.shuffleRng.counter;apply(s,'violence');eq(s.shuffleRng.counter,before)
end)
test('generation batches preserve RNG, costs and Chemical X upgrades',function(s)
    fresh(s,'defend','draw');apply(s,'generateDraw',{value=2,cardType='attack'});eq(#s.draw,3)
    apply(s,'generateColorless',{value=2});eq(#s.hand,2)
    s.relics={'chemical_x'};apply(s,'transmutation',{value=1,energyOnUse=1});eq(#s.hand,5)
    for i=3,5 do eq(s.hand[i].upgraded,true);eq(s.hand[i].costForTurn,0)end
end)
end
if group=='rewards'or group=='all'then
test('Greed kill updates gold and score before the gold event',function(s)
    s.enemies[1].hp=1;local before=s.player.gold;local score=s.scoreStats.goldGained
    apply(s,'greed',{value=20});eq(s.player.gold,before+20);eq(s.scoreStats.goldGained,score+20)
    eq(s.events[#s.events].kind,'gold')
end)
test('Ectoplasm blocks Greed rewards after a real kill',function(s)
    s.enemies[1].hp=1;s.relics={'ectoplasm'};local before=s.player.gold
    apply(s,'greed',{value=20});eq(s.player.gold,before)
end)
test('Greed preserves resolved damage and captured kind when damage hook rewrites the effect',function(s)
    local before=s.player.gold;local a={kind='greed',value=20,resolved={[s.enemies[1].id]={tag='captured'}}}
    local instance=fresh(s,'ritual_dagger')
    local combat=setmetatable({damage=function(st,source,target,n,_,_,resolved)
        eq(st,s);eq(source,s.player);eq(n,20);eq(resolved,a.resolved[target.id]);a.kind='ritual';target.hp=0
    end},{__index=C})
    local result=table.pack(Colorless.apply(combat,s,{effect=a,target=s.enemies[1],instance=instance}));eq(result.n,0);eq(s.player.gold,before+20)
    if ABYSS_COLORLESS_TRACE then trace('COLORLESS_TRACE captured-kind '..serialize({state=s,effect=a,result=result}))end
end)
test('all nonqualifying kills deny gold and ritual growth',function(s)
    for _,flag in ipairs({'escaped','halfDead','minion','minionStatus','alreadyDead','survivor'})do
        local target=s.enemies[1];target.hp=100;target.escaped=nil;target.halfDead=nil;target.minion=nil;target.statuses.minion=nil
        if flag=='minionStatus'then target.statuses.minion=1
        elseif flag=='alreadyDead'then target.hp=0
        elseif flag~='survivor'then target[flag]=true end
        local before=s.player.gold;local c=fresh(s,'ritual_dagger',nil,{deckUid=31})
        local combat=setmetatable({damage=function(_,_,t)if flag~='survivor'then t.hp=0 end end},{__index=C})
        apply(s,'greed',{value=20},nil,combat);eq(s.player.gold,before,'ineligible '..flag)
        apply(s,'ritual',{value=3,damage=15},{instance=c},combat);eq(c.misc,nil,'no growth '..flag)
    end
end)
test('Ritual grows each aliased physical object once and records permanent deck identity',function(s)
    local original=fresh(s,'ritual_dagger','hand',{deckUid=31});local related=fresh(s,'ritual_dagger','draw',{uuid=original.uuid,misc=18})
    local unrelated=fresh(s,'ritual_dagger','exhaust',{misc=33})
    s.cardInUse=original;s.queuedCards={{card=related}};s.cardActions={{instance=original}};s.anchors={original,related,unrelated}
    s.enemies[1].hp=1;apply(s,'ritual',{value=3,damage=15},{instance=original})
    eq(original.misc,18,'one growth for original aliases');eq(related.misc,21);eq(unrelated.misc,33);eq(s.ritualDaggerGrowth[31],3)
end)
test('generated Ritual copies grow without claiming master-deck ownership',function(s)
    local c=fresh(s,'ritual_dagger','hand');s.enemies[1].hp=1
    apply(s,'ritual',{value=5,damage=15},{instance=c});eq(c.misc,20);eq(next(s.ritualDaggerGrowth),nil)
end)
test('damage throws preserve the original error object',function(s)
    local failure={tag='damage failure'};local combat={damage=function()error(failure)end}
    local ok,reason=pcall(Colorless.apply,combat,s,{effect={kind='greed',value=20},target=s.enemies[1]})
    eq(ok,false);eq(reason,failure);eq(s.ritualDaggerGrowth,nil)
    if ABYSS_COLORLESS_TRACE then trace('COLORLESS_TRACE error-object '..serialize({state=s,error=reason,failure=failure}))end
end)
end
if group=='dispatch'or group=='all'then
test('Apotheosis upgrades every pile and Enlightenment respects permanent cost',function(s)
    for _,pile in ipairs({'hand','draw','discard','exhaust'})do fresh(s,'bash',pile)end
    apply(s,'apotheosis');for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do eq(pile[1].upgraded,true)end
    apply(s,'enlightenment',{value=1});eq(s.hand[1].costOverride,1);eq(s.hand[1].costForTurn,1)
end)
test('Shackles snapshots Artifact before strength application',function(s)
    s.enemies[1].statuses.artifact=1;apply(s,'shackles',{value=9});eq(s.enemies[1].statuses.shackled,nil)
    apply(s,'shackles',{value=9});eq(s.enemies[1].statuses.shackled,9)
end)
test('Impatience skips attack hands and really draws after attack leaves',function(s)
    local c=fresh(s,'strike','hand');fresh(s,'defend','draw');apply(s,'impatience',{value=1});eq(s.hand[1],c);eq(#s.hand,1)
    s.hand={};apply(s,'impatience',{value=1});eq(#s.hand,1)
end)
test('selection aliases preserve real choice tokens and physical object movement',function(s)
    fresh(s,'strike','hand');fresh(s,'defend','hand');apply(s,'purity',{value=1});eq(s.pendingChoice.op,'colorless')
    local uid=s.hand[1].uid;assert(Colorless.choose(C,s,s.pendingChoice.token,uid));assert(Colorless.choose(C,s,s.pendingChoice.token,0));eq(#s.exhaust,1)
    s.hand={};s.pendingChoice=nil;local drawn=fresh(s,'strike','draw');apply(s,'secret',{cardType='attack'});eq(s.hand[1],drawn)
    apply(s,'forethought',{value=0});eq(s.draw[1],drawn);eq(drawn.freeToPlayOnce,true)
end)
test('Discovery keeps the original top reaction and exclusion',function(s)
    apply(s,'discovery');eq(s.cardActions[1].effect.op,'discover');eq(s.cardActions[1].effect.exclude,'discovery')
end)
test('Panache accumulation and Bomb state aliases survive repeated use',function(s)
    apply(s,'panache',{value=10});apply(s,'panache',{value=14});eq(s.player.panacheDamage,24)
    apply(s,'bomb',{value=40});apply(s,'bomb',{value=50});eq(s.player.colorlessBombs,s.colorlessBombs);eq(#s.colorlessBombs,2)
end)
test('Mayhem queues and auto-plays with live target refresh',function(s)
    apply(s,'mayhem',{value=2});eq(s.cardActions[1].effect.kind,'mayhemPlay')
    s.cardActions=nil;fresh(s,'defend','draw');fresh(s,'strike','draw');apply(s,'mayhemPlay',{value=2});eq(#s.draw,0)
end)
test('Sadistic damage passes fixed damage to its original target',function(s)
    local hp=s.enemies[1].hp;apply(s,'sadisticDamage',{value=5});eq(s.enemies[1].hp,hp-5)
end)
test('unknown action errors retain exact user-facing text',function(s)
    for _,kind in ipairs({'unknown',false})do
        local ok,reason=pcall(Colorless.apply,C,s,{effect={kind=kind}});eq(ok,false)
        eq(reason:match('unimplemented colorless action: .*'),'unimplemented colorless action: '..tostring(kind))
    end
end)
end
print('COLORLESS_ACTION_PASS '..group..' '..count)
