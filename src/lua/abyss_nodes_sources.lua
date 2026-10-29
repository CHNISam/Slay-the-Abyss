-- Provenance checks for room-owned rewards and the camp Recall token.
local Common=require('abyss_nodes_common')

local matchingMap=Common.matchingMap
local pending=Common.pending

local M={}
-- Preserve validation order: map shape precedes path indexing and room identity.
function M.invalidMapOwner(run,map,flow)
    return type(map)~='table' or type(map.nodes)~='table' or type(map.path)~='table'
        or type(run.runSeed)~='string' or type(flow.mapSeed)~='string' or flow.mapSeed~=run.runSeed
end

function M.invalidRoomOwner(run,flow)
    return type(flow.floor)~='number' or flow.floor%1~=0 or flow.floor<1 or flow.floor>55
        or type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
        or run.roomGeneration<1 or run.roomGeneration>2147483647
        or type(flow.id)~='string' or type(flow.mapSignature)~='string' or flow.mapSignature==''
end

function M.roomMapMismatch(run,map,flow)
    return run.floor~=flow.floor or run.runSeed~=map.runSeed
        or (run.act or 1)~=(map.act or 1) or map.path[#map.path]~=flow.id or not matchingMap(flow,map)
end

-- Recall uses the existing campaign/history gate. The camp UI consumes
-- this source token through its existing last-action footer.
local function campSource(run,map)
    local flow,reason=pending(run,'camp');if not flow then return nil,reason end
    if flow.campChoice~=nil or flow.restReward~=nil then return nil,'camp_choice_made' end
    if M.invalidMapOwner(run,map,flow) or M.invalidRoomOwner(run,flow)
        or flow.complete~=false or M.roomMapMismatch(run,map,flow) then
        return nil,'camp_source_mismatch'
    end
    local node
    for _,entry in ipairs(map.nodes)do
        if type(entry)~='table' then return nil,'camp_source_mismatch' end
        if entry.id==flow.id then node=entry end
    end
    if not node or node.type~='camp' or node.floor~=flow.floor then return nil,'camp_source_mismatch' end
    return {id=flow.id,floor=flow.floor,act=run.act or 1,runSeed=run.runSeed,
        mapSeed=flow.mapSeed,mapSignature=flow.mapSignature,roomGeneration=run.roomGeneration}
end

M.campSource=campSource
return M
