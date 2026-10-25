package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data,Actions,Actors=require('abyss_combat'),require('abyss_data'),require('abyss_card_actions'),require('abyss_actor')
local passed,failed=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(e))end end
local function battle(deck,hp)
 local d=C.copy(Data);local e=d.enemies.enemies[1];e.ai=nil;e.intents={{id='quiet',kind='stunned',effects={}}}
 return C.new(d,{enemies={e.id},deck=deck,hp=hp or 80,seed=51})
end
local function held(s,id) for _,c in ipairs(s.hand)do if c.cardId==id then return c end end end
local function put(s,id) local c=Actions.fresh(C,s,id);s.hand[#s.hand+1]=c;return c end
local function play(s,id) return C.play(s,assert(held(s,id),'missing '..id).uid,1) end
local function kinds(s,kind) local result={};for _,e in ipairs(s.events)do if e.kind==kind then result[#result+1]=e end end;return result end
test('ten basic curses are implemented and cannot play or upgrade',function()
 local cap=require('abyss_card_capability');local ids={'regret','injury','shame','parasite','normality','doubt','writhe','pain','decay','clumsy'}
 for _,id in ipairs(ids)do local s=battle({id});local c=s.hand[1];assert(cap.isImplemented(s.catalog.cards[id]),id);local ok,why=C.canPlay(s,c.uid);eq(ok,false);eq(why,'unplayable_card');eq(C.canUpgrade(s,c),false) end
 assert(not cap.isImplemented({id='unknown',type='curse',cost=-2,effects={}}))
end)
test('Injury and Parasite occupy hand and discard without HP loss',function()
 local s=battle({'injury','parasite'});assert(C.endTurn(s));eq(s.player.hp,80);eq(s.player.maxHp,80);eq(#s.exhaust,0)
end)
test('Pain loses HP before card block and ignores existing block',function()
 local s=battle({'pain','defend'});s.player.block=9;s.events={};assert(play(s,'defend'));eq(s.player.hp,79);eq(s.player.block,14)
 local loss=kinds(s,'hp_loss');eq(#loss,1);eq(loss[1].frame.player.block,9)
end)
test('Pain lethal prevents card effect and retains card in use',function()
 local s=battle({'pain','defend'},1);assert(play(s,'defend'));eq(s.phase,'defeat');eq(s.player.block,0);eq(s.cardInUse.cardId,'defend');eq(#s.discard,0)
end)
test('each Pain is a separate HP-loss event with Rupture and Blood for Blood',function()
 local s=battle({'pain','pain','blood_for_blood','defend'});C.addStatus(s.player,'rupture',2);assert(play(s,'defend'));eq(s.player.hp,78);eq(s.player.statuses.strength,4);eq(held(s,'blood_for_blood').costReduction,2)
end)
test('Pain triggers for queued Double Tap copy before both attacks',function()
 local s=battle({'pain','strike'});s.enemies[1].hp=100;s.enemies[1].maxHp=100;C.addStatus(s.player,'double_tap',1);s.events={};assert(play(s,'strike'));eq(s.player.hp,78);eq(#kinds(s,'hp_loss'),2)
 local trace={};for _,e in ipairs(s.events)do if e.kind=='hp_loss' or e.kind=='damage' then trace[#trace+1]=e.kind end end;eq(table.concat(trace,','),'hp_loss,damage,hp_loss,damage')
end)
test('Pain top HP loss precedes Enrage and lethal Pain cancels that queued power',function()
 for _,hp in ipairs({80,1})do
  local s=battle({'pain','defend'},hp);C.addStatus(s.enemies[1],'enrage',2);s.events={};assert(play(s,'defend'))
  if hp==1 then eq(s.enemies[1].statuses.strength or 0,0)
  else local trace={};for _,e in ipairs(s.events)do if e.kind=='hp_loss' or e.kind=='status' and e.detail.status=='strength' then trace[#trace+1]=e.kind end end;eq(table.concat(trace,','),'hp_loss,status') end
 end
end)
test('Decay is two fixed self damage blocked by Block and no normal modifiers',function()
 local s=battle({'decay'});s.player.block=1;C.addStatus(s.player,'weak',2);C.addStatus(s.player,'vulnerable',2);C.addStatus(s.player,'strength',99);C.addStatus(s.player,'thorns',99);assert(C.endTurn(s));eq(s.player.hp,79)
end)
test('Doubt and Shame spend Artifact in hand order without ordinary plays or Pain',function()
 local s=battle({'doubt','shame','pain'});s.hand={held(s,'shame'),held(s,'doubt'),held(s,'pain')};C.addStatus(s.player,'artifact',1);s.events={};assert(C.endTurn(s));eq(s.player.statuses.artifact,0);eq(s.player.statuses.frail or 0,0);eq(s.player.statuses.weak,1);eq(s.player.hp,80);eq(#kinds(s,'play'),0)
end)
test('Doubt and Shame newly applied last through following player turn',function()
 local s=battle({'doubt','shame'});assert(C.endTurn(s));eq(s.player.statuses.weak,1);eq(s.player.statuses.frail,1);eq(s.player.weakJustApplied,nil);eq(s.player.frailJustApplied,nil)
 s.hand={};s.draw={};s.discard={};assert(C.endTurn(s));eq(s.player.statuses.weak or 0,0);eq(s.player.statuses.frail or 0,0)
end)
test('existing Weak stack does not regain first-tick immunity from Doubt',function()
 local s=battle({'doubt'});C.addStatus(s.player,'weak',2);assert(C.endTurn(s));eq(s.player.statuses.weak,2)
end)
test('end-turn Regret snapshots include Clumsy before later exhaust callbacks',function()
 local s=battle({'clumsy','regret','decay'});s.hand={held(s,'clumsy'),held(s,'regret'),held(s,'decay')};C.addStatus(s.player,'feel_no_pain',3);s.events={};assert(C.endTurn(s));eq(s.player.hp,75);eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'clumsy')
 local trace={};for _,e in ipairs(s.events)do if e.kind=='hp_loss' or e.kind=='damage' or e.kind=='exhaust' then trace[#trace+1]=e.kind end end;eq(table.concat(trace,','),'hp_loss,damage,exhaust')
end)
test('Writhe is innate in opening hand and never exhausts itself',function()
 local deck={'strike','defend','strike','defend','strike','defend','writhe'};for seed=1,5 do local s=battle(deck);assert(held(s,'writhe'));assert(C.endTurn(s));eq(#s.exhaust,0) end
end)
test('Normality counts earlier plays and releases immediately when removed',function()
 local s=battle({'anger','anger','anger','anger'});s.enemies[1].hp=100;s.enemies[1].maxHp=100
 for _=1,3 do assert(play(s,'anger')) end;put(s,'normality');local c=held(s,'anger');local before=s.energy;local ok,why=C.canPlay(s,c.uid,1);eq(ok,false);eq(why,'normality_limit');eq(C.play(s,c.uid,1),false);eq(s.energy,before)
 for i,v in ipairs(s.hand)do if v.cardId=='normality'then table.remove(s.hand,i);break end end;assert(C.play(s,c.uid,1))
end)
test('Normality counts Double Tap repeats and blocks queued autoplay fourth card',function()
 local s=battle({'normality','anger','anger','havoc'});s.enemies[1].hp=100;s.enemies[1].maxHp=100;C.addStatus(s.player,'double_tap',1);assert(play(s,'anger'));eq(s.cardsPlayedThisTurn,2)
 s.draw={Actions.fresh(C,s,'strike')};s.discard={};assert(play(s,'havoc'));eq(s.cardsPlayedThisTurn,3);eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'strike')
end)
test('Normality turn count resets before opening draw on next turn',function()
 local s=battle({'normality','anger','anger','anger'});s.enemies[1].hp=100;s.enemies[1].maxHp=100;for _=1,3 do assert(play(s,'anger')) end;assert(C.endTurn(s));eq(s.cardsPlayedThisTurn,0)
end)
test('Parasite permanent removal loses max HP with source minimum and clamps only current HP',function()
 local curses=require('abyss_curses')
 for _,v in ipairs({{80,79,77,77},{80,20,77,20},{3,3,1,1},{1,1,1,1}})do local owner={maxHp=v[1],hp=v[2]};curses.onRemove(owner,{cardId='parasite'});eq(owner.maxHp,v[3]);eq(owner.hp,v[4]) end
 local owner={maxHp=80,hp=20};curses.onRemove(owner,'injury');eq(owner.maxHp,80);eq(owner.hp,20)
end)
test('Clumsy exhausts exactly once and its draws do not run new end-turn curse hooks',function()
 local s=battle({'clumsy'});s.draw={Actions.fresh(C,s,'decay')};C.addStatus(s.player,'dark_embrace',1);s.events={};assert(C.endTurn(s));eq(s.player.hp,80);eq(#s.exhaust,1);eq(#kinds(s,'exhaust'),1)
end)
test('new Decay lifetime consumes Block from Metallicize before ethereal Feel No Pain',function()
 local s=battle({'clumsy','decay'});C.addStatus(s.player,'metallicize',1);C.addStatus(s.player,'feel_no_pain',9);s.events={};assert(C.endTurn(s));eq(s.player.hp,79)
 local d=kinds(s,'damage');eq(#d,1);eq(d[1].detail.blocked,1);eq(d[1].detail.amount,1)
end)
assert(failed==0,tostring(failed)..' basic curse tests failed');print('BASIC_CURSES_PASS '..passed)
