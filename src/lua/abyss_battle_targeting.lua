-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Theme = require("abyss_theme")
local CardInput = require("abyss_card_input")
local EnemyView = require('abyss_battle_enemy_view')
local M = {}
local L = Theme.layout
-- Only this responsibility owns these closures; cross-responsibility calls are explicit ports.
function M.install(owner, _ownership, _host, dependencies)
    local D = L.cardDrag
    local function enemySlot(count, i, enemy)
        return EnemyView.position(count, i, enemy)
    end
    local function enemyPosition(battle,index)
        local entry,slot,count=EnemyView.find(battle,index,owner.busy and battle==owner.displayBattle and owner.feedback or nil)
        assert(entry,'enemy has no visible presentation slot')
        return enemySlot(count,slot,entry.actor)
    end
    local function dragPose(g)
        return g.x, g.y + (g.touchScreen and 270*g.sourceScale or 0)
    end
    local function inPlayArea(x,y)
        local area = D.playArea
        return math.abs(x-area[1]) <= area[3]/2 and math.abs(y-area[2]) <= area[4]/2
    end
    local function dragTarget(g)
        if not dependencies.dragReady(g) then return false end
        local battle = g.battle
        local ok, reason = Combat.canPlay(battle,g.uid,nil)
        if not ok and reason ~= "invalid_target" then return false end
        local hovered
        local rows = EnemyView.slots(battle)
        local count = #rows
        for i, entry in ipairs(rows) do
            local enemy = entry.actor
            local x, _, portrait, step = enemySlot(count,i,enemy)
            local reach = math.min(D.targetColumn,count > 1 and step or D.targetColumn)/2
            if math.abs(g.x-x) <= math.min(reach,portrait/2+D.reticlePad)
                and math.abs(g.y-EnemyView.rowY(count,i)) <= portrait/2+D.reticlePad
                and Actors.isActive(enemy) then
                hovered = entry.index; break
            end
        end
        CardInput.sample(g, g.x, g.y, hovered, not ok)
        if g.cancelled then return false, nil, g.aiming end
        if ok then return g.dropZone, nil end
        return g.aiming and hovered ~= nil and Combat.canPlay(battle,g.uid,hovered) or false, hovered, g.aiming
    end
    return {enemySlot=enemySlot, enemyPosition=enemyPosition, dragPose=dragPose, inPlayArea=inPlayArea, dragTarget=dragTarget}
end
return M
