package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A=require('abyss_run'),require('abyss_combat'),require('abyss_actor')
local Data=require('abyss_data')
local n=0
local prototypes={}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'unexpected '..tostring(k)) end
end
local function test(name,fn) fn();n=n+1;print('ok basic five '..n..' - '..name) end
local function battle(ids,source,encounter)
 source=source or Data
 -- Each case receives its own untouched Run.new result. Cache the initial
 -- snapshot to avoid repeatedly constructing the unrelated encounter queue.
 if not prototypes[source] then prototypes[source]=Run.new(source,42) end
 local run=C.copy(prototypes[source])
 for _,id in ipairs(ids or {}) do assert(Run.obtainPotion(run,id)) end
 if encounter then assert(Run.startCombat(run,encounter)) else assert(Run.startRoomCombat(run,'normal')) end
 return run
end
local function refuse(run,slot,target,why)
 local before=C.copy(run);local combat,potions,deck=run.combat,run.potions,run.deck
 local ok,reason=Run.usePotion(run,slot,target);eq(ok,false);eq(reason,why)
 same(run,before);eq(run.combat,combat);eq(run.potions,potions);eq(run.deck,deck)
end
local function starter(cards)
 local d=C.copy(Data);d.cards.starter_deck.cards=cards;return d
end
local function use(run,slot,target)
 local energy,uid,deck=run.combat.energy,run.nextDeckUid,C.copy(run.deck)
 assert(Run.usePotion(run,slot,target));eq(run.combat.energy,energy);eq(run.nextDeckUid,uid);same(run.deck,deck)
 assert(not run.potions[slot]);refuse(run,slot,target,'empty_potion_slot')
end
local function finish(expected,marker) assert(n==expected);print(marker..' '..n) end
return {Run=Run,C=C,A=A,Data=Data,test=test,eq=eq,same=same,battle=battle,refuse=refuse,starter=starter,use=use,finish=finish}
