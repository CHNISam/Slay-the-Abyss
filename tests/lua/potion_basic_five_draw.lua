local H=dofile('tests/lua/support/potion_basic_five_fixture.lua')
local Run,C,A,Data=H.Run,H.C,H.A,H.Data
local test,eq,same,battle,refuse,starter,use=H.test,H.eq,H.same,H.battle,H.refuse,H.starter,H.use
test('Swift draws three actual top instances without spending source RNG when no shuffle is needed',function()
 local run=battle({'swift_potion'});local s=run.combat
 local hand=#s.hand;local expected={s.draw[#s.draw],s.draw[#s.draw-1],s.draw[#s.draw-2]}
 local rng=C.copy(s.shuffleRng);use(run,1);eq(#s.hand,hand+3);same(s.shuffleRng,rng)
 for i=1,3 do eq(s.hand[hand+i].uid,expected[i].uid) end
end)
test('Swift stops at ten, and a full hand still consumes exactly one bottle without drawing',function()
 local run=battle({'swift_potion','swift_potion'});local s=run.combat
 C.draw(s,4);eq(#s.hand,9);local rng=C.copy(s.shuffleRng)
 use(run,1);eq(#s.hand,10);same(s.shuffleRng,rng)
 local piles=C.copy({s.hand,s.draw,s.discard});use(run,2);same({s.hand,s.draw,s.discard},piles);same(s.shuffleRng,rng)
end)
test('Swift at exhausted piles causes no fatigue damage or RNG draw',function()
 local run=battle({'swift_potion'},starter({'defend','defend','defend','defend','defend'}))
 local s=run.combat;eq(#s.draw,0);eq(#s.discard,0);local before=C.copy(s)
 use(run,1);eq(#s.hand,5);eq(s.player.hp,before.player.hp);same(s.shuffleRng,before.shuffleRng)
end)
test('Swift respects No Draw applied by a real Battle Trance card and still consumes the bottle',function()
 local run=battle({'swift_potion'},starter({'battle_trance','defend','defend','defend','defend'}))
 local s=run.combat;local uid
 for _,card in ipairs(s.hand) do if card.cardId=='battle_trance' then uid=card.uid end end
 assert(Run.play(run,uid));assert(s.player.noDraw)
 local before=C.copy({s.hand,s.draw,s.discard,s.shuffleRng});use(run,1);same({s.hand,s.draw,s.discard,s.shuffleRng},before)
end)
test('Swift crosses an empty draw pile using the existing source shuffle and draws only available cards',function()
 local run=battle({'swift_potion'},starter({'defend','defend','defend','defend','defend','defend'}))
 local s=run.combat;local uid=s.hand[1].uid;assert(Run.play(run,uid));eq(#s.draw,1);eq(#s.discard,1)
 local top=s.draw[1].uid;local hand=#s.hand;local counter=s.shuffleRng.counter
 use(run,1);eq(#s.hand,hand+2);eq(s.hand[hand+1].uid,top);eq(s.hand[hand+2].uid,uid)
 -- DrawCardAction splits again after the singleton, scheduling the final empty shuffle.
 eq(#s.draw,0);eq(#s.discard,0);eq(s.shuffleRng.counter,counter+2)
end)
H.finish(5,'LUA_POTION_BASIC_FIVE_DRAW_PASS')
