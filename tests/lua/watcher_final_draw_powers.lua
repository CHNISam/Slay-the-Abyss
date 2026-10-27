package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_actor')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(ids,up)
 local cards={};for _,id in ipairs(ids)do cards[#cards+1]={cardId=id,upgraded=up}end
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck=cards,enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.enemies[1].ai=nil;s.enemies[1].intents={{id='wait',effects={}}};s.enemies[1].intentIndex=1;s.energy=20;return s
end
local function held(s,id)for _,v in ipairs(s.hand)do if v.cardId==id then return v end end;error('missing '..id)end
local function play(s,id)local ok,why=C.play(s,held(s,id).uid,1);assert(ok,why)end
for _,up in ipairs({false,true})do
 local deus=battle({'deus_ex_machina'},up);eq(#deus.exhaust,1);eq(deus.exhaust[1].cardId,'deus_ex_machina');eq(#deus.hand,up and 3 or 2)
 for _,c in ipairs(deus.hand)do eq(c.cardId,'miracle');eq(c.upgraded,false)end
 local m=battle({'master_reality','alpha'},up);play(m,'master_reality');play(m,'alpha');eq(m.draw[1].cardId,'beta');eq(m.draw[1].upgraded,true)
 local f=battle({'foresight','empty_fist','empty_body'},up);f.rules.player.drawPerTurn=1;play(f,'foresight');assert(C.endTurn(f));assert(f.pendingScry);eq(#f.hand,0);assert(f.startTurnPending)
 local token=f.pendingScry.token;local first=f.pendingScry.candidateUids[1];local ok,why=C.chooseScry(f,{first},token);assert(ok,why);eq(f.pendingScry,nil);eq(f.startTurnPending,nil);eq(#f.hand,1);eq(f.discard[1].uid,first)
end
print('WATCHER_FINAL_DRAW_POWERS Deus/Master Reality/Foresight basic/upgraded passed')
