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
 local w=battle({'wave_of_the_hand','empty_body'},up);play(w,'wave_of_the_hand');w.player.block=999;play(w,'empty_body');eq(w.player.block,999);eq(w.enemies[1].statuses.weak,up and 2 or 1)
 assert(C.endTurn(w));eq(w.player.statuses.wave_of_the_hand,nil)
 local e=battle({'establishment','protect','sands_of_time'},up);play(e,'establishment');local protect=held(e,'protect');local sands=held(e,'sands_of_time')
 assert(C.endTurn(e));eq(C.cardDefinition(e,protect).cost,1);eq(C.cardDefinition(e,sands).cost,2)
 assert(C.endTurn(e));eq(C.cardDefinition(e,protect).cost,0);eq(C.cardDefinition(e,sands).cost,0)
end
local tiny=battle({'wave_of_the_hand','empty_body'},false);play(tiny,'wave_of_the_hand');A.applyPower(tiny,tiny.player,'frail',1,tiny.player)
tiny.catalog.cards.empty_body.effects={{op='block',value=1}};play(tiny,'empty_body')
eq(tiny.player.block,0);eq(tiny.enemies[1].statuses.weak,1)
print('WATCHER_FINAL_BLOCK_RETENTION positive-float/cap callbacks and retained discounts passed')
