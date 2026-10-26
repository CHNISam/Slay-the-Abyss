package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(deck,up)
 local d=P.prepare(D,'watcher');local values={}
 for _,id in ipairs(deck)do values[#values+1]={cardId=id,upgraded=up==true}end
 local s=C.new(d,{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck=values,enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.energy=20;return s
end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('missing '..id)end
local function play(s,id,target)local ok,why=C.play(s,held(s,id).uid,target or 1);assert(ok,why)end
for _,up in ipairs({false,true})do
 local s=battle({'swivel','empty_fist'},up)
 play(s,'swivel');eq(s.player.block,up and 11 or 8);s.energy=0
 play(s,'empty_fist');eq(s.energy,0);eq(s.enemies[1].hp,1000-(up and 14 or 9));eq(s.player.statuses.free_attack,nil)
end
local persistent=battle({'swivel','empty_fist'},false)
play(persistent,'swivel');assert(C.endTurn(persistent));eq(persistent.player.statuses.free_attack,1)
persistent.energy=0;play(persistent,'empty_fist');eq(persistent.player.statuses.free_attack,nil)
local unsupported=battle({'alpha'},false)
local ok,why=C.canPlay(unsupported,held(unsupported,'alpha').uid,1);eq(ok,false);eq(why,'card_content_unavailable')
print('WATCHER_FINAL_FIRST swivel basic/upgraded passed')
