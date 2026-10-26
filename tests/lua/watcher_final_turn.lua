package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_actor')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(ids,up)
 local cards={};for _,id in ipairs(ids)do cards[#cards+1]={cardId=id,upgraded=up}end
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck=cards,enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.enemies[1].ai=nil;s.enemies[1].intents={{id='wait',effects={}}};s.enemies[1].intentIndex=1
 s.energy=20;return s
end
local function held(s,id)for _,v in ipairs(s.hand)do if v.cardId==id then return v end end;error('missing '..id)end
local function play(s,id)local ok,why=C.play(s,held(s,id).uid,1);assert(ok,why)end
for _,up in ipairs({false,true})do
 local c=battle({'conclude'},up);play(c,'conclude');eq(c.turn,2);eq(c.enemies[1].hp,up and 984 or 988);eq(c.energy,3)
 local v=battle({'vault','deva_form'},up);A.applyPower(v,v.player,'weak',2,v.player);v.enemies[1].block=20
 v.enemies[1].intents[1].effects={{op='damage',value=10}};local hp=v.player.hp
 play(v,'vault');eq(v.turn,2);eq(v.player.hp,hp);eq(v.enemies[1].block,20);eq(v.player.statuses.weak,2)
 local d=battle({'deva_form','deva_form'},up);play(d,'deva_form');play(d,'deva_form');eq(d.player.statuses.deva_form,2)
 assert(C.endTurn(d));eq(d.energy,5);assert(C.endTurn(d));eq(d.energy,7)
 local b=battle({'blasphemy'},up);play(b,'blasphemy');eq(b.player.stance,'Divinity');eq(b.energy,22)
 A.applyPower(b,b.player,'intangible',2,b.player);local before=b.player.hp
 assert(C.endTurn(b));eq(b.player.hp,before-1);eq(b.player.stance,'Neutral');eq(b.player.statuses.end_turn_death,nil)
end
local dead=battle({'blasphemy'},false);play(dead,'blasphemy');assert(C.endTurn(dead));eq(dead.phase,'defeat')
print('WATCHER_FINAL_TURN conclude/vault/deva/blasphemy basic/upgraded passed')
