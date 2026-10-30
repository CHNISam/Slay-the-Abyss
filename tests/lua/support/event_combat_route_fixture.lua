-- Controlled source-room components, not natural event selection or Act1 wins.
-- Inventory, HP, card values and RNG words are never rewritten to win a fight.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C,R,D=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for key,value in pairs(a)do same(value,b[key])end;for key in pairs(b)do assert(a[key]~=nil)end
end
local function event(seed,id)
 local run=Run.new(D,seed,{experimental=true,campaign=true});local map=Map.generate(D,seed,2)
 run.act,run.floor=2,17;run.encounters=require('abyss_encounter_queue').new(seed,2)
 run.unknown.pools=require('abyss_event_pool').new('full',false,2)
 local first=Map.available(map)[1]
 for _,node in ipairs(map.nodes)do if node.id==first.id then node.type,node.eventId='event',id end end
 local accepted,why=Nodes.enter(run,map,first.id);assert(accepted,why)
 return run,map
end
local function target(run)
 local index
 for i,enemy in ipairs(run.combat.enemies)do if enemy.hp>0 and not enemy.escaped then
  if not index or enemy.hp<run.combat.enemies[index].hp then index=i end
 end end
 return index
end
local function playStarterBattle(run)
 -- Fixed legal policy only. No direct damage, relic/card grants or outcome flag.
 for _=1,20 do
  if run.phase~='combat'then return end
  local attempted={}
  while run.phase=='combat'do
   local battle=run.combat;local pick,priority
   for _,card in ipairs(battle.hand)do
    local definition=battle.catalog.cards[card.cardId]
    local cost=definition.cost
    if card.upgraded and definition.upgrade and definition.upgrade.cost then cost=definition.upgrade.cost end
    local score=definition.type=='attack'and 10 or 1
    if card.cardId=='bash'and battle.energy>=3 then score=20 end
    if not attempted[card.uid]and type(cost)=='number'and cost>=0 and cost<=battle.energy and(not priority or score>priority)then pick,priority=card,score end
   end
   if not pick then break end
   attempted[pick.uid]=true;Run.play(run,pick.uid,target(run))
  end
  if run.phase=='combat'then assert(Run.endTurn(run))end
 end
 assert(run.phase~='combat','bounded legal starter policy did not reach an outcome')
end
return {Run=Run,N=Nodes,Map=Map,C=C,R=R,D=D,event=event,same=same,playStarterBattle=playStarterBattle}
