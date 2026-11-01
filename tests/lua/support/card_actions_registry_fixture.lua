package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_card_actions')
local data=require('abyss_data')
local function serialize(v,seen)
    if type(v)=='function'then return 'function'end
    if type(v)~='table'then return type(v)..':'..tostring(v)end
    seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
    seen.n=seen.n+1;seen[v]=seen.n
    local keys={};for k in pairs(v)do
        if k~='catalog'and k~='rules'and k~='sourcePools'and k~='statusDefinitions'then keys[#keys+1]=k end
    end
    table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
    local out={};for _,k in ipairs(keys)do out[#out+1]=serialize(k,seen)..'='..serialize(v[k],seen)end
    return '{'..table.concat(out,';')..'}'
end
local function battle()
    local s=C.new(data,{seed=42,deck={'strike'},enemies={'cultist'},cardRandomSeed='42'})
    s.hand={{uid=101,cardId='strike',upgraded=false},{uid=102,cardId='defend',upgraded=false}}
    s.draw={};s.discard={};s.exhaust={};s.cardActions=nil
    return s
end
if ABYSS_REGISTRY_PROFILE then
    local plated=require('abyss_plated_armor')
    local act2=require('abyss_act2_powers')
    local watcher=require('abyss_watcher_final_cards')
    local originalPlated,originalAct2,originalOps=plated.supports,act2.supports,watcher.ops
    local originalRequire=require
    for _,op in ipairs({'heal','block','exhaustRandom','upgradeHand','doubleStrength','damageRandom','effectBatch'})do
        local s=battle()
        local calls={plated=0,act2=0,watcherRequire=0,watcherOps=0}
        plated.supports=function(key)calls.plated=calls.plated+1;return originalPlated(key)end
        act2.supports=function(key)calls.act2=calls.act2+1;return originalAct2(key)end
        watcher.ops=setmetatable({},{__index=function(_,key)calls.watcherOps=calls.watcherOps+1;return originalOps[key]end})
        require=function(name)
            if name=='abyss_watcher_final_cards'then calls.watcherRequire=calls.watcherRequire+1 end
            return originalRequire(name)
        end
        A.apply(C,s,{effect={op=op,value=1,all=true,effects={}},source=s.player,target=s.enemies[1]})
        require=originalRequire;watcher.ops=originalOps
        plated.supports,act2.supports=originalPlated,originalAct2
        print('PROFILE '..op..' '..calls.plated..' '..calls.act2..' '..calls.watcherRequire..' '..calls.watcherOps)
    end
    return
end
local cases={
    {op='upgradeHand',all=true},{op='upgradeHand'}, {op='exhaustChoose'},
    {op='exhaustMany',value=1},{op='discardRedraw',value=1},
    {op='discardToHand',value=1},{op='recoverExhaust'}, {op='dualWield',value=1},
    {op='block',value=3,fixed=true},{op='block',value=3},
    {op='damage',value=3},{op='effectBatch',effects={{op='block',value=2}}},
    {op='doubleStrength'},{op='spotWeakness',value=2},
    {op='damageRandom',value=2,times=2},{op='reaper',value=3},
    {op='heal',value=3},{op='feed',value=999,maxHp=3},
    {op='obtainPotion',id='fire_potion',unavailable=true},
    {op='resolveCurlUp',targetId='missing',value=3},
}
for i,e in ipairs(cases)do
    local s=battle();s.player.hp=s.player.hp-5;s.player.statuses.strength=2
    local item={effect=e,source=s.player,target=s.enemies[1],instance=s.hand[1]}
    local result=table.pack(A.apply(C,s,item))
    print('REGISTRY '..i..' '..serialize({result=result,state=s}))
    if s.pendingChoice then
        local r=table.pack(A.choose(C,s,s.pendingChoice.token,s.hand[1].uid))
        print('CHOICE '..i..' '..serialize({result=r,state=s}))
    end
end
-- Real battle state and exact caller identity, with sentinel combat return
-- values to expose tail-return vs deliberately discarded return semantics.
for _,op in ipairs({'staticRetaliation','enemyAction','heartBeat','capturedSharpHide','dispose','unknownRegistryProbe','block'})do
    local s=battle();local api={};for k,v in pairs(C)do api[k]=v end
    local item={effect={op=op,value=2},source=s.player,target=s.enemies[1],instance=s.hand[1]}
    local calls={}
    local function called(...)
        local args=table.pack(...);assert(args[1]==s,'source state identity')
        calls[#calls+1]=args
        return false,'sentinel',nil,9
    end
    for _,name in ipairs({'staticRetaliation','resolveEnemyAction','heartBeat','capturedSharpHide','disposeCard','applyEffects'})do api[name]=called end
    local result=table.pack(A.apply(api,s,item))
    print('RETURN '..op..' '..serialize({result=result,calls=calls}))
end
for _,op in ipairs({'heal','block','damageRandom','upgradeHand','staticRetaliation','dispose','resolveCurlUp','unknownRegistryProbe'})do
    local s=battle();s.enemies[1].hp=0
    local calls={};local api={};for k,v in pairs(C)do api[k]=v end
    api.applyEffects=function(_,effects)calls[#calls+1]=effects end
    api.staticRetaliation=function()calls[#calls+1]='retaliate'end
    api.disposeCard=function()calls[#calls+1]='dispose'end
    A.enqueue(s,{op=op,value=1},s.player,s.enemies[1],s.hand[1])
    A.drain(api,s)
    print('VICTORY '..op..' '..serialize({state=s,calls=calls}))
end
print('CARD_ACTION_REGISTRY_PASS')
