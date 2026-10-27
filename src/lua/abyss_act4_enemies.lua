-- Final-act catalog and enemy lifecycle only. Combat retains queue ownership.
local Heart=require('abyss_corrupt_heart')
local Pair=require('abyss_spire_pair')
local Actors=require('abyss_actor')
local Copy=require('abyss_copy').copy
local M={}
function M.owns(enemy)return Heart.owns(enemy)or Pair.owns(enemy)end
function M.register(catalog)
 Heart.register(catalog,Copy);Pair.register(catalog,Copy)
end
function M.resolve(source,tier)
 if source=='The Heart'then
  if tier~='boss'then return nil,'encounter_tier_mismatch'end
  return {id='ending_heart',tier='boss',source=source,enemies={'corrupt_heart'}}
 end
 return Pair.resolve(source,tier)
end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
function M.validateIntent(enemy,intent)
 if not M.owns(enemy)then return false end
 local definition=Heart.owns(enemy)and Heart.enemy or nil
 if not definition then
  for _,candidate in ipairs(Pair.enemies)do if candidate.id==enemy.id then definition=candidate;break end end
 end
 assert(definition,'unknown final-act enemy identity')
 local expected
 for _,move in ipairs(definition.intents)do if move.id==intent.id then expected=move;break end end
 assert(expected and same(expected,intent),'unsupported final-act source intent')
 return true
end
local api={applyPower=Actors.applyPower,isActive=Actors.isActive}
function api.removePower(state,actor,id)
 local before=actor.statuses[id];if before==nil then return false end
 require('abyss_power_schedule').remove(state,actor,id);actor.statuses[id]=nil
 local order={};for _,old in ipairs(actor.powerOrder or {})do if old~=id then order[#order+1]=old end end
 actor.powerOrder=order
 require('abyss_events').emit(state,'status_removed',{target=actor.id,status=id,amount=-before})
 return true
end
function M.preBattle(state,enemy)
 if Pair.owns(enemy)then return Pair.preBattle(api,state,enemy)end
 for _,effect in ipairs(Heart.preBattle(state,enemy))do
  Actors.applyPower(state,enemy,effect.status,effect.value,enemy)
 end
end
function M.initialize(state,enemy,random)
 if Heart.owns(enemy)then return Heart.initialize(state,enemy,random)end
 return Pair.initialize(state,enemy,random)
end
function M.advance(state,enemy,random)
 if Heart.owns(enemy)then return Heart.advance(state,enemy,random)end
 return Pair.advance(state,enemy,random)
end
function M.afterAction(state,enemy,random,intent)
 if Pair.owns(enemy)then return Pair.afterAction(state,enemy,random,intent)end
 -- The existing queued RollMove owns its cancellation. Do not add a dead
 -- caster guard; it survives retaliation while another monster is alive.
 return Heart.advance(state,enemy,random)
end
return M
