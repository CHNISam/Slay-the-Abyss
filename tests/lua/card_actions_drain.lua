package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_card_actions')
local C=require('abyss_combat')
local data=require('abyss_data')
-- Raw execution observes today's owner. Only the independently loaded complete
-- frozen module opts into its original Rare dependency, never a live fallback.
local epoch=ABYSS_DRAIN_EPOCH or 'current-family'
assert(epoch=='frozen-rare'or epoch=='current-family','unknown drain source epoch')
local frozen=epoch=='frozen-rare'
local rareModule=frozen and 'abyss_rare_relics'or 'abyss_relic_family_combat'
local rare=frozen and require(rareModule)or require(rareModule).rare
local rareQueries=frozen and rare or require('abyss_relic_queries').rare
local silent=require('abyss_silent_final_cards')
local original={apply=A.apply,reaction=A.reactionRetained,owns=rareQueries.owns,refresh=rare.onRefreshHand,allowed=silent.allowedAfterVictory,require=require}
local count=0
local function eq(a,b,label)assert(a==b,'[DRAIN_CONTRACT] '..label..' '..tostring(a)..' ~= '..tostring(b))end
local quoted={}
local function quote(value)
    if not quoted[value]then quoted[value]='"'..value:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',string.byte(c))end)..'"'end
    return quoted[value]
end
-- The trace-only native observer emits complete typed table definitions with
-- persistent IDs. The raw fixture needs no custom VM or observer installation.
local function graph(value)
    return assert(ABYSS_DRAIN_GRAPH,'native trace observer required')(value)
end
if ABYSS_DRAIN_TRACE then
    local child={value='first'};local f=function()error('[DRAIN_CONTRACT] observer invoked function')end
    local sample={a=child,b=child,gone='old',fn=f,[f]=child,[child]=f,[true]='bool',[7]='number'};sample.self=sample
    setmetatable(sample,{owner=sample,label='first',__index=f})
    local first=graph(sample);sample.gone=nil;child.value='second';setmetatable(sample,{owner=sample,label='second',__index=f});local second=graph(sample)
    child.value='first';local third=graph(sample)
    sample.a=nil;sample.b=nil;sample.fn=nil;sample[f]=nil;sample[child]=nil;sample[true]=nil;sample[7]=nil;setmetatable(sample,nil);local fourth=graph(sample)
    print('DRAIN_GRAPH_PROBE ['..first..','..second..','..third..','..fourth..']')
end
local function run(name,setup,check,fullCatalog)
    A.apply=original.apply;A.reactionRetained=original.reaction
    rareQueries.owns=original.owns;rare.onRefreshHand=original.refresh;silent.allowedAfterVictory=original.allowed;require=original.require
    -- Constructor is real, but its opening drain is outside the controlled
    -- observation. Guard it so semantic mutants reach the tested invocation.
    local s=C.new(data,{seed=42,deck={'strike'},enemies={'cultist'},cardRandomSeed='42',beforeFirstTurn=function(state)state.drainingCardActions=true;return true end})
    s.drainingCardActions=nil;s.cardActions=nil;s.queuedCards=nil;s.resolvingCard=nil
    -- These controlled battles use only the real strike/defend definitions.
    -- Keep their complete definitions and all statuses/RNG/actors/pools while
    -- avoiding hundreds of unrelated card definitions at every observation.
    if not fullCatalog then s.catalog.cards={strike=s.catalog.cards.strike,defend=s.catalog.cards.defend}end
    s.hand={{uid=101,cardId='strike'},{uid=102,cardId='defend'}};s.draw={};s.discard={};s.exhaust={}
    local events={};local aliases={};local snapshots={};local observing=false
    local function observe(label,...)
        events[#events+1]={label=label,args=table.pack(...)}
        if ABYSS_DRAIN_TRACE and observing then snapshots[#snapshots+1]='{"label":'..quote(label)..',"graph":'..graph({state=s,aliases=aliases})..'}'end
    end
    local api={outcome=function(state)eq(state,s,'outcome identity');observe('outcome');return nil end,
        enemyActionRetained=function(effect)observe('enemy',effect);return false end,
        resolveQueuedCard=function(state,item)eq(state,s,'queued state');observe('queued',item);return false,nil,9 end,
        finishEarlyTurn=function(state)eq(state,s,'finish identity');eq(s.drainingCardActions,nil,'finish owner cleared');observe('finish');return false,nil,9 end}
    rareQueries.owns=function(state,id)eq(state,s,'owns state');eq(id,'unceasing_top','owns id');observe('owns');return false end
    rare.onRefreshHand=function(state,flag)eq(state,s,'refresh state');eq(flag,true,'refresh flag');observe('refresh');return false end
    silent.allowedAfterVictory=function(effect)observe('allowed',effect);return false end
    A.reactionRetained=function(effect)observe('reaction',effect);return false end
    A.apply=function(combat,state,item)eq(combat,api,'apply combat');eq(state,s,'apply state');observe('apply',item);return false,nil,9 end
    local requireError;local refreshLoads={}
    require=function(module)
        if module==rareModule then
            refreshLoads[#refreshLoads+1]=module
            -- Only the approved dependency name moved. Keep the historical
            -- graph event while checking the actual paths separately below.
            observe('require','abyss_rare_relics');if requireError then error(requireError)end
        elseif not frozen and module=='abyss_relic_queries'then
            refreshLoads[#refreshLoads+1]=module
        elseif module=='abyss_silent_final_cards'then
            observe('require',module);if requireError then error(requireError)end
        end
        return original.require(module)
    end
    local ctx={s=s,api=api,events=events,aliases=aliases,observe=observe,setRequireError=function(e)requireError=e end}
    ctx.item=function(op,label)
        local item={effect={op=op,value=1},source=s.player,target=s.enemies[1],instance=s.hand[1],label=label or op}
        aliases[#aliases+1]=item;return item
    end
    setup(ctx)
    observing=true
    local before=ABYSS_DRAIN_TRACE and graph({state=s,aliases=aliases})
    local result=table.pack(pcall(A.drain,api,s))
    if not frozen then
        for i,module in ipairs(refreshLoads)do
            eq(module,i%2==1 and rareModule or 'abyss_relic_queries','current refresh exact require order')
        end
        if not requireError then eq(#refreshLoads%2,0,'current refresh requires both owners')end
    end
    if check then check(ctx,result)else eq(result[1],true,name..' success');eq(result.n,1,name..' zero return')end
    count=count+1
    if ABYSS_DRAIN_TRACE then
        local after=graph({state=s,aliases=aliases,events=events,result=result})
        print('DRAIN_TRACE '..count..' {"name":'..quote(name)..',"before":'..before..',"observations":['..table.concat(snapshots,',')..'],"after":'..after..'}')
    end
end
local function labels(ctx,kind)
    local out={};for _,event in ipairs(ctx.events)do if event.label==kind then out[#out+1]=event.args[1].label end end
    return table.concat(out,',')
end
for _,outcome in ipairs({false,'victory','defeat','other'})do
    for _,op in ipairs({'block','unknown','enemyAction','silentFinal'})do
        run('retention '..tostring(outcome)..' '..op,function(x)
            x.api.outcome=function()x.observe('outcome',outcome);return outcome end
            x.s.cardActions={x.item(op)};x.aliases.queue=x.s.cardActions
        end,function(x,r)
            eq(r[1],true,'retention success');eq(r.n,1,'retention arity')
            eq(labels(x,'apply'),(not outcome or outcome=='victory'and op=='block')and op or '','retention execution')
            eq(#x.aliases.queue,0,'popped in place');eq(x.s.cardActions,nil,'normal cleanup')
        end)
    end
end
for _,field in ipairs({'pendingChoice','pendingDiscard','actionQueue'})do
    for _,when in ipairs({'initial','apply','outcome','queued','refresh'})do
        run('pause '..field..' '..when,function(x)
            local marker={};x.aliases.marker=marker
            if when=='initial'then x.s[field]=marker
            elseif when=='apply'then A.apply=function()x.s[field]=marker end
            elseif when=='outcome'then x.api.outcome=function()x.s[field]=marker end
            elseif when=='queued'then x.api.resolveQueuedCard=function()x.s[field]=marker end
            else rareQueries.owns=function()return true end;rare.onRefreshHand=function()x.s[field]=marker;return 'again'end end
            x.s.cardActions=(when=='refresh'or when=='queued')and {}or {x.item('block')}
            x.s.queuedCards=when=='queued'and {x.item('queued')}or {};x.aliases.queue=x.s.cardActions
            x.aliases.queued=x.s.queuedCards;x.s.resolvingCard=marker
        end,function(x,r)
            eq(r[1],true,'pause success');eq(r.n,1,'pause arity');eq(x.s.cardActions,x.aliases.queue,'pause queue retained')
            eq(x.s.queuedCards,x.aliases.queued,'pause queued retained');eq(x.s.resolvingCard,x.aliases.marker,'pause resolving retained')
            if when=='initial'then eq(#x.aliases.queue,1,'initial pause no pop')end
        end)
    end
end
for _,field in ipairs({'pendingScry','pendingHandChoice','pendingPileChoice','pendingPlay','resolvingEffects','endTurnAfterCard'})do
    run('nonpause '..field,function(x)x.s[field]={};x.s.cardActions={x.item('block')}end,function(x,r)
        eq(r[1],true,'nonpause success');eq(labels(x,'apply'),'block','nonpause executes');eq(x.s.cardActions,nil,'nonpause cleanup')
    end)
end
run('truthy owner guard',function(x)x.s.drainingCardActions='owner';x.s.cardActions={x.item('block')}end,function(x,r)
    eq(r[1],true,'guard success');eq(r.n,1,'guard zero returns');eq(#x.events,0,'guard no callbacks');eq(#x.s.cardActions,1,'guard queue untouched')
end)
run('same owner reentry',function(x)
    x.s.cardActions={x.item('block')};A.apply=function()local n=#x.events;eq(table.pack(A.drain(x.api,x.s)).n,0,'reentry arity');eq(#x.events,n,'reentry no callbacks');eq(x.s.drainingCardActions,true,'reentry preserves owner');eq(#x.s.cardActions,0,'popped before callback')end
end)
run('finish reentry and cleanup',function(x)
    x.s.cardActions={};x.s.queuedCards={};x.s.resolvingCard={};local calls=0
    x.api.finishEarlyTurn=function()
        calls=calls+1;eq(x.s.cardActions,nil,'finish cleanup');eq(x.s.queuedCards,nil,'finish queued cleanup');eq(x.s.resolvingCard,nil,'finish resolving cleanup')
        eq(x.s.drainingCardActions,nil,'finish flag');if calls==1 then eq(table.pack(A.drain(x.api,x.s)).n,0,'finish reentry')end
        return false,nil,9
    end
end)
run('dynamic finish double lookup',function(x)
    local reads=0;x.api.finishEarlyTurn=nil
    setmetatable(x.api,{__index=function(_,key)
        if key=='finishEarlyTurn'then reads=reads+1;x.observe('finishLookup',reads);eq(reads<=2,true,'bounded finish reads');return function()eq(reads,2,'two dynamic reads')end end
    end})
end)
run('queue priority TOP BOTTOM and identity',function(x)
    local first=x.item('block','first');local second=x.item('block','second');x.s.cardActions={first,second};x.aliases.queue=x.s.cardActions
    x.s.queuedCards={x.item('queued','queued')};x.aliases.queued=x.s.queuedCards
    A.apply=function(_,s,item)
        if item.label~='fromQueued'then eq(s.cardActions,x.aliases.queue,'dense queue identity')end;x.observe('apply',item)
        if item==first then eq(s.cardActions[1],second,'left shift');A.enqueue(s,{op='block'},s.player,s.enemies[1],s.hand[1],true);s.cardActions[1].label='top';A.enqueue(s,{op='block'},s.player,s.enemies[1],s.hand[1],false);s.cardActions[#s.cardActions].label='bottom'end
    end
    x.api.resolveQueuedCard=function(_,item)x.observe('queued',item);x.s.cardActions={x.item('block','fromQueued')}end
end,function(x,r)eq(r[1],true,'queue success');eq(labels(x,'apply'),'first,top,second,bottom,fromQueued','queue order');eq(labels(x,'queued'),'queued','queued order')end)
run('outcome changes queue before lookup',function(x)
    x.s.cardActions={x.item('block','old')};x.aliases.old=x.s.cardActions;local n=0
    x.api.outcome=function()n=n+1;if n==1 then x.s.cardActions={x.item('unknown','replacement')};return false end;return 'defeat'end
end,function(x,r)eq(r[1],true,'outcome success');eq(labels(x,'apply'),'replacement','outcome queue mutation');eq(#x.aliases.old,1,'old queue untouched')end)
run('dynamic apply and next outcome',function(x)
    x.s.cardActions={x.item('block','first'),x.item('block','second'),x.item('unknown','third')}
    A.apply=function(_,_,item)
        x.observe('apply',item);A.apply=function(_,_,nextItem)x.observe('replacementApply',nextItem);x.api.outcome=function()return 'victory'end end
    end
end,function(x,r)eq(r[1],true,'dynamic success');eq(labels(x,'apply'),'first','original apply');eq(labels(x,'replacementApply'),'second','dynamic apply and outcome')end)
for _,replacement in ipairs({'enemyAction','silentFinal','block'})do
    run('reaction replaces effect '..replacement,function(x)
        x.s.cardActions={x.item('unknown')};x.api.outcome=function()return 'victory'end
        A.reactionRetained=function(effect)x.observe('reaction',effect);x.aliases[1].effect={op=replacement};return false end
        x.api.enemyActionRetained=function(effect)x.observe('enemy',effect);eq(effect,x.aliases[1].effect,'new enemy effect');return true end
        silent.allowedAfterVictory=function(effect)x.observe('allowed',effect);eq(effect,x.aliases[1].effect,'new silent effect');return true end
    end,function(x,r)eq(r[1],true,'replacement success');eq(labels(x,'apply'),replacement=='block'and ''or 'unknown','repeated effect reads')end)
end
run('retained short circuit and enemy override',function(x)
    x.api.outcome=function()return 'victory'end;x.s.cardActions={x.item('block'),x.item('enemyAction')}
    A.reactionRetained=function(effect)eq(effect.op,'enemyAction','retained skips reaction');x.observe('reaction',effect);return true end
    x.api.enemyActionRetained=function(effect)x.observe('enemy',effect);return false end
end,function(x,r)eq(r[1],true,'override success');eq(labels(x,'apply'),'block','enemy override')end)
run('silent repeated allow',function(x)
    x.api.outcome=function()return 'victory'end;x.s.cardActions={x.item('silentFinal')};local n=0
    A.reactionRetained=original.reaction
    silent.allowedAfterVictory=function(effect)n=n+1;x.observe('allowed',effect);return n==2 end
end,function(x,r)eq(r[1],true,'silent success');eq(labels(x,'apply'),'silentFinal','second allow query')end)
for _,terminal in ipairs({false,'victory'})do
    run('refresh require '..tostring(terminal),function(x)x.api.outcome=function()return terminal end end,function(x,r)
        eq(r[1],true,'refresh success');local calls=0;for _,e in ipairs(x.events)do if e.label=='require'then calls=calls+1 end end;eq(calls,1,'terminal still requires rare')
    end)
end
run('refresh truthy no progress sentinel',function(x)
    local n=0;local sentinel={label='refresh sentinel'};x.aliases.sentinel=sentinel
    rareQueries.owns=function()return true end;rare.onRefreshHand=function()n=n+1;x.observe('refresh',n);if n==4 then error(sentinel)end;return 'again'end
end,function(x,r)eq(r[1],false,'bounded refresh error');eq(r[2],x.aliases.sentinel,'error identity');eq(x.s.drainingCardActions,true,'refresh failure retains owner')end)
run('refresh dynamic method and queues',function(x)
    rareQueries.owns=function()x.observe('owns');rare.onRefreshHand=function()x.s.cardActions={x.item('block','refreshed')};rareQueries.owns=function()return false end;return {}end;return true end
end,function(x,r)eq(r[1],true,'refresh success');eq(labels(x,'apply'),'refreshed','refresh joins owner')end)
run('end turn refresh short circuit',function(x)
    x.s.endTurnAfterCard=true;rareQueries.owns=function()error('[DRAIN_CONTRACT] end turn owns called')end
end)
for _,point in ipairs({'reaction','apply','queued','refresh'})do
    run('replacement queues '..point,function(x)
        x.s.cardActions={x.item(point=='reaction'and 'unknown'or 'block','first')};x.aliases.oldActions=x.s.cardActions
        x.s.queuedCards={x.item('queued','oldQueued')};x.aliases.oldQueued=x.s.queuedCards
        local function replace()
            x.s.cardActions={x.item('block','replacement')};x.s.queuedCards={x.item('queued','newQueued')}
            x.aliases.newActions=x.s.cardActions;x.aliases.newQueued=x.s.queuedCards
        end
        if point=='reaction'then A.reactionRetained=function()replace();return false end
        elseif point=='apply'then A.apply=function(_,_,item)x.observe('apply',item);if item.label=='first'then replace()end end
        elseif point=='queued'then x.s.cardActions={};x.api.resolveQueuedCard=function(_,item)x.observe('queued',item);if item.label=='oldQueued'then replace()end end
        else x.s.cardActions={};x.s.queuedCards={};rareQueries.owns=function()return true end;rare.onRefreshHand=function()replace();rareQueries.owns=function()return false end;return 'again'end end
    end,function(x,r)
        eq(r[1],true,'queue replacement success');eq(r.n,1,'queue replacement arity')
        eq(#x.aliases.newActions,0,'replacement actions consumed in place');eq(#x.aliases.newQueued,0,'replacement queued consumed in place')
        eq(labels(x,'queued'),point=='queued'and 'oldQueued,newQueued'or 'newQueued','replacement queued order')
        eq(x.s.cardActions,nil,'replacement actions cleaned');eq(x.s.queuedCards,nil,'replacement queued cleaned')
    end)
end
run('dynamic reaction and queued callbacks',function(x)
    x.s.cardActions={x.item('unknown','first'),x.item('unknown','second')}
    A.reactionRetained=function(effect)x.observe('firstReaction',effect);A.reactionRetained=function(nextEffect)x.observe('nextReaction',nextEffect);return false end;return false end
    x.s.queuedCards={x.item('queued','firstQueued'),x.item('queued','secondQueued')}
    x.api.resolveQueuedCard=function(_,item)x.observe('queued',item);x.api.resolveQueuedCard=function(_,nextItem)x.observe('replacementQueued',nextItem);return nil,false,9 end end
end,function(x,r)
    eq(r[1],true,'dynamic callbacks success');eq(r.n,1,'dynamic callbacks arity');eq(labels(x,'queued'),'firstQueued','first queued callback')
    eq(labels(x,'replacementQueued'),'secondQueued','dynamic queued callback')
    local first,nextCount=0,0;for _,e in ipairs(x.events)do if e.label=='firstReaction'then first=first+1 elseif e.label=='nextReaction'then nextCount=nextCount+1 end end
    eq(first,1,'first reaction once');eq(nextCount,1,'next reaction once')
end)
run('callback clears owner and reenters',function(x)
    x.s.cardActions={x.item('block','outer'),x.item('block','inner')}
    A.apply=function(_,_,item)
        x.observe('apply',item);if item.label=='outer'then x.s.drainingCardActions=nil;eq(table.pack(A.drain(x.api,x.s)).n,0,'cleared owner reentry arity')end
    end
end,function(x,r)eq(r[1],true,'cleared owner success');eq(labels(x,'apply'),'outer,inner','cleared owner permits reentry')end)
run('retained reads op again for enemy override',function(x)
    local reads=0;local effect=setmetatable({},{__index=function(_,key)
        if key=='op'then reads=reads+1;x.observe('opLookup',reads);return reads==1 and 'block'or 'enemyAction'end
    end})
    local item=x.item('block');item.effect=effect;x.s.cardActions={item};x.api.outcome=function()return 'victory'end
    A.reactionRetained=function()error('[DRAIN_CONTRACT] retained op must short circuit')end
    x.api.enemyActionRetained=function(e)eq(e,effect,'enemy dynamic effect');x.observe('enemy',e);return false end
end,function(x,r)eq(r[1],true,'op dynamic success');eq(labels(x,'apply'),'','enemy overrides retained op')end)
run('require can replace rare methods',function(x)
    local wrapped=require
    require=function(module)
        local result=wrapped(module)
        if module==rareModule then
            local owner=frozen and result or result.rare
            owner.onRefreshHand=function()x.observe('replacementRefresh');x.s.pendingChoice={};return {}end
            if frozen then owner.owns=function()x.observe('replacementOwns');return true end end
        elseif not frozen and module=='abyss_relic_queries'then result.rare.owns=function()x.observe('replacementOwns');return true end end
        return result
    end
end,function(x,r)
    eq(r[1],true,'require replacement success');eq(r.n,1,'require replacement arity');eq(x.s.pendingChoice~=nil,true,'dynamic required refresh runs')
end)
for _,point in ipairs({'outcome','reaction','enemy','apply','queued','require','owns','refresh','finish'})do
    run('error '..point,function(x)
        local sentinel={label=point};x.aliases.sentinel=sentinel
        local function fail()error(sentinel)end
        x.s.cardActions={x.item(point=='enemy'and 'enemyAction'or point=='reaction'and 'unknown'or 'block')};x.aliases.queue=x.s.cardActions
        if point=='outcome'then x.api.outcome=fail
        elseif point=='reaction'then A.reactionRetained=fail
        elseif point=='enemy'then x.api.enemyActionRetained=fail
        elseif point=='apply'then A.apply=fail
        elseif point=='queued'then x.s.cardActions={};x.s.queuedCards={x.item('queued')};x.api.resolveQueuedCard=fail
        elseif point=='finish'then x.api.finishEarlyTurn=fail
        else x.s.cardActions={};if point=='require'then x.setRequireError(sentinel)elseif point=='owns'then rareQueries.owns=fail else rareQueries.owns=function()return true end;rare.onRefreshHand=fail end end
    end,function(x,r)
        eq(r[1],false,'error propagated');eq(r[2],x.aliases.sentinel,'original error object');eq(r.n,2,'error arity')
        eq(x.s.drainingCardActions,point~='finish'and true or nil,'error owner boundary')
        if point=='apply'or point=='reaction'or point=='enemy'then eq(#x.aliases.queue,0,'error leaves popped')end
        if point=='finish'then eq(x.s.cardActions,nil,'finish failure after cleanup')end
    end)
end
-- Actual dispatch and real RNG, rather than only observed callback substitutes.
run('real random damage and queued block',function(x)
    A.apply=original.apply;A.reactionRetained=original.reaction
    for k,v in pairs(C)do x.api[k]=v end
    local random=C.cardRandom
    x.api.cardRandom=function(state,max)local value=random(state,max);x.observe('RNG',max,value);return value end
    x.s.cardActions={x.item('damageRandom'),x.item('block')}
end)
run('full catalog real Top draw',function(x)
    for k,v in pairs(C)do x.api[k]=v end
    A.apply=function(combat,state,item)x.observe('realApply',item);return original.apply(combat,state,item)end
    A.reactionRetained=original.reaction
    rareQueries.owns=function(...)x.observe('realOwns');return original.owns(...)end
    rare.onRefreshHand=function(...)x.observe('realRefresh');return original.refresh(...)end
    x.s.relics={'unceasing_top'};x.s.relicCounters={};rare.bindBattle(x.s);rare.atTurnStart(x.s)
    x.s.hand={};x.s.draw={{uid=300,cardId='strike'}};x.aliases.drawn=x.s.draw[1];x.aliases.draw=x.s.draw
end,function(x,r)
    eq(r[1],true,'real Top success');eq(r.n,1,'real Top arity');eq(x.s.hand[1],x.aliases.drawn,'real Top same drawn instance');eq(#x.aliases.draw,0,'real Top draw consumed')
end,true)
run('full catalog real queued card choice',function(x)
    for k,v in pairs(C)do x.api[k]=v end
    A.apply=function(combat,state,item)x.observe('realApply',item);return original.apply(combat,state,item)end
    A.reactionRetained=original.reaction
    local card={uid=301,cardId='armaments'};x.aliases.card=card
    x.s.queuedCards={{card=card,targetIndex=1}};x.aliases.queued=x.s.queuedCards
    local resolve=x.api.resolveQueuedCard
    x.api.resolveQueuedCard=function(state,item)x.observe('realQueued',item);return resolve(state,item)end
end,function(x,r)
    eq(r[1],true,'real queued choice success');eq(r.n,1,'real queued choice arity');eq(x.s.pendingChoice~=nil,true,'real queued card pauses for choice')
    eq(x.s.queuedCards,x.aliases.queued,'choice preserves queued identity');eq(#x.aliases.queued,0,'queued card popped')
end,true)
run('full catalog real dispatch reentry then error',function(x)
    for k,v in pairs(C)do x.api[k]=v end
    A.reactionRetained=original.reaction
    local sentinel={label='real dispatch sentinel'};x.aliases.sentinel=sentinel
    x.s.cardActions={x.item('damageRandom','first'),x.item('block','second')};x.aliases.queue=x.s.cardActions
    A.apply=function(combat,state,item)
        x.observe('realApply',item);eq(table.pack(A.drain(combat,state)).n,0,'real dispatch guarded reentry')
        if item.label=='second'then error(sentinel)end
        return original.apply(combat,state,item)
    end
end,function(x,r)
    eq(r[1],false,'real dispatch error');eq(r[2],x.aliases.sentinel,'real dispatch error identity');eq(r.n,2,'real dispatch error arity')
    eq(x.s.drainingCardActions,true,'real error preserves owner');eq(#x.aliases.queue,0,'real error leaves popped queue');eq(x.s.cardActions,x.aliases.queue,'real error skips cleanup')
end,true)
A.apply=original.apply;A.reactionRetained=original.reaction;rareQueries.owns=original.owns;rare.onRefreshHand=original.refresh;silent.allowedAfterVictory=original.allowed;require=original.require
print('CARD_ACTION_DRAIN_PASS '..count)
