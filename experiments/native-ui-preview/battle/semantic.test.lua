local S=require('semantic')
assert(type(S.new)=='function','semantic bridge must create real Run/Combat fixture')
local a=S.new()
assert(a.run.phase=='combat' and #a.run.combat.hand==5)
local b=a.run.combat
local function find(id)for i,c in ipairs(b.hand)do if c.cardId==id then return i,c end end end
local slot,c=find('strike');assert(slot)
local token=a:capture(slot,true)
local hp,energy=b.enemies[1].hp,b.energy
assert(not a:submit(token,99,'invalid'),'invalid target rejected')
assert(b.enemies[1].hp==hp and b.energy==energy,'invalid target has no state mutation')
assert(a:submit(token,1,'one'),'valid card uses real Run.play')
assert(b.enemies[1].hp==hp-6 and b.energy==energy-1,'core settles damage and cost')
assert(not a:submit(token,1,'two'),'consumed token cannot submit twice')
assert(b.enemies[1].hp==hp-6 and b.energy==energy-1,'duplicate does not spend twice')
local foundPlay,foundDamage=false,false
for _,e in ipairs(a.queue)do assert(e.frame,'immutable event frame required');foundPlay=foundPlay or e.kind=='play';foundDamage=foundDamage or e.kind=='damage' end
assert(foundPlay and foundDamage)
assert(not a:submit(a:capture(2,true),nil,'busy'),'busy gate rejects overlapping command')
for i=1,28 do a:update(1/60)end
assert(not a.busy,'feedback gate releases')
assert(#a.effects==1 and a.effects[1].age<.6,'action gate releases before damage VFX tail')
local retained=a.effects[1]
slot,c=find('defend');local cancel=a:capture(slot,true)
S.input.sample(cancel,0,0,nil,false);S.input.sample(cancel,0,-300,nil,false)
assert(S.input.release(cancel,true)=='cancel','return-to-hand cancels')
local unchanged=b.energy;a:cancel(cancel);assert(b.energy==unchanged)
local stale=a:capture(slot,true);stale.turn=stale.turn-1
assert(not a:submit(stale,nil,'stale'),'stale battle token rejected')
local g={sx=0,sy=-300,elapsed=0};S.input.begin(g,720,true,1280)
for i=1,4 do g.elapsed=i/60;g.x,g.y=i*2,-300+i*25;S.intent.sample(g,g.x,g.y)end
assert(S.intent.flick(g),'mature upward flick classifier retained')
g.aiming=true;assert(not S.intent.flick(g),'targeted aim never auto flicks')
slot,c=find('defend');assert(a:submit(a:capture(slot,true),nil,'defend'))
assert(b.player.block==5,'real core block')
assert(a.effects[1]==retained,'next command preserves prior independent VFX')
for i=1,60 do a:update(1/60)end
assert(not a.busy)
local elapsed={};for i=1,8 do local x=S.new();local k=x:find('strike');local t=os.clock();assert(x:submit(x:capture(k,true),1,'perf'..i));elapsed[i]=(os.clock()-t)*1000 end
table.sort(elapsed);print('SEMANTIC_PASS checks=16 input_events=0 command_ms_p50='..elapsed[4]..' command_ms_max='..elapsed[8])
