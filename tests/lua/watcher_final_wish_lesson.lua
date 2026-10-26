package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,R=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_sts_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(id,up)
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',miscRng=R.fromSeed('7'),enableStances=true,
 deck={{uid=90,cardId=id,upgraded=up}},masterDeck={{uid=1,cardId='empty_fist',upgraded=false}},enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.enemies[1].ai=nil;s.enemies[1].intents={{id='wait',effects={}}};s.enemies[1].intentIndex=1;s.energy=20;return s
end
local function play(s)local ok,why=C.play(s,s.hand[1].uid,1);assert(ok,why)end
for _,up in ipairs({false,true})do
 for option=1,3 do
  local s=battle('wish',up);local gold=s.player.gold;play(s);local p=assert(s.pendingChoice);eq(s.pendingPlay.uid,1)
  local ok,why=C.chooseCard(s,p.token+1,option);eq(ok,false);eq(why,'stale_card_choice');eq(s.pendingChoice,p)
  assert(C.chooseCard(s,p.token,option));eq(s.pendingChoice,nil);eq(s.pendingPlay,nil);eq(#s.exhaust,1)
  if option==1 then eq(s.player.statuses.strength,up and 4 or 3)
  elseif option==2 then eq(s.player.gold,gold+(up and 30 or 25))
  else eq(s.player.statuses.plated_armor,up and 8 or 6);s.player.statuses.barricade=1;assert(C.endTurn(s));eq(s.player.block,up and 8 or 6)end
 end
 local l=battle('lesson_learned',up);l.enemies[1].hp=up and 13 or 10;local before=R.snapshot(l.miscRng).counter;play(l)
 eq(l.enemies[1].hp,0);eq(l.phase,'victory');eq(l.masterDeck[1].upgraded,true);eq(l.masterDeckChanges[1].uid,1);eq(R.snapshot(l.miscRng).counter,before+1)
 local minion=battle('lesson_learned',up);minion.enemies[1].hp=1;minion.enemies[1].minion=true;play(minion);eq(minion.masterDeck[1].upgraded,false);eq(minion.masterDeckChanges,nil)
end
print('WATCHER_FINAL_WISH_LESSON all options basic/upgraded, singleton misc and minion exclusion passed')
