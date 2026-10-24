-- Fixed-source death reaction boundaries, not a general action queue.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Run,Data=require('abyss_combat'),require('abyss_actor'),require('abyss_run'),require('abyss_data')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b) if type(a)~='table' then return eq(a,b) end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why))) end
local function battle(ids,deck)
 local s=C.new(Data,{enemies=ids or {'fungi_beast','fungi_beast'},deck=deck or {'strike'},seed=42})
 for _,e in ipairs(s.enemies)do e.intentIndex=1 end
 s.events={};return s
end
local function play(s,id,target) for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid,target));return end end;error('missing card '..id)end
local function vuln(s) return s.player.statuses.vulnerable or 0 end
local function events(s,status) local found={};for _,e in ipairs(s.events)do if e.kind=='status' and e.detail.status==status then found[#found+1]=e end end;return found end
local function sequence(s)
 local result={};for _,e in ipairs(s.events)do
  if e.kind=='damage' then result[#result+1]='damage:'..e.detail.target
  elseif e.kind=='status_damage' then result[#result+1]=e.detail.status..':'..e.detail.target
  elseif e.kind=='status' then result[#result+1]=e.detail.status..':'..e.detail.target end
 end;return table.concat(result,',')
end

test('each real Fungi starts with independent visible death power2',function()
 local s=battle();for _,e in ipairs(s.enemies)do eq(e.statuses.spore_cloud,2);local found=false;for _,v in ipairs(C.statusView(e))do if v.id=='spore_cloud' then found=true;eq(v.amount,2);eq(v.decay,'none');assert(v.description:find('易伤',1,true))end end;assert(found)end
 C.addStatus(s.enemies[1],'spore_cloud',1);eq(s.enemies[2].statuses.spore_cloud,2);eq(s.catalog.enemies.fungi_beast.ai.sporeCloudStacks,2)
end)
test('Strike kill applies source-null Vulnerable before next action and only once',function()
 local s=battle();local e=s.enemies[1];e.hp=6;play(s,'strike',1);eq(e.hp,0);eq(vuln(s),2);eq(s.player.vulnerableJustApplied,nil)
 eq(sequence(s),'damage:'..e.id..',vulnerable:player');eq(events(s,'vulnerable')[1].detail.source,nil)
 C.damage(s,s.player,e,99);C.retaliate(s,s.player,e,99);eq(vuln(s),2);eq(#events(s,'vulnerable'),1)
 assert(C.endTurn(s));eq(s.player.hp,71);eq(vuln(s),1)
end)
test('nonlethal, blocked and non-Fungi deaths do not trigger',function()
 local s=battle({'fungi_beast','sneaky_gremlin'});local e=s.enemies[1];C.damage(s,s.player,e,1);eq(vuln(s),0);e.block=99;C.damage(s,s.player,e,1);eq(vuln(s),0)
 C.damage(s,s.player,s.enemies[2],99);eq(vuln(s),0)
end)
test('final single kill does not apply or consume Artifact',function()
 local s=battle({'fungi_beast'});s.enemies[1].hp=6;C.addStatus(s.player,'artifact',1);play(s,'strike',1);eq(s.phase,'victory');eq(vuln(s),0);eq(s.player.statuses.artifact,1);eq(#events(s,'vulnerable'),0)
end)
test('Artifact blocks one whole death application without Vulnerable timing',function()
 local s=battle();s.enemies[1].hp=6;C.addStatus(s.player,'artifact',1);play(s,'strike',1)
 eq(s.player.statuses.artifact,0);eq(vuln(s),0);eq(s.player.vulnerableJustApplied,nil);eq(#events(s,'artifact'),1);eq(events(s,'artifact')[1].detail.blockedStatus,'vulnerable')
end)
test('Spore is above same victim Thorns even if retaliation kills player',function()
 local s=battle();s.enemies[1].hp=6;s.player.hp=1;C.addStatus(s.enemies[1],'thorns',1);play(s,'strike',1)
 eq(vuln(s),2);eq(s.player.hp,0);eq(s.phase,'defeat');eq(sequence(s),'damage:'..s.enemies[1].id..',vulnerable:player,thorns:player')
end)
test('dead player cancels death application without spending Artifact',function()
 local s=battle();s.enemies[1].hp=1;s.player.hp=0;C.addStatus(s.player,'artifact',1);C.retaliate(s,s.player,s.enemies[1],1)
 eq(s.enemies[1].hp,0);eq(vuln(s),0);eq(s.player.statuses.artifact,1);eq(#events(s,'vulnerable'),0)
end)
test('Cleave finishes area damage before applying a surviving battle death',function()
 local s=battle(nil,{'cleave'});s.enemies[1].hp=8;local hp=s.enemies[2].hp;play(s,'cleave')
 eq(s.enemies[2].hp,hp-8);eq(vuln(s),2);eq(sequence(s),'damage:'..s.enemies[1].id..',damage:'..s.enemies[2].id..',vulnerable:player')
 for _,e in ipairs(s.events)do if e.kind=='damage' then eq(e.frame.player.statuses.vulnerable or 0,0) end end
end)
test('all-killed AoE clears earlier queued Spore but retains Thorns',function()
 local s=battle(nil,{'cleave'});C.addStatus(s.player,'artifact',1)
 for _,e in ipairs(s.enemies)do e.hp=8;C.addStatus(e,'thorns',1)end
 play(s,'cleave');eq(s.phase,'victory');eq(s.player.hp,78);eq(vuln(s),0);eq(s.player.statuses.artifact,1);eq(#events(s,'artifact'),0)
end)
test('two AoE deaths consume one Artifact then apply one remaining Spore',function()
 local s=battle({'fungi_beast','fungi_beast','sneaky_gremlin'},{'cleave'});s.enemies[1].hp=8;s.enemies[2].hp=8;C.addStatus(s.player,'artifact',1)
 play(s,'cleave');eq(vuln(s),2);eq(s.player.statuses.artifact,0);eq(#events(s,'artifact'),1);eq(#events(s,'vulnerable'),1)
 eq(sequence(s),'damage:'..s.enemies[1].id..',damage:'..s.enemies[2].id..',damage:'..s.enemies[3].id..',artifact:player,vulnerable:player')
end)
test('two deaths without Artifact each stack separately, no shared passive state',function()
 local s=battle({'fungi_beast','fungi_beast','sneaky_gremlin'},{'cleave'});s.enemies[1].hp=8;s.enemies[2].hp=8;play(s,'cleave');eq(vuln(s),4);eq(#events(s,'vulnerable'),2)
end)
test('later-target lethal Thorns runs before earlier-target Spore and cancels it',function()
 local s=battle(nil,{'cleave'});s.enemies[1].hp=8;s.player.hp=1;C.addStatus(s.enemies[2],'thorns',1);C.addStatus(s.player,'artifact',1)
 play(s,'cleave');eq(s.phase,'defeat');eq(vuln(s),0);eq(s.player.statuses.artifact,1)
end)
test('later-target Spore runs before earlier-target lethal Thorns',function()
 local s=battle(nil,{'cleave'});s.enemies[2].hp=8;s.player.hp=1;C.addStatus(s.enemies[1],'thorns',1)
 play(s,'cleave');eq(s.phase,'defeat');eq(vuln(s),2)
end)
test('separate damage actions preserve already applied Spore on eventual victory',function()
 local s=battle();s.enemies[1].hp=1;s.enemies[2].hp=1
 C.damage(s,s.player,s.enemies[1],1);eq(vuln(s),2);C.damage(s,s.player,s.enemies[2],1);eq(C.outcome(s),'victory');eq(vuln(s),2)
end)
test('enemy Thorns death affects teammate damage and skips first new round decay',function()
 local s=battle();s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);assert(C.endTurn(s))
 eq(s.enemies[1].hp,0);eq(s.player.hp,65);eq(vuln(s),2);eq(s.player.vulnerableJustApplied,nil)
 local first=events(s,'vulnerable')[1];eq(first.detail.source,nil);eq(first.frame.player.vulnerableJustApplied,true)
end)
test('existing Vulnerable stacks without refreshing first-round suppression',function()
 local s=battle();s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);C.addStatus(s.player,'vulnerable',2);assert(C.endTurn(s))
 eq(s.player.hp,62);eq(vuln(s),3);eq(s.player.vulnerableJustApplied,nil)
end)
test('enemy-turn blocked Spore leaves next teammate damage unmodified',function()
 local s=battle();s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);C.addStatus(s.player,'artifact',1);assert(C.endTurn(s))
 eq(s.player.hp,68);eq(vuln(s),0);eq(s.player.statuses.artifact,0)
end)
test('poison death completes decrement then applies before living teammate move',function()
 local s=battle();s.enemies[1].hp=1;C.addStatus(s.enemies[1],'poison',1);assert(C.endTurn(s))
 eq(s.enemies[1].hp,0);eq(s.enemies[1].statuses.poison,0);eq(s.player.hp,71);eq(vuln(s),2)
 local ev=events(s,'vulnerable')[1];eq(ev.frame.enemies[1].statuses.poison,0);eq(ev.frame.player.vulnerableJustApplied,true)
end)
test('separate pre-turn poison deaths retain first resolved Spore at victory',function()
 local s=battle();for _,e in ipairs(s.enemies)do e.hp=1;C.addStatus(e,'poison',1)end;assert(C.endTurn(s))
 eq(s.phase,'victory');eq(s.player.hp,80);eq(vuln(s),2);eq(#events(s,'vulnerable'),1)
end)
test('final poison and final Thorns death do not spend Artifact',function()
 for _,mode in ipairs({'poison','thorns'})do local s=battle({'fungi_beast'});s.enemies[1].hp=1;C.addStatus(s.player,'artifact',1)
  if mode=='poison' then C.addStatus(s.enemies[1],'poison',1)else C.addStatus(s.player,'thorns',1)end
  assert(C.endTurn(s));eq(s.phase,'victory');eq(vuln(s),0);eq(s.player.statuses.artifact,1)
 end
end)
test('real Run Fire Potion kill applies Spore then consumes the potion',function()
 local r=Run.new(Data,42);r.floor=5;r.potions={'fire_potion'};assert(Run.startCombat(r,'fungi_pair'));r.combat.enemies[1].hp=20
 assert(Run.usePotion(r,1,1));eq(r.combat.enemies[1].hp,0);eq(vuln(r.combat),2);eq(#r.potions,0)
end)
test('card failure rolls back death, Artifact, flags, events and original references',function()
 local s=battle();s.enemies[1].hp=6;C.addStatus(s.player,'artifact',1)
 s.catalog.cards.strike.effects[2]={op='gainStatus',status='unknown',value=1}
 local before=C.copy(s);local p,e,statuses,hand,ev=s.player,s.enemies[1],s.player.statuses,s.hand,s.events
 eq(pcall(C.play,s,s.hand[1].uid,1),false);same(s,before);eq(s.player,p);eq(s.enemies[1],e);eq(p.statuses,statuses);eq(s.hand,hand);eq(s.events,ev)
 s.catalog.cards.strike.effects[2]=nil;play(s,'strike',1);eq(e.hp,0);eq(statuses.artifact,0);eq(vuln(s),0)
end)
test('unblocked failed card also restores applied Vulnerable and allows one later trigger',function()
 local s=battle();s.enemies[1].hp=6;s.catalog.cards.strike.effects[2]={op='gainStatus',status='unknown',value=1};local before=C.copy(s)
 eq(pcall(C.play,s,s.hand[1].uid,1),false);same(s,before);s.catalog.cards.strike.effects[2]=nil;play(s,'strike',1);eq(vuln(s),2);eq(#events(s,'vulnerable'),1)
end)
test('Twin Strike does not repeat the death trigger on its dead second-hit target',function()
 local s=battle(nil,{'twin_strike'});s.enemies[1].hp=5;play(s,'twin_strike',1);eq(vuln(s),2);eq(#events(s,'vulnerable'),1)
end)
test('separate area hits resolve first Spore before a later all-kill hit',function()
 local s=battle();s.enemies[1].hp=1;s.enemies[2].hp=2
 C.applyEffects(s,{{op='damageAll',value=1,times=2}},s.player)
 eq(C.outcome(s),'victory');eq(vuln(s),2);eq(#events(s,'vulnerable'),1)
end)
test('separate poison actions spend only the first Artifact before final death',function()
 local s=battle();C.addStatus(s.player,'artifact',2)
 for _,e in ipairs(s.enemies)do e.hp=1;C.addStatus(e,'poison',1)end
 assert(C.endTurn(s));eq(s.phase,'victory');eq(s.player.statuses.artifact,1);eq(vuln(s),0)
end)
test('a new encounter has fresh death powers and no previous player debuff',function()
 local r=Run.new(Data,42);r.floor=5;assert(Run.startCombat(r,'fungi_pair'));local s=r.combat
 s.enemies[1].hp=1;C.damage(s,s.player,s.enemies[1],1);eq(vuln(s),2)
 s.enemies[2].hp=1;C.damage(s,s.player,s.enemies[2],1);assert(Run.finishCombat(r));assert(Run.claimCardReward(r,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(r)
 r.floor=6;assert(Run.startCombat(r,'fungi_pair'));eq(vuln(r.combat),0);for _,e in ipairs(r.combat.enemies)do eq(e.statuses.spore_cloud,2)end
end)
print('SPORE_CLOUD '..passed..' passed; '..failed..' failed');assert(failed==0)
