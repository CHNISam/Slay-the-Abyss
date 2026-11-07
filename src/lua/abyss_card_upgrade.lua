-- Card-instance upgrade eligibility, cost and metadata rules only.
-- Hosts retain card selection, custody, queues and transaction rollback.
local copy=require('abyss_copy').copy
local M={}
local MAX=2147483647
local function integer(n,lo) return type(n)=='number' and n==n and n%1==0 and n>=(lo or 0) and n<=MAX end

function M.combatBaseCost(state, instance)
    local def=assert(state.catalog.cards[instance.cardId])
    if def.costMode=='all_energy' then return -1 end
    local cost=instance.upgraded and def.upgrade and def.upgrade.cost or def.cost
    if instance.costOverride~=nil then cost=instance.costOverride end
    if instance.cardId=='masterful_stab'then cost=instance.combatCost or (instance.costOverride~=nil and cost or cost+(instance.masterfulLosses or 0))end
    if instance.cardId=='blood_for_blood' then cost=math.max(0,cost-(instance.costReduction or 0)) end
    return cost
end

-- SearingBlow(int n) keeps timesUpgraded but resets baseDamage/upgraded.
-- A source makeCopy constructor records this count-only baseline; ordinary
-- instances without it retain the original cumulative upgrade formula.
function M.validSearingBlowCopy(instance)
    local base=instance.searingBlowCopyUpgrades
    if base==nil then return true end
    local n=instance.upgrades
    return instance.cardId=='searing_blow' and type(base)=='number' and base%1==0 and base>=0 and base<=2147483647
        and type(n)=='number' and n%1==0 and n>=base and n<=2147483647
        and type(instance.upgraded)=='boolean' and instance.upgraded==(n>base)
end

local function resolved(s,c)
 local d=copy(assert(s.catalog.cards[c.cardId],'unknown status-build card'))
 if c.upgraded then for k,v in pairs(d.upgrade or {}) do d[k]=copy(v) end end;return d
end
local function cost(s,c)
 local d=resolved(s,c);local base=c.combatCost or d.cost;local turn=c.turnCost
 if turn==nil then turn=base end
 assert(integer(base) and integer(turn),'invalid Blood for Blood cost metadata');return base,turn
end
M.statusDefinition=resolved
M.bloodCost=cost

-- Host invokes before changing the upgraded flag. Catalog upgrade damage is
-- still applied by ordinary definition merging, never copied into the instance.
function M.onUpgrade(s,c)
 assert(c.cardId=='blood_for_blood' and not c.upgraded,'invalid Blood for Blood upgrade')
 local base,turn=cost(s,c);local rawBase=base<4 and base-1 or 3
 c.combatCost=math.max(0,rawBase);c.turnCost=turn>0 and math.max(0,rawBase+turn-base) or 0
 return true
end

function M.canUpgrade(state,instance)
    local d=state.catalog.cards[instance.cardId]
    return M.validSearingBlowCopy(instance) and d and d.type~='status' and d.type~='curse' and d.upgrade~=nil and (not instance.upgraded or d.repeatable==true)
end
local function upgradeBloodCost(state,instance)
    if instance.combatCost==nil then instance.combatCost=M.combatBaseCost(state,instance) end
    if instance.turnCost==nil and instance.costForTurn~=nil then instance.turnCost=instance.costForTurn end
    M.onUpgrade(state,instance)
    instance.costOverride,instance.costReduction=nil,nil
    if instance.costForTurn~=nil then instance.costForTurn=instance.turnCost end
end

local function upgradeRetainedCost(state,instance,def)
    local before=M.combatBaseCost(state,instance)
    local turn=instance.costForTurn or before
    local diff=turn-before
    local nextCost=def.upgrade.cost
    instance.costOverride=nil
    if turn>0 then instance.costForTurn=math.max(0,nextCost+diff) end
end

function M.upgrade(state,instance)
    if not M.canUpgrade(state,instance) then return false end
    local def=state.catalog.cards[instance.cardId]
    if instance.cardId=='blood_for_blood' and not instance.upgraded then
        upgradeBloodCost(state,instance)
    elseif def.upgrade.cost~=nil and (instance.costOverride~=nil or instance.costForTurn~=nil) then
        upgradeRetainedCost(state,instance,def)
    end
    instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
    instance.upgraded=true;return true
end

return M
