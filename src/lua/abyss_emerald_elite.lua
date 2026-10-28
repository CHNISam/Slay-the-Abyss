-- Fixed319009 source component. Host owns real qualification, mapRng lifetime,
-- legal room entry, battle callbacks and enclosing transaction/rollback.
local R=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
local M={}
local firstFloor={1,18,35}
local selectionFields={version=true,act=true,nodeId=true,x=true,y=true}
local bindingFields={'runSeed','act','floor','nodeId','sourceEncounter','combatGeneration'}
local offerFields={version=true,type=true,claimed=true}
for _,key in ipairs(bindingFields)do offerFields[key]=true end
local function plain(value)return type(value)=='table'and getmetatable(value)==nil end
local function integer(value,lo,hi)
 return type(value)=='number'and value%1==0 and value>=lo and value<=hi
end
local function text(value)return type(value)=='string'and #value>0 end
local function exact(value,fields)
 if not plain(value)then return false end
 for key in pairs(value)do if not fields[key]then return false end end
 return true
end
local function array(value)
 if not plain(value)then return false end
 local count=0
 for key in pairs(value)do if not integer(key,1,#value)then return false end;count=count+1 end
 return count==#value
end
local function selected(value,boost)
 local fields=selectionFields
 if boost then fields=Copy(fields);fields.roll=true end
 return exact(value,fields)and value.version==1 and integer(value.act,1,3)
  and text(value.nodeId)and integer(value.x,0,6)and integer(value.y,0,14)
  and (not boost or integer(value.roll,0,3))
end
local function candidates(map,act)
 if not array(map.nodes)then return nil end
 local result,ids,positions={},{},{}
 for _,node in ipairs(map.nodes)do
  if not plain(node)then return nil end
  if node.type=='elite'then
   local x,y=node.x,node.y
   if x==nil and y==nil then
    if not integer(node.floor,firstFloor[act],firstFloor[act]+14)or not integer(node.lane,1,7)then return nil end
    x,y=node.lane-1,node.floor-firstFloor[act]
   end
   if not text(node.id)or not integer(x,0,6)or not integer(y,0,14)then return nil end
   local position=x..':'..y
   if ids[node.id]or positions[position]then return nil end
   ids[node.id],positions[position]=true,true
   result[#result+1]={version=1,act=act,nodeId=node.id,x=x,y=y}
  end
 end
 table.sort(result,function(a,b)if a.y~=b.y then return a.y<b.y end;return a.x<b.x end)
 return result
end
-- Selection never seeds an RNG or mutates the supplied graph/stream. Disabled
-- eligibility and TheEnding return an unchanged private stream, without a draw.
function M.select(map,mapRng,context)
 if not plain(map)or not plain(context)or type(context.endingUnlocked)~='boolean'
  or type(context.emeraldOwned)~='boolean'then return nil,nil,'invalid_emerald_context'end
 local act=map.act
 if act==nil then act=1 end
 if not integer(act,1,4)then return nil,nil,'invalid_act'end
 local ok,nextRng=pcall(R.cloneState,mapRng)
 if not ok then return nil,nil,'invalid_map_rng'end
 if act==4 or not context.endingUnlocked or context.emeraldOwned then return nil,nextRng end
 if map.firstFloor~=nil and map.firstFloor~=firstFloor[act]then return nil,nil,'invalid_map_floor'end
 local nodes=candidates(map,act)
 if not nodes then return nil,nil,'invalid_elite_nodes'end
 if #nodes==0 then return nil,nil,'no_elite_nodes'end
 return nodes[R.randomIntBetween(nextRng,0,#nodes-1)+1],nextRng
end
-- Caller invokes this once at actual marked-room entry, not during map creation.
function M.prepare(selection,mapRng)
 if not selected(selection,false)then return nil,nil,'invalid_emerald_selection'end
 local ok,nextRng=pcall(R.cloneState,mapRng)
 if not ok then return nil,nil,'invalid_map_rng'end
 local boost=Copy(selection);boost.roll=R.randomIntBetween(nextRng,0,3)
 return boost,nextRng
end
local function actorsValid(actors)
 if not array(actors)or #actors==0 then return false end
 local ids={}
 for _,actor in ipairs(actors)do
  if not plain(actor)or not text(actor.id)or ids[actor.id]
   or not integer(actor.maxHp,1,2147483647)or not integer(actor.hp,0,actor.maxHp)then return false end
  ids[actor.id]=true
 end
 return true
end
-- Callback only: no status catalog, heal routing or ordinary-monster Regen is
-- installed here. Caller must enqueue source actions inside its transaction.
function M.apply(actors,boost,api)
 if not selected(boost,true)or not actorsValid(actors)or not plain(api)then return false,'invalid_emerald_boost'end
 local health=boost.roll==1
 local apply=api.applyPower
 if health then apply=api.increaseMaxHp end
 if type(apply)~='function'then return false,'emerald_callback_required'end
 local initial={};for i,actor in ipairs(actors)do initial[i]=actor end
 for _,actor in ipairs(initial)do
  local ok,why
  if health then
   local increase=math.floor(R.float32(actor.maxHp*.25)+.5)
   ok,why=apply(actor,increase)
  else
   local id=boost.roll==0 and 'strength'or boost.roll==2 and 'metallicize'or 'regenerate_monster'
   local n=boost.roll==0 and boost.act+1 or boost.roll==2 and boost.act*2+2 or boost.act*2+1
   ok,why=apply(actor,id,n)
  end
  if ok~=true then return false,why or 'emerald_callback_failed'end
 end
 return true
end
local function binding(context)
 return plain(context)and text(context.runSeed)and integer(context.act,1,3)
  and integer(context.floor,firstFloor[context.act],firstFloor[context.act]+14)
  and text(context.nodeId)and text(context.sourceEncounter)and integer(context.combatGeneration,1,2147483647)
end
local function rewardEligible(context)
 return binding(context)and context.endingUnlocked==true and context.emeraldOwned==false
  and context.marked==true and context.roomClass=='elite'and context.outcome=='victory'and context.smoked==false
end
-- This helper trusts the caller's actual room/result context. It never sets a
-- Run key, synthesizes qualification, substitutes a relic or proves natural play.
function M.rewardOwner(context,rewardCount)
 if not rewardEligible(context)or not integer(rewardCount,1,2147483647)then return nil,'emerald_reward_unavailable'end
 local offer={version=1,type='EMERALD_KEY',claimed=false}
 for _,key in ipairs(bindingFields)do offer[key]=context[key]end
 return offer
end
function M.canClaim(offer,context)
 if not exact(offer,offerFields)or offer.version~=1 or offer.type~='EMERALD_KEY'or offer.claimed~=false
  or not rewardEligible(context)or context.phase~='reward'then return false,'emerald_reward_owner_mismatch'end
 for _,key in ipairs(bindingFields)do
  if offer[key]~=context[key]then return false,'emerald_reward_owner_mismatch'end
 end
 return true
end
function M.claim(offer,context,obtain)
 local valid,why=M.canClaim(offer,context)
 if not valid then return false,why end
 if type(obtain)~='function'then return false,'emerald_callback_required'end
 local ok;ok,why=obtain()
 if ok~=true then return false,why or 'emerald_obtain_failed'end
 offer.claimed=true
 return true
end
return M
