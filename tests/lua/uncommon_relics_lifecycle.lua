package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,U=require('abyss_run'),require('abyss_combat'),require('abyss_uncommon_relics')
local Data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function begin(ids,deck)
 local r=Run.new(Data,42)
 for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id),'cannot obtain '..id)end
 if deck then r.deck={};for i,id in ipairs(deck)do r.deck[i]={uid=i,cardId=id,upgraded=false}end;r.nextDeckUid=#deck+1 end
 assert(Run.startCombat(r,'cultist_solo'));return r,r.combat
end
local function find(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 C.draw(s,10)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error('missing '..id)
end
test('normal obtain activates three attack relics in real plays and resets next turn',function()
 local r,s=begin({'Kunai','Shuriken','Ornamental Fan'},{'strike','strike','strike','defend','defend','defend','defend'})
 s.enemies[1].hp=200;s.enemies[1].maxHp=200
 for i=1,3 do local c=find(s,'strike');assert(Run.play(r,c.uid,1))end
 assert(s.player.statuses.strength==1 and s.player.statuses.dexterity==1 and s.player.block==4)
 assert(Run.endTurn(r));assert(s.relicCounters.kunai==0 and s.relicCounters.shuriken==0)
end)
test('normal obtain enables Blue Candle playable exact curse exhausted and HP lost',function()
 local r,s=begin({'Blue Candle'},{'injury','defend','defend','defend','defend','defend'})
 local c=find(s,'injury');local hp=s.player.hp;local energy=s.energy
 assert(Run.play(r,c.uid));assert(s.player.hp==hp-1 and s.energy==energy)
 local found=false;for _,card in ipairs(s.exhaust)do if card.uid==c.uid then found=true end end;assert(found)
end)
test('normal obtain Strike Dummy adds three before vulnerable Paper Frog',function()
 local r,s=begin({'StrikeDummy','Paper Frog'},{'strike','defend','defend','defend','defend','defend'})
 local c=find(s,'strike');s.enemies[1].statuses.vulnerable=2;local hp=s.enemies[1].hp
 assert(Run.play(r,c.uid,1));assert(s.enemies[1].hp==hp-15)
end)
test('normal obtain Hourglass turn one and Horn Cleat turn two',function()
 local r,s=begin({'Mercury Hourglass','HornCleat'})
 local found=false;for _,e in ipairs(s.events)do if e.kind=='damage'and e.detail.amount==3 then found=true end end;assert(found)
 assert(Run.endTurn(r));assert(s.player.block==14)
end)
test('normal obtain Clay actual HP-loss hooks creates next-turn block',function()
 local r,s=begin({'Self Forming Clay'});C.applyEffects(s,{{op='loseHp',value=1}},s.player)
 assert(s.player.statuses.next_turn_block==3);assert(Run.endTurn(r));assert(s.player.block==3)
end)
test('normal obtain Ink Bottle carries ten-play counter and triggers real draw',function()
 local r,s=begin({'InkBottle'},{'defend','defend','defend','defend','defend','defend'})
 s.relicCounters.ink_bottle=9;local c=find(s,'defend');local count=#s.hand
 assert(Run.play(r,c.uid));assert(s.relicCounters.ink_bottle==0 and #s.hand==count)
end)
test('normal obtain Sundial counts runtime shuffle and spends real energy action',function()
 local r,s=begin({'Sundial'},{'defend','defend','defend','defend','defend','defend'})
 s.relicCounters.sundial=2;s.discard=s.draw;s.draw={};local energy=s.energy
 C.draw(s,1);require('abyss_card_actions').drain(C,s)
 assert(s.energy==energy+2 and s.relicCounters.sundial==0)
end)
test('Toolbox pauses ordinary opening draw then resolves one choice without reroll',function()
 local r,s=begin({'Toolbox'});local p=assert(s.pendingChoice);assert(p.op=='toolbox'and #s.hand==0)
 local rng=s.cardRandomRng.counter;local token=p.token;local selected=p.cards[1].cardId
 assert(Run.chooseCard(r,token,1));assert(not s.pendingChoice and #s.hand==6 and s.energy==3)
 local found=false;for _,card in ipairs(s.hand)do if card.cardId==selected then found=true end end;assert(found)
 assert(s.cardRandomRng.counter==rng,'Toolbox rerolled on retrieval')
 assert(not Run.chooseCard(r,token,1));assert(s.cardRandomRng.counter==rng)
end)
test('Mummified Hand actual power play makes an eligible strike free this turn',function()
 local r,s=begin({'Mummified Hand'},{'inflame','strike','strike','strike','strike','strike'})
 local power=find(s,'inflame');assert(Run.play(r,power.uid))
 local free;for _,card in ipairs(s.hand)do if card.cardId=='strike'and C.cardDefinition(s,card).cost==0 then free=card end end
 assert(free);local energy=s.energy;assert(Run.play(r,free.uid,1));assert(s.energy==energy)
 assert(Run.endTurn(r));for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,card in ipairs(pile)do if card.cardId=='strike'then assert(C.cardDefinition(s,card).cost==1)end end end
end)
test('Gremlin Horn actual death grants energy and draw only before final enemy',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Gremlin Horn'))
 r.deck={};for i=1,7 do r.deck[i]={uid=i,cardId='strike'}end;r.nextDeckUid=8
 assert(Run.startCombat(r,'louse_pair'));local s=r.combat
 for _,enemy in ipairs(s.enemies)do enemy.hp=1 end
 local before=#s.hand;assert(Run.play(r,find(s,'strike').uid,1));assert(s.energy==3 and #s.hand==before)
 assert(Run.play(r,find(s,'strike').uid,2));assert(s.energy==2 and #s.hand==before-1)
end)
test('Meat triggers before Burning Blood once at the exact half-HP boundary',function()
 local function win(hp,bloom)
  local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Meat on the Bone'));if bloom then assert(Run.obtainRelic(r,'Mark of the Bloom'))end
  r.hp=hp;r.maxHp=80;assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;s.enemies[1].hp=1
  local card=find(s,'strike');assert(Run.play(r,card.uid,1));return r,card
 end
 local r,card=win(40);assert(r.hp==58 and r.phase=='reward')
 assert(not Run.play(r,card.uid,1));assert(r.hp==58,'victory healing repeated')
 assert(win(41).hp==47,'Meat fired above half HP')
 assert(win(40,true).hp==40,'Bloom allowed victory healing')
end)
print('LUA_UNCOMMON_RELIC_LIFECYCLE_PASS '..n)
