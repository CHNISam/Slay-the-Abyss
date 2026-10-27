package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_actor');local data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function new(id,up)
 local s=C.new(data,{deck={},enemies={'jaw_worm','jaw_worm'},seed=17,shuffleSeed='17'})
 for _,enemy in ipairs(s.enemies)do enemy.hp=1000;enemy.maxHp=1000;enemy.block=0;enemy.intents={{id='wait',effects={{op='block',value=0}}}};enemy.intentIndex=1;enemy.ai=nil end
 s.hand={{cardId=id,uid=1,upgraded=up==true}};s.nextUid=20;s.energy=5
 return s
end
local function play(s,id,uid,target)s.hand[#s.hand+1]={cardId=id,uid=uid,upgraded=false};assert(C.play(s,uid,target))end
local s=new('panache');assert(C.play(s,1));for i=2,6 do play(s,'good_instincts',i)end;eq(s.enemies[1].hp,990);eq(s.enemies[2].hp,990)
s=new('sadistic_nature',true);assert(C.play(s,1));play(s,'blind',2,1);eq(s.enemies[1].hp,993)
A.addStatus(s.enemies[2],'artifact',1);play(s,'trip',3,2);eq(s.enemies[2].hp,1000)
s=new('the_bomb');assert(C.play(s,1));assert(C.endTurn(s));eq(s.enemies[1].hp,1000);assert(C.endTurn(s));eq(s.enemies[1].hp,1000);assert(C.endTurn(s));eq(s.enemies[1].hp,960)
s=new('magnetism');assert(C.play(s,1));assert(C.endTurn(s));eq(#s.hand,1);assert(s.catalog.cards[s.hand[1].cardId].color=='colorless')
s=new('mayhem');assert(C.play(s,1));s.draw={{cardId='swift_strike',uid=2,upgraded=false}}
for uid=3,7 do s.draw[#s.draw+1]={cardId='defend',uid=uid,upgraded=false}end
assert(C.endTurn(s));eq(s.enemies[1].hp+s.enemies[2].hp,1993);eq(s.discard[1].cardId,'swift_strike')
s=new('panic_button');assert(C.play(s,1));eq(s.player.block,30);play(s,'good_instincts',2);eq(s.player.block,30);C.block(s,s.player,5,true);eq(s.player.block,35)
s=new('dark_shackles');assert(C.play(s,1,1));eq(s.enemies[1].statuses.strength,-9);assert(C.endTurn(s));eq(s.enemies[1].statuses.strength,0)
s=new('mind_blast');s.draw={{cardId='defend',uid=2},{cardId='strike',uid=3},{cardId='anger',uid=4}};assert(C.play(s,1,1));eq(s.enemies[1].hp,997)
s=new('hand_of_greed');s.enemies[1].hp=10;local gold=s.player.gold;assert(C.play(s,1,1));eq(s.player.gold,gold+20)
s=new('hand_of_greed',true);s.enemies[1].hp=10;s.enemies[2].hp=0;gold=s.player.gold;assert(C.play(s,1,1));eq(s.player.gold,gold+25)
s=new('apparition');assert(C.play(s,1));C.damage(s,s.enemies[1],s.player,100);eq(s.player.hp,79)
s=new('jax',true);assert(C.play(s,1));eq(s.player.hp,77);eq(s.player.statuses.strength,3)
s=new('panic_button');A.addStatus(s.player,'artifact',1);assert(C.play(s,1));eq(s.player.statuses.artifact,0);eq(s.player.statuses.no_block or 0,0)
s=new('bandage_up');s.player.hp=40;s.relics={'magic_flower'};assert(C.play(s,1));eq(s.player.hp,46)
s=new('bandage_up');s.player.hp=40;s.relics={'mark_of_bloom'};assert(C.play(s,1));eq(s.player.hp,40)
print('ok colorless persistent Powers, kill rewards, dynamic damage and special effects')
