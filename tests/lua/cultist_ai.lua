package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Combat=require('abyss_combat')
local Data=require('abyss_data')
local n=0
local function eq(a,b,name) assert(a==b,(name or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok Cultist '..n..' - '..name) end
local function battle(enemies,deck,seed) return Combat.new(Data,{enemies=enemies or {'cultist'},deck=deck or {'defend'},seed=seed or 42}) end
local function strength(e) return e.statuses.strength or 0 end
local function same(a,b)
 if type(b)~='table' then eq(a,b);return end
 for k,v in pairs(b) do same(a[k],v) end
 for k in pairs(a) do assert(b[k]~=nil,'unexpected key '..tostring(k)) end
end

test('A0 opener shows Ritual3 without Strength or damage',function()
 local s=battle();local e=s.enemies[1];local view=Combat.intent(s,1)
 eq(view.kind,'buff');eq(view.effects[1].status,'ritual');eq(view.effects[1].value,3)
 view.effects[1].value=99;eq(Combat.intent(s,1).effects[1].value,3)
 assert(Combat.endTurn(s));eq(s.player.hp,80);eq(e.statuses.ritual,3);eq(strength(e),0)
 eq(Combat.intent(s,1).kind,'attack');eq(Combat.intent(s,1).effects[1].value,6)
 local status=Combat.statusView(e);eq(status[1].id,'ritual');eq(status[1].name,'仪式');eq(status[1].amount,3)
 status[1].amount=99;eq(e.statuses.ritual,3)
end)

test('natural trace is 0,6,9,12,15 with one opener',function()
 local s=battle();local grants=0
 for i,expected in ipairs({0,6,9,12,15}) do
  local hp=s.player.hp;assert(Combat.endTurn(s));eq(hp-s.player.hp,expected)
  eq(strength(s.enemies[1]),(i-1)*3)
 end
 for _,event in ipairs(s.events) do if event.kind=='status' and event.detail.status=='ritual' then grants=grants+1 end end
 eq(grants,1)
end)

test('both enemies finish actions and owner end-turn before any Ritual growth',function()
 local s=battle({'cultist','cultist'});assert(Combat.endTurn(s))
 Combat.addStatus(s.enemies[2],'regen',1);s.enemies[2].hp=s.enemies[2].hp-1
 local start=#s.events;assert(Combat.endTurn(s));local damage,lastOwnerEnd,firstGrowth=0,0,nil
 for i=start+1,#s.events do local ev=s.events[i]
  if ev.kind=='damage' then damage=damage+1;eq(ev.frame.enemies[1].statuses.strength or 0,0);eq(ev.frame.enemies[2].statuses.strength or 0,0) end
  if ev.kind=='heal' then lastOwnerEnd=i end
  if ev.kind=='status' and ev.detail.status=='strength' then firstGrowth=firstGrowth or i;eq(damage,2) end
 end
 assert(firstGrowth and lastOwnerEnd>0 and firstGrowth>lastOwnerEnd)
 eq(strength(s.enemies[1]),3);eq(strength(s.enemies[2]),3)
end)

test('weak and negative Strength modify attacks, not Ritual magnitude',function()
 local s=battle();assert(Combat.endTurn(s));local e=s.enemies[1]
 Combat.addStatus(e,'strength',-2);Combat.addStatus(e,'weak',1)
 local hp=s.player.hp;assert(Combat.endTurn(s));eq(hp-s.player.hp,3);eq(strength(e),1)
 eq(e.statuses.ritual,3);eq(e.statuses.weak,0)
end)

test('player death prevents all round-end growth',function()
 local s=battle({'cultist','jaw_worm'});assert(Combat.endTurn(s));s.player.hp=1
 assert(Combat.endTurn(s));eq(s.phase,'defeat');eq(strength(s.enemies[1]),0)
end)

test('later teammate lethal attack cancels growth for earlier live attacker',function()
 local s=battle({'cultist','cultist'});assert(Combat.endTurn(s));s.player.hp=7
 assert(Combat.endTurn(s));eq(s.phase,'defeat');eq(strength(s.enemies[1]),0);eq(strength(s.enemies[2]),0)
end)

test('poison kill before opener never grants Ritual',function()
 local s=battle({'cultist','jaw_worm'});local e=s.enemies[1];e.hp=1;Combat.addStatus(e,'poison',1)
 assert(Combat.endTurn(s));eq(e.hp,0);eq(e.statuses.ritual,nil);eq(strength(e),0)
end)

test('poison kill after opener skips action and round growth',function()
 local s=battle({'cultist','jaw_worm'});assert(Combat.endTurn(s));local e=s.enemies[1]
 e.hp=1;Combat.addStatus(e,'poison',1);assert(Combat.endTurn(s));eq(e.hp,0);eq(strength(e),0)
end)

test('thorns death skips growth while teammate finishes',function()
 local s=battle({'cultist','jaw_worm'});assert(Combat.endTurn(s));local e=s.enemies[1];e.hp=1
 Combat.addStatus(s.player,'thorns',1);assert(Combat.endTurn(s));eq(e.hp,0);eq(strength(e),0)
 eq(s.enemies[2].intentIndex,3);eq(s.phase,'player')
end)

test('pre-action lethal card keeps Ritual absent and victory terminal',function()
 local s=battle(nil,{'strike'});local e=s.enemies[1];e.hp=1
 assert(Combat.play(s,s.hand[1].uid,1));eq(s.phase,'victory');eq(e.statuses.ritual,nil)
 eq(Combat.endTurn(s),false);eq(strength(e),0)
end)

test('mixed Lagavulin retains three sleeps and Cultist round growth',function()
 local s=battle({'cultist','lagavulin'})
 for _=1,3 do assert(Combat.endTurn(s)) end
 eq(strength(s.enemies[1]),6);eq(Combat.intent(s,2).kind,'attack');eq(s.enemies[2].statuses.ritual,nil)
 eq(s.player.hp,65)
end)

test('HP is always sampled through existing project RNG, not nominal50',function()
 local seen={}
 for seed=0,63 do
  local s=battle(nil,nil,seed);local expected=48+((seed*25173+13849)%65536)%7
  eq(s.enemies[1].hp,expected);eq(s.enemies[1].maxHp,expected);seen[expected]=true
  local again=battle(nil,nil,seed);eq(again.enemies[1].hp,expected);eq(s.seed,again.seed)
 end
 for hp=48,54 do assert(seen[hp]) end
end)

test('failed card restores live Ritual AI, statuses, identities and events',function()
 local s=battle(nil,{'strike'});assert(Combat.endTurn(s));local e=s.enemies[1]
 s.catalog.cards.strike.effects={{op='damage',value=9},{op='gainStatus',status='strength',value=2147483647}}
 Combat.addStatus(s.player,'strength',1)
 local before=Combat.copy(s);local statuses=e.statuses;local events=s.events
 eq(pcall(Combat.play,s,s.hand[1].uid,1),false);same(s,before);eq(s.enemies[1],e);eq(e.statuses,statuses);eq(s.events,events)
end)

test('fresh instances do not inherit Ritual phase or Strength',function()
 local a=battle();assert(Combat.endTurn(a));assert(Combat.endTurn(a));local b=battle()
 eq(strength(a.enemies[1]),3);eq(strength(b.enemies[1]),0);eq(b.enemies[1].statuses.ritual,nil)
 eq(Combat.intent(b,1).kind,'buff')
end)
print('Cultist runtime: '..n..' groups passed')
