package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,Actions=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function battle(ids,up)
 local deck={};for _,id in ipairs(ids)do deck[#deck+1]={cardId=id,upgraded=up}end
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck=deck,enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.enemies[1].ai=nil;s.enemies[1].intents={{id='wait',effects={}}};s.enemies[1].intentIndex=1;s.energy=20;return s
end
local function held(s,id)for _,v in ipairs(s.hand)do if v.cardId==id then return v end end;error('missing '..id)end
local function play(s,id)local ok,why=C.play(s,held(s,id).uid,1);assert(ok,why)end
for _,up in ipairs({false,true})do
 local m=battle({'meditate','empty_fist','empty_body','swivel'},up)
 local a,b=held(m,'empty_fist'),held(m,'empty_body')
 for i=#m.hand,1,-1 do local c=m.hand[i];if c==a or c==b then table.remove(m.hand,i);m.discard[#m.discard+1]=c end end
 play(m,'meditate')
 if not up then local p=assert(m.pendingPileChoice);eq(m.turn,1);eq(m.player.stance,'Neutral');assert(C.choosePile(m,{a.uid},p.token,p.generation))end
 eq(m.turn,2);eq(m.player.stance,'Calm');eq(a.retain,nil)
 local o=battle({'omniscience'},up);local original=Actions.fresh(C,o,'empty_fist');o.draw[1]=original
 play(o,'omniscience');local p=assert(o.pendingPileChoice);eq(p.mode,'omniscience');eq(#p.candidateUids,1)
 local wrong,why=C.choosePile(o,{original.uid},p.token+1,p.generation);eq(wrong,false);eq(why,'stale_pile_choice_token');eq(o.pendingPileChoice,p)
 assert(C.choosePile(o,{original.uid},p.token,p.generation));eq(o.enemies[1].hp,982);eq(o.energy,up and 17 or 16)
 local found=0;for _,c in ipairs(o.exhaust)do if c.uid==original.uid then found=found+1 end end;eq(found,1);eq(#o.discard,0)
end
print('WATCHER_FINAL_PILE_CHOICES Meditate/Omniscience basic/upgraded, singleton and stale token passed')
