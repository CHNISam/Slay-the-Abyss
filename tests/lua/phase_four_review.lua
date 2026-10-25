-- Independent fixed319009 contract review. Controlled genuine Core states;
-- no business service or handler is replaced; not natural acquisition proof.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_actor')
local Profiles=require('abyss_character_profiles')
local Data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b,why)assert(a==b,(why or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('ok phase_four_review '..name)
 else failed=failed+1;print('not ok phase_four_review '..name..' -- '..tostring(why))end
end
local function find(pile,id)for _,c in ipairs(pile)do if c.cardId==id then return c end end;error('missing '..id)end
local function contains(pile,uid)for _,c in ipairs(pile)do if c.uid==uid then return true end end;return false end
local function count(pile,id)local n=0;for _,c in ipairs(pile)do if c.cardId==id then n=n+1 end end;return n end
local function arrange(s,ids)
 local all={};for _,p in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(p)do all[#all+1]=c end end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 for _,id in ipairs(ids)do
  local found;for i,c in ipairs(all)do if c.cardId==id then found=table.remove(all,i);break end end
  s.hand[#s.hand+1]=assert(found,'fixture instance missing '..id)
 end
 for _,c in ipairs(all)do s.draw[#s.draw+1]=c end
end
local function play(s,id,target)local ok,why=C.play(s,find(s.hand,id).uid,target);assert(ok,why)end

test('Divinity exit recalls Flurry after normal Draw so retained hand can fill first',function()
 local deck={'prostrate','flurry_of_blows'};for i=1,8 do deck[#deck+1]='protect'end;for i=1,5 do deck[#deck+1]='defend_purple'end
 local s=C.new(Profiles.prepare(Data,'watcher'),{seed=42,cardRandomSeed='42',enableStances=true,deck=deck,enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 local ids={'prostrate','flurry_of_blows'};for i=1,8 do ids[#ids+1]='protect'end;arrange(s,ids)
 -- Nine Mantra is a legal preexisting combat state. Apply through the real
 -- Actor API, then let actual Prostrate and Flurry cards do the transition.
 assert(A.applyPower(s,s.player,'mantra',9,s.player));play(s,'prostrate');eq(s.player.stance,'Divinity')
 local flurry=find(s.hand,'flurry_of_blows');play(s,'flurry_of_blows',1);assert(contains(s.discard,flurry.uid))
 eq(#s.hand,8);eq(#s.draw,5);assert(C.endTurn(s));eq(s.player.stance,'Neutral');eq(#s.hand,10)
 -- DivinityStance51-52 queues Neutral. During its execution ChangeStanceAction
 -- 57-58 -> Flurry35 queues DiscardToHand BOTTOM, behind normal opening Draw.
 -- Draw fills both slots first, so DiscardToHand must leave Flurry in discard.
 eq(count(s.hand,'defend_purple'),2,'ordinary Draw gets both free slots before recall')
 assert(contains(s.discard,flurry.uid),'full hand leaves Flurry in real discard pile')
 assert(not contains(s.hand,flurry.uid),'Flurry is not recalled ahead of Draw')
 eq(#s.draw,3)
end)
for _,first in ipairs({'choked','sharp_hide'})do
 test(first..' acquisition controls whether Choke resolves before lethal Sharp Hide',function()
  local s=C.new(Profiles.prepare(Data,'silent'),{seed=42,cardRandomSeed='42',deck={'strike_green'},enemies={'cultist'}})
  s.player.hp=3;s.enemies[1].hp=7
  assert(A.applyPower(s,s.enemies[1],first,first=='choked' and 5 or 3,s.player))
  local second=first=='choked' and 'sharp_hide' or 'choked'
  assert(A.applyPower(s,s.enemies[1],second,second=='choked' and 5 or 3,s.player))
  local used=find(s.hand,'strike_green');play(s,'strike_green',1)
  eq(s.player.hp,0);eq(s.phase,'defeat');eq(s.enemies[1].hp,first=='choked' and 0 or 1)
  assert(s.cardInUse==used,'lethal onUse stops before UseCard disposal')
  assert(not contains(s.discard,used.uid));eq(s.pendingPlay,nil)
 end)
end
print('PHASE_FOUR_REVIEW_PASS '..passed..' FAIL '..failed)
if failed>0 then error('phase_four_review found '..failed..' source-contract violations')end
