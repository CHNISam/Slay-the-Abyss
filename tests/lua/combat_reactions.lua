-- Independent pinned c1cf79dfa8e81189546d95277d3bb891d831ba6e admission oracle.
local Oracle={}
function Oracle.enqueue(state, effect, source, target, instance, top)
    state.cardActions = state.cardActions or {}
    local item = {effect=effect, source=source or state.player, target=target, instance=instance}
    if top then table.insert(state.cardActions, 1, item) else state.cardActions[#state.cardActions+1] = item end
end
function Oracle.enqueueReaction(state,effect,top)
    if state.actionQueue then
        local queue=require('abyss_action_queue')
        local action={kind='effect',effect=effect}
        if top then queue.pushTop(state,action)else queue.pushBottom(state,action)end
    else Oracle.enqueue(state,effect,nil,nil,nil,top)end
end
local forbidden={'abyss_actor','abyss_card_actions','abyss_combat','abyss_game_ui'}
local loaders={}
for _,name in ipairs(forbidden)do loaders[name]=package.preload[name];package.preload[name]=function()error('forbidden reaction dependency: '..name)end end
local ok,R=pcall(function()
 if ABYSS_REACTIONS_FILE then return assert(loadfile(ABYSS_REACTIONS_FILE))()end
 return require('abyss_combat_reactions')
end)
assert(ok,'independent Combat Reactions load failed: '..tostring(R))
for _,name in ipairs(forbidden)do assert(package.loaded[name]==nil,'reaction imported '..name);package.preload[name]=loaders[name]end
package.loaded.abyss_combat_reactions=R
local Q=require('abyss_action_queue')
local function eq(a,b,label)assert(a==b,(label or 'identity')..': '..tostring(a)..' ~= '..tostring(b))end
local function state(mode)
 local s={player={id='p'},cardActions={{effect={op='sentinel'}}},rng={seed=42},events={}}
 if mode~='legacy'then Q.start(s,{{kind='effect',effect={op='typedSentinel'}}})end
 if mode=='typed'then s.cardActions=nil end
 return s
end
local function check(module,mode)
 local s=state(mode);local legacy=s.cardActions;local typed=s.actionQueue;local first=legacy and legacy[1];local action=typed and typed.actions[1]
 local e1,e2,e3={op='a'},{op='b'},{op='c'}
 local rng=s.rng
 eq(module.enqueueReaction(s,e1),nil,'bottom return');eq(module.enqueueReaction(s,e2,true),nil,'top return');module.enqueueReaction(s,e3)
 eq(s.rng,rng);eq(s.rng.seed,42);eq(#s.events,0)
 if typed then
  eq(s.actionQueue,typed);eq(typed.actions[1].effect,e2);eq(typed.actions[2],action);eq(typed.actions[3].effect,e1);eq(typed.actions[4].effect,e3);eq(#typed.actions,4);eq(typed.current,nil);eq(typed.paused,false)
  eq(s.cardActions,legacy);if legacy then eq(#legacy,1);eq(legacy[1],first)end
 else
  eq(s.cardActions,legacy);eq(legacy[1].effect,e2);eq(legacy[2],first);eq(legacy[3].effect,e1);eq(legacy[4].effect,e3);eq(#legacy,4);eq(legacy[1].source,s.player)
 end
 local effect,target,instance,source={op='direct'},{id='target'},{uid=1},{id='source'}
 eq(module.enqueue(s,effect,source,target,instance,true),nil)
 local item=s.cardActions[1];eq(item.effect,effect);eq(item.source,source);eq(item.target,target);eq(item.instance,instance)
 module.enqueue(s,effect,false);eq(s.cardActions[#s.cardActions].source,s.player)
 return s
end
for _,mode in ipairs({'legacy','typed','both'})do check(Oracle,mode);check(R,mode)end
for _,bad in ipairs({{op='bad',callback=function()end},setmetatable({op='bad'},{})})do
 local _,old=pcall(Oracle.enqueueReaction,state('typed'),bad)
 local success,err=pcall(R.enqueueReaction,state('typed'),bad)
 eq(success,false,'typed invalid rejected');eq(tostring(err):match(': ([^:]+)$'),tostring(old):match(': ([^:]+)$'),'error contract')
end
local Cards=require('abyss_card_actions')
eq(Cards.enqueue,R.enqueue);eq(Cards.enqueueReaction,R.enqueueReaction)
local saved=Cards.enqueue
local seen=0
Cards.enqueue=function(s,e,source,target,instance,top)
 seen=seen+1;eq(source,nil);eq(target,nil);eq(instance,nil);eq(top,true)
 -- Reentrant restoration/replacement must affect the next admission immediately.
 Cards.enqueue=saved;saved(s,e,source,target,instance,top)
end
local s=state('legacy');Cards.enqueueReaction(s,{op='first'},true);Cards.enqueueReaction(s,{op='second'},true);eq(seen,1);eq(Cards.enqueue,saved)
local original=Cards.enqueueReaction
Cards.enqueueReaction=function(s,e,top)return 'intercepted'end
eq(R.enqueueReaction({},{}),'intercepted');Cards.enqueueReaction=original;eq(R.enqueueReaction,original)
-- Restore nil and non-forwarded assignments use the same Lua table semantics.
Cards.enqueue=nil;eq(R.enqueue,nil);Cards.enqueue=saved
Cards.reactionsProbe=7;eq(rawget(Cards,'reactionsProbe'),7);Cards.reactionsProbe=nil
print('combat_reactions: oracle, identity, priority, independence, dynamic restoration PASS')
