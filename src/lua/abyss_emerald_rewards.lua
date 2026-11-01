-- Run/Nodes bridge for immutable chapter birth facts and independent key items.
-- Only Nodes binds a successfully chosen source-map elite; never an explicit ID.
local E=require('abyss_emerald_elite')
local Copy=require('abyss_copy').copy
local M={}
local function plain(value)return type(value)=='table'and getmetatable(value)==nil end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(b)~='table'then return a==b end
 if not plain(a)then return false end
 for k,v in pairs(b)do if not same(a[k],v)then return false end end
 for k in pairs(a)do if b[k]==nil then return false end end
 return true
end
local function keys(run)
 local k=run.keys
 return plain(k)and type(k.ruby)=='boolean'and type(k.emerald)=='boolean'and type(k.sapphire)=='boolean'
end
local function birth(context)
 if not plain(context)or type(context.endingUnlocked)~='boolean'or type(context.emeraldOwned)~='boolean'then return false end
 for key in pairs(context)do if key~='endingUnlocked'and key~='emeraldOwned'then return false end end
 return true
end
function M.mapContext(run)
 if run.mapBirthAct~=(run.act or 1)or not birth(run.mapBirthContext)then return nil,'map_birth_context_unavailable'end
 return Copy(run.mapBirthContext)
end
function M.freezeMapContext(run)
 if run.mapBirthAct==(run.act or 1)then return M.mapContext(run)end
 local act=run.act or 1
 if act~=1 and act~=2 and act~=3 and act~=4 then return nil,'invalid_act'end
 if run.campaign==true and not keys(run)then return nil,'invalid_keys'end
 run.mapBirthContext={endingUnlocked=run.campaignProfile~='competition-two-act' and run.campaign==true and run.endingUnlocked==true,
  emeraldOwned=run.campaign==true and run.keys.emerald==true or false}
 run.mapBirthAct=act
 return Copy(run.mapBirthContext)
end
function M.bind(run,boost)
 if not plain(boost)or not plain(boost.effect)or not run.combat or not run.combat.roomSeed
  or boost.runSeed~=run.runSeed or boost.effect.act~=(run.act or 1)or run.encounterTier~='elite'
  or not run.encounterSource or run.combat.combatGeneration~=run.combatGeneration then return nil,'invalid_emerald_combat_owner'end
 return {boost=Copy(boost),combatGeneration=run.combatGeneration,encounterId=run.encounterId,
  sourceEncounter=run.encounterSource,floor=run.floor}
end
local function context(run)
 local owner,flow,battle=run.emeraldCombat,run.nodeFlow,run.combat
 local initial=M.mapContext(run)
 if not initial or not initial.endingUnlocked or initial.emeraldOwned or not keys(run)
  or not plain(owner)or not plain(owner.boost)or not plain(flow)or not battle then return end
 local boost=owner.boost
 if run.campaign~=true or run.encounterTier~='elite'or flow.type~='elite'
  or owner.encounterId~=run.encounterId or owner.sourceEncounter~=run.encounterSource
  or owner.combatGeneration~=run.combatGeneration or battle.combatGeneration~=owner.combatGeneration
  or flow.encounterId~=owner.encounterId or flow.encounterSource~=owner.sourceEncounter
  or owner.floor~=run.floor or flow.floor~=owner.floor or flow.id~=boost.nodeId
  or flow.mapSeed~=boost.runSeed or flow.mapSignature~=boost.mapSignature
  or boost.runSeed~=run.runSeed or boost.effect.act~=run.act
  or not same(flow.emeraldBoost,boost)or not run.lastResult or run.lastResult.encounterId~=owner.encounterId then return end
 return {endingUnlocked=run.endingUnlocked==true,emeraldOwned=run.keys.emerald,
  marked=true,roomClass='elite',outcome=run.lastResult.outcome,smoked=battle.smoked==true,
  runSeed=run.runSeed,act=run.act,floor=run.floor,nodeId=flow.id,
  sourceEncounter=owner.sourceEncounter,combatGeneration=owner.combatGeneration,phase=run.phase}
end
function M.offer(run,rewardCount)
 if not run.emeraldCombat then return nil end
 local binding=context(run)
 if not binding then return nil,'emerald_reward_owner_mismatch'end
 return E.rewardOwner(binding,rewardCount)
end
function M.claim(run)
 local binding=context(run)
 local offer=run.phase=='reward'and run.rewards and run.rewards.emeraldKey
 if not binding or not offer then return false,'no_pending_emerald_key'end
 return E.claim(offer,binding,function()run.keys.emerald=true;return true end)
end
function M.canClaim(run)
 local binding=context(run)
 local offer=run.phase=='reward'and run.rewards and run.rewards.emeraldKey
 return binding~=nil and offer~=nil and E.canClaim(offer,binding)or false
end
return M
