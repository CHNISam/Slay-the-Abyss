package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(ids,up)
 local cards={};for _,id in ipairs(ids)do cards[#cards+1]={cardId=id,upgraded=up}end
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck=cards,enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.energy=20;return s
end
local function held(s,id)for _,v in ipairs(s.hand)do if v.cardId==id then return v end end;error('missing '..id)end
local function play(s,id)local ok,why=C.play(s,held(s,id).uid,1);assert(ok,why)end
local function take(s,id)
 for i,c in ipairs(s.draw)do if c.cardId==id then table.remove(s.draw,i);s.hand[#s.hand+1]=c;return c end end
 error('missing generated '..id)
end
for _,up in ipairs({false,true})do
 local s=battle({'alpha'},up);play(s,'alpha');eq(#s.exhaust,1)
 local beta=take(s,'beta');eq(beta.upgraded,false);play(s,'beta');eq(#s.exhaust,2)
 local omega=take(s,'omega');eq(omega.upgraded,false);play(s,'omega');eq(s.player.statuses.omega,50)
 s.player.block=100;assert(C.endTurn(s));eq(s.enemies[1].hp,950)
 local x=battle({'conjure_blade'},up);x.energy=2;play(x,'conjure_blade');eq(x.energy,0)
 local exp=take(x,'expunger');eq(exp.expungerHits,up and 3 or 2);x.energy=1;play(x,'expunger');eq(x.enemies[1].hp,1000-9*(up and 3 or 2))
 local j=battle({'judgment'},up);j.enemies[1].hp=up and 40 or 30;j.enemies[1].block=999
 play(j,'judgment');eq(j.enemies[1].hp,0);eq(j.phase,'victory')
 local fail=battle({'judgment'},up);fail.enemies[1].hp=up and 41 or 31;play(fail,'judgment');eq(fail.enemies[1].hp,up and 41 or 31)
 local b=battle({'spirit_shield','empty_fist','empty_body'},up);b.player.statuses.dexterity=2
 play(b,'spirit_shield');eq(b.player.block,(up and 4 or 3)*2+2)
 local r=battle({'ragnarok'},up);r.player.statuses.strength=2;play(r,'ragnarok');eq(r.enemies[1].hp,1000-(up and 8*6 or 7*5))
end
local zero=battle({'conjure_blade'},false);zero.energy=0;play(zero,'conjure_blade');local exp=take(zero,'expunger');eq(exp.expungerHits,0);zero.energy=1;play(zero,'expunger');eq(zero.enemies[1].hp,1000)
local reaction=battle({'ragnarok'},false);reaction.player.hp=1;reaction.enemies[1].statuses.thorns=1
play(reaction,'ragnarok');eq(reaction.player.hp,0);eq(reaction.enemies[1].hp,995)
print('WATCHER_FINAL_DAMAGE_GENERATION basic/upgraded, thresholds, zero-X and retaliation passed')
