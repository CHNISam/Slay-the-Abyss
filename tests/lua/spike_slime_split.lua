-- Source-derived split lifecycle, through actual Combat/Run entry points.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D,Run=require('abyss_combat'),require('abyss_data'),require('abyss_run')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why))) end
local function battle(ids) return C.new(D,{enemies=ids or {'spike_slime_l'},deck={'strike'},seed=42}) end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error('missing intent '..id)end
local function damage(s,n) return C.damage(s,s.player,s.enemies[1],n,true) end
local function ready(s,hp) local e=s.enemies[1];damage(s,e.hp-(hp or 30));eq(C.intent(s,1).kind,'split');return e end
local function observe(fn)
 local old,calls=C.random,{};C.random=function(s,n)calls[#calls+1]=n;old(s,n);return 1 end
 local ok,why=pcall(fn,calls);C.random=old;assert(ok,why)
end
local function count(s,id)local n=0;for _,p in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(p)do if c.cardId==id then n=n+1 end end end;return n end
test('even and odd maxHP use exact half threshold and interrupt without spawning',function()
 for _,max in ipairs({64,65,70})do local s=battle();local e=s.enemies[1];e.hp=max;e.maxHp=max;damage(s,max-math.floor(max/2)-1);assert(C.intent(s,1).kind~='split');damage(s,1);eq(C.intent(s,1).kind,'split');eq(#s.enemies,1);eq(e.hp,math.floor(max/2));eq(s.phase,'player')end
end)
test('child HP captures remaining HP on split turn, not original trigger amount',function()
 local s=battle();local p=ready(s,30);damage(s,7);assert(C.endTurn(s));eq(#s.enemies,3);eq(s.enemies[2],p);eq(p.hp,0)
 for _,i in ipairs({1,3})do local c=s.enemies[i];eq(c.definitionId,'spike_slime_m');eq(c.hp,23);eq(c.maxHp,23);eq(c.block,0);eq(next(c.statuses),nil)end
 eq(s.player.hp,80);eq(count(s,'slimed'),0);eq(s.phase,'player');eq(s.turn,2)
end)
test('split child ctor skips HP draws and child init rolls precede parent roll',function()
 observe(function(calls)local s=battle();local p=ready(s);local before=#calls;assert(C.endTurn(s));eq(#calls-before,3);for i=before+1,#calls do eq(calls[i],100)end;eq(C.intent(s,1).id,'spike_slime_m_1');eq(C.intent(s,3).id,'spike_slime_m_1');eq(p.spikeLast,'spike_slime_l_split')end)
end)
test('children receive new identities, independent histories and no parent powers',function()
 local s=battle({'spike_slime_l','spike_slime_m'});local p=ready(s);local ally=s.enemies[2];C.addStatus(p,'strength',6);C.addStatus(p,'weak',3);C.addStatus(p,'poison',2);p.spikeLast='spike_slime_l_1';p.block=9
 assert(C.endTurn(s));eq(s.enemies[2],p);eq(s.enemies[4],ally);local seen={};for _,e in ipairs(s.enemies)do assert(not seen[e.id]);seen[e.id]=true end
 for _,i in ipairs({1,3})do local c=s.enemies[i];eq(c.hp,28);eq(next(c.statuses),nil);eq(c.spikeLast,nil);assert(c~=p and c.statuses~=p.statuses and c.statuses~=ally.statuses)end
end)
test('snapshot action queue preserves later teammate and skips newborns',function()
 observe(function()local s=battle({'spike_slime_l','sneaky_gremlin'});local ally=s.enemies[2];ready(s);s.events={};assert(C.endTurn(s));eq(s.player.hp,71);local actions={};for _,e in ipairs(s.events)do if e.kind=='intent' then actions[#actions+1]=e.detail.enemy end end;eq(#actions,2);eq(actions[2],ally.id);eq(count(s,'slimed'),0);assert(C.endTurn(s));eq(s.player.hp,46);eq(count(s,'slimed'),2)end)
end)
test('poison crossing threshold executes split this turn with post-poison HP',function()
 local s=battle();local p=s.enemies[1];p.hp=40;p.maxHp=70;C.addStatus(p,'poison',7);assert(C.endTurn(s));eq(#s.enemies,3);eq(s.enemies[1].hp,33);eq(s.enemies[3].hp,33);eq(s.player.hp,80)
end)
test('retaliation interruption preserves queued Slimed and roll before next-turn split',function()
 observe(function(calls)local s=battle();local p=s.enemies[1];p.hp=40;p.maxHp=70;force(p,'spike_slime_l_1');C.addStatus(s.player,'thorns',6);local n=#calls;assert(C.endTurn(s));eq(p.hp,34);eq(count(s,'slimed'),2);eq(C.intent(s,1).kind,'split');eq(#s.enemies,1);local rolls=0;for i=n+1,#calls do if calls[i]==100 then rolls=rolls+1 end end;eq(rolls,1);eq(p.spikeLast,'spike_slime_l_split');assert(C.endTurn(s));eq(#s.enemies,3);eq(s.enemies[1].hp,34);eq(s.player.hp,64)end)
end)
test('later lethal player hit cancels triggered split and gives no spawn',function()
 local s=battle();ready(s);damage(s,99);eq(C.outcome(s),'victory');eq(#s.enemies,1);assert(C.endTurn(s));eq(s.phase,'victory');eq(#s.enemies,1)
end)
test('lethal poison cancels pending split without child or action roll',function()
 observe(function(calls)local s=battle();local p=ready(s);C.addStatus(p,'poison',99);local n=#calls;assert(C.endTurn(s));eq(s.phase,'victory');eq(#s.enemies,1);eq(#calls,n)end)
end)
test('split destruction does not trigger death powers or premature victory',function()
 local s=battle();local p=ready(s);C.addStatus(p,'spore_cloud',2);s.events={};assert(C.endTurn(s));eq(s.player.statuses.vulnerable or 0,0);eq(C.outcome(s),nil);eq(s.phase,'player');for _,e in ipairs(s.events)do assert(e.kind~='victory')end
end)
test('new actors do not rewrite old detached event frames',function()
 local s=battle();local p=ready(s);local prior=s.events[#s.events].frame;local oldid=prior.enemies[1].id;assert(C.endTurn(s));eq(#prior.enemies,1);eq(prior.enemies[1].id,oldid);eq(prior.enemies[1].hp,30);C.addStatus(s.enemies[1],'strength',2);eq(next(prior.enemies[1].statuses),nil)
end)
test('real Run holds rewards until both children die and awards only once',function()
 local r=Run.new(D,42);r.floor=4;assert(Run.startCombat(r,'large_spike'));local s=r.combat;ready(s);local gold,victories=r.gold,r.victories;assert(Run.endTurn(r));eq(r.phase,'combat');eq(r.gold,gold);eq(r.victories,victories)
 s.hand={{uid=s.nextUid,cardId='bludgeon'}};s.nextUid=s.nextUid+1;s.energy=3;assert(Run.play(r,s.hand[1].uid,1));eq(r.phase,'combat');eq(r.gold,gold)
 s.hand={{uid=s.nextUid,cardId='bludgeon'}};s.nextUid=s.nextUid+1;s.energy=3;assert(Run.play(r,s.hand[1].uid,3));eq(r.phase,'reward');eq(r.victories,victories+1);eq(r.gold,gold)
 eq(r.rewards.gold,D.rules.rewards.normalGold);eq(r.rewards.goldClaimed,false)
 assert(Run.claimGoldReward(r));eq(r.gold,gold+D.rules.rewards.normalGold);eq(r.rewards.goldClaimed,true)
 local after,rewards,uid=r.gold,r.rewards,r.nextDeckUid
 local ok,why=Run.claimGoldReward(r);eq(ok,false);eq(why,'no_pending_gold')
 eq(r.gold,after);eq(r.rewards,rewards);eq(r.nextDeckUid,uid);eq(r.victories,victories+1);eq(r.phase,'reward')
 assert(not Run.endTurn(r));eq(r.gold,after)
end)
test('failed multi-effect card restores split flag intent and event references',function()
 local s=battle();local p=s.enemies[1];p.hp=36;p.maxHp=70;s.catalog.cards.strike.effects={{op='damage',value=6},{op='block',value=5}};local intent=p.intentIndex;local events=s.events;local n=#events;local old=C.block;C.block=function()error('SPLIT_ROLLBACK')end
 local ok,why=pcall(C.play,s,s.hand[1].uid,1);C.block=old;eq(ok,false);assert(tostring(why):find('SPLIT_ROLLBACK',1,true));eq(p.hp,36);eq(p.intentIndex,intent);assert(not p.splitTriggered);eq(s.events,events);eq(#events,n);eq(s.enemies[1],p);assert(C.play(s,s.hand[1].uid,1));eq(C.intent(s,1).kind,'split')
end)
test('below-half zero damage interrupts but plain endTurn without damage does not',function()
 local s=battle();local p=s.enemies[1];p.hp=30;p.maxHp=70;force(p,'spike_slime_l_2');assert(C.endTurn(s));assert(not p.splitTriggered);damage(s,0);eq(C.intent(s,1).kind,'split')
end)
test('blocked normal Thorns still counts as a damage callback for split',function()
 local s=battle();local p=s.enemies[1];p.hp=32;p.maxHp=64;p.block=5;C.addStatus(s.player,'thorns',1);C.damage(s,p,s.player,16);eq(p.hp,32);eq(p.block,4);eq(C.intent(s,1).kind,'split')
end)
test('dead attacker cannot manufacture a damage callback on a live half-HP target',function()
 local s=battle({'spike_slime_l','spike_slime_m'});local p=s.enemies[1];p.hp=30;p.maxHp=70;s.enemies[2].hp=0;C.damage(s,s.enemies[2],p,0);assert(not p.splitTriggered);C.retaliate(s,s.enemies[2],p,0);eq(C.intent(s,1).kind,'split')
end)
test('real targeted fire potion interrupts and retains subsequent card damage',function()
 local r=Run.new(D,42);r.floor=4;assert(Run.startCombat(r,'large_spike'));local p=r.combat.enemies[1];p.hp=40;p.maxHp=70;assert(Run.obtainPotion(r,'fire_potion'));assert(Run.usePotion(r,1,1));eq(r.combat.enemies[1].hp,20);eq(C.intent(r.combat,1).kind,'split');eq(#r.combat.enemies,1);damage(r.combat,5);assert(Run.endTurn(r));eq(r.combat.enemies[1].hp,15)
end)
test('first and second child opening rolls occur before the retained parent roll',function()
 local s=battle();ready(s);local old,trace=C.random,{};C.random=function(st,n)if n==100 then trace[#trace+1]={count=#st.enemies, dead=st.enemies[#trace+1==1 and 1 or 2].hp==0} end;return old(st,n)end
 local ok,why=pcall(C.endTurn,s);C.random=old;assert(ok,why);eq(#trace,3);for i,row in ipairs(trace)do eq(row.count,i);eq(row.dead,true)end
end)
print(passed..' split groups passed; '..failed..' failed');assert(failed==0)
