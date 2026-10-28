-- The existing campaign profile owns the competition roster, not content pools.
local M={}
local competition={ironclad='ironclad',raiden='raiden',RD='raiden'}
function M.allows(profile,id)
    return profile~='competition-two-act' or id==nil or competition[id]~=nil
end
function M.accepts(data,options)
    if not options or options.campaignProfile~='competition-two-act' then return true end
    local identity
    -- runCardCharacter describes the assembled source catalogue, not an active
    -- prepared role. A raw shared catalogue remains a legal Raiden input.
    for _,field in ipairs({{options,'character'},{data,'experimentalCharacter'},{data,'characterId'},
        {data,'originalV4Role'}})do
        local id=field[1][field[2]]
        if id~=nil then
            local canonical=competition[id]
            if not canonical or identity and identity~=canonical then return false end
            identity=canonical
        end
    end
    return true -- no identity markers means the unchanged production Geo loadout
end
return M
