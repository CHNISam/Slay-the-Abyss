package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Actions,R,Retained=require('abyss_combat'),require('abyss_card_actions'),require('abyss_sts_random'),require('abyss_retained_cards')
local D=require('abyss_silent_final_cards').withCardDefinitions(require('abyss_warrior_strength_cards').withCards(require('abyss_character_profiles').prepare(require('abyss_data'),'watcher')))
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function fresh(advanced,deck)
 local s=C.new(D,{deck=deck,enemies={'cultist'},seed=42,enableStances=true,orbSlots=0,cardRandomSeed='42'})
 s.experimentalMechanics=advanced;return s
end
local function play(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid));return end end;error('missing real Power')end
for _,advanced in ipairs({false,true})do
 local s=fresh(advanced,{'combust','study'});play(s,'combust');play(s,'study');s.player.hp=20
 C.applyEffects(s,{{op='gainStatus',status='regen',value=3}},s.player)
 local burn=Actions.fresh(C,s,'burn');burn.costForTurn=0;Actions.toHand(s,burn)
 s.draw[#s.draw+1]=Actions.fresh(C,s,'defend_purple')
 local before=C.copy(s);local hand,draw,discard,player,enemy,rng=s.hand,s.draw,s.discard,s.player,s.enemies[1],s.cardRandomRng
 local original=R.randomInt;local fired=false
 R.randomInt=function(stream,max)
  local result=original(stream,max)
  if stream==rng then eq(s.player.statuses.regen,2);eq(s.enemies[1].hp,before.enemies[1].hp-5);fired=true;error('INJECTED_OWNER_END_STUDY_RNG')end
  return result
 end
 local ok,why=pcall(C.endTurn,s);R.randomInt=original
 assert(not ok and tostring(why):find('INJECTED_OWNER_END_STUDY_RNG',1,true)and fired)
 same(s,before);eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.player,player);eq(s.enemies[1],enemy);eq(s.cardRandomRng,rng);eq(burn.costForTurn,0)
 print('PASS whole endTurn rollback after Burn/Regen/Combust/Study RNG failure with original graphs '..tostring(advanced))
 local t=fresh(advanced,{'combust','establishment','well_laid_plans'});for _,id in ipairs({'combust','establishment','well_laid_plans'})do play(t,id)end
 local cards={};for _,id in ipairs({'defend_purple','perseverance','dazed'})do local c=Actions.fresh(C,t,id);Actions.toHand(t,c);cards[id]=c end
 assert(C.endTurn(t));assert(C.chooseCard(t,t.pendingChoice.token,cards.defend_purple.uid))
 local pending,queue=t.pendingChoice,t.actionQueue;before=C.copy(t);local retained=Retained.onRetained;fired=false
 Retained.onRetained=function(state,card)
  local accepted,intent=retained(state,card)
  if card==cards.perseverance then
   eq(card.retainedBlockBonus,2);eq(state.exhaust[1].uid,cards.dazed.uid);eq(C.cardDefinition(state,cards.defend_purple).cost,0)
   fired=true;error('INJECTED_LATE_RETAINED_CALLBACK')
  end
  return accepted,intent
 end
 ok,why=pcall(C.chooseCard,t,pending.token,0);Retained.onRetained=retained
 assert(not ok and tostring(why):find('INJECTED_LATE_RETAINED_CALLBACK',1,true)and fired)
 same(t,before);eq(t.pendingChoice,pending);eq(t.actionQueue,queue);eq(queue.paused,true);eq(C.cardDefinition(t,cards.defend_purple).cost,1)
 assert(C.chooseCard(t,pending.token,0));eq(cards.perseverance.retainedBlockBonus,2);eq(t.pendingChoice,nil);eq(t.actionQueue,nil)
 print('PASS same WLP continuation survives late retained callback failure, original pending/queue, retry once '..tostring(advanced))
end
print('OWNER_END_ROLLBACK_PASS')
