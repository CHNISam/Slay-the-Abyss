-- A deterministic write recorder for the existing native-control fixture.
-- Each scenario still owns its complete, independent control tree.
local M={}
function M.serialize(value,seen)
    local kind=type(value)
    if kind=='number' then return string.format('%.17g',value) end
    if kind~='table' then return kind..':'..tostring(value) end
    seen=seen or {};assert(not seen[value],'cyclic trace value');seen[value]=true
    local keys={};for key in pairs(value)do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={}
    for _,key in ipairs(keys)do out[#out+1]=tostring(key)..'='..M.serialize(value[key],seen)end
    seen[value]=nil;return '{'..table.concat(out,',')..'}'
end
function M.new()
    local recorder={hash=0.0,count=0}
    function recorder:add(value)
        local text=M.serialize(value)..'\n'
        for i=1,#text do self.hash=(self.hash*131+text:byte(i))%2147483647 end
        self.count=self.count+1
    end
    function recorder:attach(control,path)
        path=path or 'root'
        local fields={}
        for key,value in pairs(control)do
            if type(value)~='function' and key~='children' and key~='parent' and key~='ui' then
                fields[key]=value;control[key]=nil
            end
        end
        local original=getmetatable(control)
        setmetatable(control,{__index=function(_,key)
            if fields[key]~=nil then return fields[key]end
            return original and original.__index and original.__index[key]
        end,__newindex=function(_,key,value)
            fields[key]=value
            if type(value)~='function' and key~='listeners' and key~='refreshCallback' then
                recorder:add({path,key,value})
            end
        end})
        for _,name in ipairs({'SetVisible','SetImage','SetSizeDelta','SetLocalScale','SetAnchoredPosition','SetAsLastSibling'})do
            local method=control[name]
            if method then rawset(control,name,function(owner,...)
                recorder:add({path,name,{...}})
                return method(owner,...)
            end)end
        end
        local keys={};for key in pairs(control.children or {})do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys)do self:attach(control.children[key],path..'/'..key)end
    end
    return recorder
end
return M
