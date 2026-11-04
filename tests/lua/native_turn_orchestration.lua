-- Real native turn entry, live action execution, and deterministic mutable graph.
package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Actor=require('abyss_combat'),require('abyss_card_actions'),require('abyss_actor')
local Data=require('abyss_data')
local count,trace=0,{}
local function eq(a,b,label)assert(a==b,'[NATIVE_TURN] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function graph(v,seen)
 if type(v)=='function'then return 'function'end
 if type(v)=='number'then return 'number:'..string.format('%.17g',v)end
 if type(v)~='table'then return type(v)..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do if k~='catalog'and k~='rules'and k~='sourcePools'and k~='statusDefinitions'then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=graph(k,seen)..'='..graph(v[k],seen)end
 return '{'..table.concat(rows,';')..'}'
end
local enqueue=A.enqueue
A.enqueue=function(s,e,...)
 trace[#trace+1]=graph(e)
 return enqueue(s,e,...)
end
local function battle()
 local s=C.new(Data,{seed=42,deck={'strike','defend','bash'},enemies={'cultist'},shuffleSeed='42',cardRandomSeed='42'})
 s.experimentalMechanics=false;s.turn=1;s.phase='enemy';s.events={};s.cardActions=nil
 s.hand={};s.draw={{uid=101,cardId='strike'},{uid=102,cardId='defend'},{uid=103,cardId='bash'}}
 s.discard={{uid=201,cardId='defend'},{uid=202,cardId='strike'}};s.exhaust={}
 s.nextUid=1000;s.player.noDraw=true;s.player.block=8
 s.testAliases={player=s.player,first=s.draw[1],discard=s.discard,shuffle=s.shuffleRng}
 trace={}
 return s
end
local function run(s,callback)
 local result=table.pack(pcall(C.startPlayerTurn,s,callback))
 if ABYSS_NATIVE_TURN_TRACE then print('NATIVE_TURN_TRACE '..graph({state=s,result=result,enqueue=trace}))end
 return table.unpack(result,1,result.n)
end
local function test(name,fn)
 if ABYSS_NATIVE_TURN_CASE and ABYSS_NATIVE_TURN_CASE~=name then return end
 fn();count=count+1;print('ok native turn '..count..' '..name)
end

test('normal',function()
 local s=battle();local first=s.draw[1];local turn=s.turn
 local called,ok=run(s)
 eq(called,true,'normal called');eq(ok,true,'normal success');eq(s.turn,turn+1,'turn advanced')
 eq(s.phase,'player','player phase');eq(s.player.noDraw,false,'draw reset');eq(s.player.block,0,'block reset')
 eq(s.energy,3,'ordinary recharge');eq(#s.hand,5,'ordinary draw and reshuffle')
 eq(s.testAliases.first,first,'original card reference');eq(s.testAliases.player,s.player,'player reference')
 eq(s.events[#s.events].kind,'player_turn','turn event after drain')
end)
test('powers',function()
 local s=battle();local p=s.player
 for _,entry in ipairs({{'rage',2},{'flame_barrier',3},{'double_tap',1},{'berserk',2},{'demon_form',3},{'brutality',1}})do
  Actor.status(s,p,entry[1],entry[2],p,false)
 end
 p.powerOrder={'berserk','demon_form','brutality','rage','flame_barrier','double_tap'}
 trace={};local hp=p.hp;local called,ok=run(s)
 eq(called,true,'powers called');eq(ok,true,'powers success')
 eq(p.statuses.rage,nil,'rage cleared');eq(p.statuses.flame_barrier,nil,'barrier cleared');eq(p.statuses.double_tap,nil,'double tap cleared')
 eq(p.statuses.strength,3,'Demon Form strength');eq(s.energy,5,'Berserk energy');eq(p.hp,hp-1,'Brutality loses HP')
 eq(trace[1],graph({op='energy',value=2}),'first applied Power order')
 eq(trace[2],graph({op='gainStatus',status='strength',value=3}),'second applied Power order')
 eq(trace[#trace-1],graph({op='draw',value=1}),'Brutality draw first')
 eq(trace[#trace],graph({op='loseHp',value=1}),'Brutality HP loss second')
end)
test('opening',function()
 local s=battle();s.turn=0;s.openingInnateExtra=2;s.relics={'toolbox'}
 local called,ok=run(s)
 eq(called,true,'opening called');eq(ok,true,'opening success');eq(s.openingInnateExtra,nil,'innate extra consumed')
 eq(trace[1],graph({op='shopRelic',kind='toolbox'}),'Toolbox before ordinary draw')
 eq(trace[2],graph({op='draw',value=5}),'ordinary opening draw')
 eq(trace[3],graph({op='draw',value=2}),'extra innate draw follows ordinary')
end)
test('later-innate',function()
 local s=battle();s.openingInnateExtra=2;s.relics={'toolbox'}
 local called,ok=run(s);eq(called,true,'later called');eq(ok,true,'later success')
 eq(s.openingInnateExtra,2,'later turn retains unused opening marker')
 eq(trace[1],graph({op='draw',value=5}),'later turn omits Toolbox and innate extra')
end)
test('post-draw-hooks',function()
 local s=battle();s.relics={'warped_tongs'}
 s.draw[#s.draw+1]={uid=104,cardId='wound'}
 Actor.status(s,s.player,'evolve',1,s.player,false);trace={}
 local called,ok=run(s);eq(called,true,'post draw called');eq(ok,true,'post draw success')
 eq(trace[1],graph({op='draw',value=5}),'ordinary draw admitted first')
 eq(trace[2],graph({op='relicUpgradeRandomHand'}),'post-draw relic admitted before draw hooks execute')
 eq(trace[3],graph({op='draw',value=1}),'Evolve hook appended behind post-draw relic')
 local upgraded=0;for _,card in ipairs(s.hand)do if card.upgraded then upgraded=upgraded+1 end end
 eq(upgraded,1,'post-draw upgrade sees newly drawn hand')
end)
test('callback-refusal',function()
 local s=battle();local before=#s.events
 local called,ok,why=run(s,function(state)state.callbackTouched=state.player;return false,'turn_refused'end)
 eq(called,true,'refusal normal return');eq(ok,false,'refusal result');eq(why,'turn_refused','refusal reason')
 eq(#trace,0,'refusal stops all action enqueue');eq(s.callbackTouched,s.player,'callback side effect preserved')
 eq(#s.hand,0,'refusal before draw');assert(#s.events>=before,'[NATIVE_TURN] prior events retained')
end)
test('callback-throw',function()
 local s=battle();local called,why=run(s,function(state)state.callbackTouched=state.player;error('native_turn_callback_throw',0)end)
 eq(called,false,'callback throw propagates');eq(why,'native_turn_callback_throw','exact callback error')
 eq(#trace,0,'throw stops enqueue');eq(s.callbackTouched,s.player,'throw preserves original nontransactional side effects')
end)
test('callback-overflow',function()
 local s=battle();local called,ok,why=run(s,function(state)state.energy=2147483647;return true end)
 eq(called,true,'callback overflow return');eq(ok,false,'callback overflow rejected');eq(why,'effect_overflow','overflow reason')
 eq(#trace,0,'callback overflow stops enqueue');eq(s.energy,2147483647,'overflow not applied')
end)
test('relic-overflow',function()
 local s=battle();s.relics={'ice_cream'};s.energy=2147483647
 local called,ok,why=run(s)
 eq(called,true,'relic overflow return');eq(ok,false,'relic overflow rejected');eq(why,'effect_overflow','relic overflow reason')
 eq(#trace,0,'relic overflow before Powers/draw');eq(s.energy,2147483647,'ordinary overflow not applied')
end)
test('already-finished',function()
 local s=battle();s.player.hp=0;local turn=s.turn
 local called,ok=run(s,function()error('must not call opening callback')end)
 eq(called,true,'finished return');eq(ok,nil,'finished no result');eq(s.phase,'defeat','finished phase')
 eq(s.turn,turn,'finished does not advance turn');eq(#trace,0,'finished no queued actions')
end)
test('start-effect-defeat',function()
 local s=battle();s.player.hp=1;Actor.status(s,s.player,'poison',2,s.player,false);trace={}
 local called,ok=run(s,function()error('must not call callback after start-turn defeat')end)
 eq(called,true,'start effect defeat return');eq(ok,nil,'start effect defeat no result')
 eq(s.phase,'defeat','start effect defeat phase');eq(s.turn,2,'start effect advances turn before defeat')
 eq(#trace,0,'start effect defeat queues no draws')
end)
test('original-v4',function()
 local Profiles=require('abyss_original_v4_profiles')
 local s=C.new(Profiles.prepare(Data,'RD'),{seed=42,deck={},enemies={'cultist'}})
 s.experimentalMechanics=false;s.events={};s.turn=1;s.phase='enemy';s.player.block=10
 s.originalV4.nextEnergy=2;s.originalV4.nextBlock=4;s.originalV4.nextDraw=2
 s.originalV4.chargedUsed=1;s.originalV4.musouRefunded=1;trace={}
 local called,ok=run(s)
 eq(called,true,'V4 called');eq(ok,true,'V4 success');eq(s.energy,5,'V4 recharge and next energy')
 eq(s.player.block,4,'V4 block after reset');eq(s.originalV4.nextEnergy,0,'V4 energy consumed')
 eq(s.originalV4.nextDraw,0,'V4 extra draw consumed');eq(s.originalV4.nextBlock,0,'V4 block consumed')
 eq(trace[1],graph({op='draw',value=7}),'V4 extra draw in ordinary draw action')
 eq(s.originalV4.chargedUsed,0,'V4 per-turn reset');eq(s.originalV4.musouRefunded,0,'V4 refund reset')
end)
print('NATIVE_TURN_ORCHESTRATION_PASS '..count)
