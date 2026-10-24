package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data,Run,Map,Nodes=require('abyss_combat'),require('abyss_data'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b) eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(name,fn) fn();n=n+1;print('PASS independent '..name) end
local function battle(deck,hp)
 local data=C.copy(Data);local e=data.enemies.enemies[1];e.ai=nil;e.intents={{id='quiet',kind='stunned',effects={}}}
 return C.new(data,{enemies={e.id},deck=deck,hp=hp or 80,seed=51})
end
local function ownership(s)
 local seen,count={},0
 for _,name in ipairs({'hand','draw','discard','exhaust'}) do for _,c in ipairs(s[name]) do assert(not seen[c.uid],'duplicate '..c.uid);seen[c.uid]=true;count=count+1 end end
 if s.cardInUse then assert(not seen[s.cardInUse.uid]);seen[s.cardInUse.uid]=true;count=count+1 end
 return count
end
test('second lethal Regret preserves first discard and current-card ownership',function()
 local s=battle({'regret','regret','defend'},4);s.events={};local before=C.copy(s.catalog)
 assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.hp,0);eq(ownership(s),3)
 eq(#s.hand,1);eq(s.hand[1].cardId,'defend');eq(#s.discard,1);eq(s.discard[1].cardId,'regret');eq(s.cardInUse.cardId,'regret');same(s.catalog,before)
 local amounts={};for _,e in ipairs(s.events)do if e.kind=='hp_loss'then amounts[#amounts+1]=e.detail.amount end end;eq(#amounts,2);eq(amounts[1],3);eq(amounts[2],1)
end)
test('after an ordinary card play Regret captures current reduced hand exactly once',function()
 local s=battle({'regret','defend','strike'});local card
 for _,c in ipairs(s.hand)do if c.cardId=='defend'then card=c end end
 assert(C.play(s,card.uid));s.events={};assert(C.endTurn(s));eq(s.player.hp,78);eq(ownership(s),3);eq(s.cardInUse,nil)
 local losses=0;for _,e in ipairs(s.events)do if e.kind=='hp_loss'then eq(e.detail.amount,2);losses=losses+1;eq(e.frame.player.block,5)end end;eq(losses,1)
end)
test('full ten-card hand includes ethereal cards and non-triggering power types',function()
 local s=battle({'regret','dazed','ghostly_armor','carnage','inflame','strike','strike','defend','defend','defend'})
 while #s.draw>0 do s.hand[#s.hand+1]=table.remove(s.draw) end
 s.events={};assert(C.endTurn(s));eq(s.player.hp,70);eq(#s.exhaust,3);eq(ownership(s),10)
 local losses=0;for _,e in ipairs(s.events)do if e.kind=='hp_loss'then eq(e.detail.amount,10);eq(#e.frame.exhaust,0);losses=losses+1 end end;eq(losses,1)
end)
test('lethal Regret prevents ethereal cleanup regen and temporary strength removal',function()
 local s=battle({'regret','ghostly_armor','defend'},3)
 C.addStatus(s.player,'regen',4);C.addTemporaryStrength(s.player,3,s);s.events={};local seed=s.seed
 assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.player.statuses.regen,4);eq(s.player.temporaryStrength,3);eq(s.player.statuses.strength,3)
 eq(s.seed,seed);eq(#s.exhaust,0);eq(ownership(s),3);eq(#s.hand,2);eq(#s.discard,0)
 for _,e in ipairs(s.events)do assert(e.kind~='heal' and e.kind~='status' and e.kind~='enemy_turn' and e.kind~='player_turn')end
end)
test('source ordinary attack modifiers cannot change Regret loss',function()
 local s=battle({'regret','regret','defend','strike'});s.player.block=99
 for _,x in ipairs({{'strength',50},{'weak',3},{'vulnerable',3},{'thorns',99},{'artifact',2}})do C.addStatus(s.player,x[1],x[2])end
 s.events={};assert(C.endTurn(s));eq(s.player.hp,72)
 for _,e in ipairs(s.events)do if e.kind=='hp_loss'then eq(e.detail.amount,4);eq(e.detail.blocked,0);eq(e.frame.player.block,99)end;assert(e.kind~='damage' and e.kind~='status_damage' and e.kind~='play')end
end)
print('INDEPENDENT_REGRET_PASS '..n)
