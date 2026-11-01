package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local Data=require('abyss_data')
local passed,failed=0,0
local function test(name,f)local ok,why=pcall(f);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function open(id,prepare,encounter)
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,id));if prepare then prepare(r)end
 assert(Run.startCombat(r,encounter or 'cultist_solo'));return r.combat
end
local function status(s,id)
 for _,e in ipairs(s.events)do if e.kind=='status'and e.detail.status==id and e.detail.target=='player'then return e end end
 error('missing '..id..' application event')
end
for _,row in ipairs({{'Thread and Needle','plated_armor',4},{'ClockworkSouvenir','artifact',1}})do
 test(row[1]..' applies TOP before ordinary draw',function()
  local s=open(row[1]);local event=status(s,row[2]);assert(s.player.statuses[row[2]]==row[3]);assert(#event.frame.hand==0)
 end)
end
test('Girya applies trained Strength TOP before ordinary draw',function()
 local s=open('Girya',function(r)assert(require('abyss_rare_relics').lift(r))end)
 assert(s.player.statuses.strength==1);assert(#status(s,'strength').frame.hand==0)
end)
test('Du Vu Doll counts permanent curses and applies Strength TOP before draw',function()
 local s=open('Du-Vu Doll',function(r)assert(Run.obtainCard(r,'injury'))end)
 assert(s.player.statuses.strength==1);assert(#status(s,'strength').frame.hand==0)
end)
test('Sling elite Strength TOP precedes ordinary draw',function()
 local s=open('Sling',function(r)r.floor=6 end,'elite_nob');assert(s.player.statuses.strength==2);assert(#status(s,'strength').frame.hand==0)
end)
test('Philosopher Stone synchronously boosts enemies before Mercury first-turn damage',function()
 local s=open("Philosopher's Stone",function(r)assert(Run.obtainRelic(r,'Mercury Hourglass'))end)
 assert(s.enemies[1].statuses.strength==1)
 for _,e in ipairs(s.events)do if e.kind=='damage'then assert(#e.frame.hand==0 and e.frame.enemies[1].statuses.strength==1);return end end
 error('missing opening damage')
end)
test('Fossilized Helix BOTTOM Buffer follows ordinary draw',function()
 local s=open('FossilizedHelix');assert(s.player.statuses.buffer==1);assert(#status(s,'buffer').frame.hand==5)
end)
test('Clockwork and Thread TOP order reverses actual acquisition in both orders',function()
 for _,ids in ipairs({{'ClockworkSouvenir','Thread and Needle'},{'Thread and Needle','ClockworkSouvenir'}})do
  local r=Run.new(Data,42);for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id))end
  assert(Run.startCombat(r,'cultist_solo'));local order={}
  for _,event in ipairs(r.combat.events)do if event.kind=='status'and(event.detail.status=='artifact'or event.detail.status=='plated_armor')then order[#order+1]=event.detail.status;assert(#event.frame.hand==0)end end
  assert(#order==2);assert(order[1]==(ids[2]=='ClockworkSouvenir'and 'artifact'or 'plated_armor'))
 end
end)
test('Clockwork Artifact is present before first-turn Mercury damage',function()
 local s=open('ClockworkSouvenir',function(r)assert(Run.obtainRelic(r,'Mercury Hourglass'))end)
 for _,event in ipairs(s.events)do if event.kind=='damage'then assert(event.frame.player.statuses.artifact==1 and #event.frame.hand==0);return end end
 error('missing Mercury damage')
end)
test('Captain Wheel actual third-turn block precedes ordinary draw',function()
 local s=open('CaptainsWheel');s.player.hp=1000;s.player.maxHp=1000;s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 assert(C.endTurn(s));assert(C.endTurn(s))
 for _,event in ipairs(s.events)do if event.kind=='block'and event.detail.amount==18 then assert(event.frame.turn==3 and #event.frame.hand==0);return end end
 error('missing Captain Wheel block')
end)
test('Warped Tongs upgrades the ordinary five-card hand before Brutality extra draw',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'WarpedTongs'))
 r.deck={{uid=1,cardId='brutality'}};for i=2,11 do r.deck[i]={uid=i,cardId='defend'}end;r.nextDeckUid=12
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;s.player.hp=1000;s.player.maxHp=1000;s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 C.draw(s,10);local power;for _,card in ipairs(s.hand)do if card.cardId=='brutality'then power=card end end
 assert(power);assert(Run.play(r,power.uid));assert(C.endTurn(s))
 for _,event in ipairs(s.events)do if event.kind=='card_upgraded'and event.frame.turn==2 then assert(#event.frame.hand==5);return end end
 error('missing second-turn Tongs upgrade')
end)
test('Incense and Mercury BOTTOM effects preserve both real acquisition orders',function()
 for _,ids in ipairs({{'Incense Burner','Mercury Hourglass'},{'Mercury Hourglass','Incense Burner'}})do
  local r=Run.new(Data,42);for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id))end
  r.relicCounters.incense_burner=5;assert(Run.startCombat(r,'cultist_solo'))
  local found=false
  for _,event in ipairs(r.combat.events)do if event.kind=='damage'then
   assert(((event.frame.player.statuses.intangible or 0)>0)==(ids[1]=='Incense Burner'));assert(#event.frame.hand==0);found=true
  end end
  assert(found and r.combat.player.statuses.intangible==1)
 end
end)
test('Pocketwatch and Tongs preserve held order before Brutality postdraw power',function()
 for _,ids in ipairs({{'Pocketwatch','WarpedTongs'},{'WarpedTongs','Pocketwatch'}})do
  local r=Run.new(Data,42);for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id))end
  r.deck={{uid=1,cardId='brutality',upgraded=true}};for i=2,15 do r.deck[i]={uid=i,cardId='defend'}end;r.nextDeckUid=16
  assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;s.player.hp=1000;s.player.maxHp=1000;s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
  local power;for _,card in ipairs(s.hand)do if card.cardId=='brutality'then power=card end end;assert(power)
  assert(Run.play(r,power.uid));assert(C.endTurn(s))
  local found=false
  for _,event in ipairs(s.events)do if event.kind=='card_upgraded'and event.frame.turn==2 then assert(#event.frame.hand==(ids[1]=='Pocketwatch'and 8 or 5));found=true end end
  assert(found and #s.hand==9)
 end
end)
assert(failed==0,tostring(failed)..' source opening order regressions')
print('LUA_SOURCE_OPENING_PASS '..passed)
