-- Test fixtures choose real connected paths; no room, edge or rule mutations.
local Map=require('abyss_map')
local M={}
function M.at(map,id)
    for _,node in ipairs(Map.available(map))do if node.id==id then return node end end
    error('route node is not available: '..tostring(id))
end
function M.to(map,predicate)
    local index={};for _,node in ipairs(map.nodes)do index[node.id]=node end
    local pending,seen={},{};for _,node in ipairs(Map.available(map))do pending[#pending+1]={node.id};seen[node.id]=true end
    local at=1
    while pending[at]do
        local path=pending[at];at=at+1;local node=index[path[#path]]
        if predicate(node)then return path end
        for _,id in ipairs(node.nextIds)do
            if not seen[id]then
                local nextPath={};for i,value in ipairs(path)do nextPath[i]=value end
                nextPath[#nextPath+1]=id;pending[#pending+1]=nextPath;seen[id]=true
            end
        end
    end
    error('no matching room on the actual reachable map')
end
function M.best(map,score)
    local index,memo={},{};for _,node in ipairs(map.nodes)do index[node.id]=node end
    local function visit(id)
        if memo[id]then return memo[id][1],memo[id][2]end
        local node=index[id];local bestValue,bestPath=0,{}
        for _,nextId in ipairs(node.nextIds)do
            local value,path=visit(nextId)
            if #bestPath==0 or value>bestValue then bestValue,bestPath=value,path end
        end
        local path={id};for _,value in ipairs(bestPath)do path[#path+1]=value end
        local value=bestValue+score(node);memo[id]={value,path};return value,path
    end
    local bestValue,bestPath
    for _,node in ipairs(Map.available(map))do
        local value,path=visit(node.id)
        if not bestValue or value>bestValue then bestValue,bestPath=value,path end
    end
    return assert(bestPath)
end
return M
