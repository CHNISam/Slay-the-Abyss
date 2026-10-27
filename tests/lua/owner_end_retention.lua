package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Actions=require('abyss_combat'),require('abyss_card_actions')
local D=require('abyss_silent_final_cards').withCardDefinitions(require('abyss_warrior_strength_cards').withCards(require('abyss_character_profiles').prepare(require('abyss_data'),'watcher')))
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function play(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid));return end end;error('missing real Power')end
for _,advanced in ipairs({false,true})do
 local s=C.new(D,{deck={'combust','establishment','well_laid_plans'},enemies={'cultist'},seed=42,enableStances=true,orbSlots=0,cardRandomSeed='42'})
 s.experimentalMechanics=advanced
 for _,id in ipairs({'combust','establishment','well_laid_plans'})do play(s,id)end
 local cards={};for _,id in ipairs({'defend_purple','protect','sands_of_time','dazed'})do local c=Actions.fresh(C,s,id);Actions.toHand(s,c);cards[id]=c end
 local hp,enemy=s.player.hp,s.enemies[1].hp
 assert(C.endTurn(s));local q=s.actionQueue;local p=s.pendingChoice
 assert(q and q.paused and q.current.effect.op=='ownerEndRetain');assert(p and p.kind=='retain')
 eq(s.player.hp,hp-1);eq(s.enemies[1].hp,enemy-5);eq(C.cardDefinition(s,cards.defend_purple).cost,1);eq(#s.exhaust,0)
 eq(C.endTurn(s),false);eq(C.play(s,cards.defend_purple.uid),false)
 assert(C.chooseCard(s,p.token,cards.defend_purple.uid));assert(C.chooseCard(s,s.pendingChoice.token,0))
 eq(s.actionQueue,nil);eq(s.pendingChoice,nil);eq(s.player.hp,hp-1);eq(s.enemies[1].hp,enemy-5)
 eq(s.exhaust[1].uid,cards.dazed.uid);eq(C.cardDefinition(s,cards.defend_purple).cost,0);eq(C.cardDefinition(s,cards.protect).cost,1);eq(C.cardDefinition(s,cards.sands_of_time).cost,2)
 eq(cards.defend_purple.retain,nil);eq(cards.protect.retain,nil);eq(cards.sands_of_time.retain,nil)
 eq(cards.sands_of_time.retainedTurn,1);eq(s.turn,2)
 print('PASS same ordinary queue pauses WLP -> Establishment25 -> Ethereal -> retained callbacks once '..tostring(advanced))
end
print('OWNER_END_RETENTION_PASS')
