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
    local recorder={hash=0.0,count=0,nativeButtons={}}
    local transforms={}
    function recorder:add(value)
        local text=M.serialize(value)..'\n'
        local transform=transforms[text]
        if not transform then
            local factor,offset=1.0,0.0
            for i=1,#text do
                factor=(factor*131)%2147483647
                offset=(offset*131+text:byte(i))%2147483647
            end
            transform={factor,(factor*65536)%2147483647,offset};transforms[text]=transform
        end
        -- Two 16-bit limbs keep every product/sum below 2^49, preserving the
        -- original byte-loop hash exactly in Lua doubles while reusing rows.
        self.hash=((self.hash%65536)*transform[1]+math.floor(self.hash/65536)*transform[2]+transform[3])%2147483647
        self.count=self.count+1
    end
    function recorder:assertNativeInteraction()
        for _,button in ipairs(self.nativeButtons)do
            assert(button.control.interactable==button.control.raycastTarget,
                'native button gates diverged: '..button.path)
        end
    end
    function recorder:attach(control,path)
        path=path or 'root'
        local kind=control.kind
        if kind=='presetButton'then self.nativeButtons[#self.nativeButtons+1]={control=control,path=path}end
        local pile=kind=='cursorArea' and (path=='root/battlePanel/drawIcon/hit'
            or path=='root/battlePanel/discardIcon/hit' or path=='root/battlePanel/exhaustIcon/hit')
        local fields={}
        for key,value in pairs(control)do
            if type(value)~='function' and key~='children' and key~='parent' and key~='ui' and key~='kind' then
                fields[key]=value;control[key]=nil
            end
        end
        local original=getmetatable(control)
        setmetatable(control,{__index=function(_,key)
            if fields[key]~=nil then return fields[key]end
            local index=original and original.__index
            if type(index)=='function'then return index(control,key)end
            return index and index[key]
        end,__newindex=function(_,key,value)
            -- Delegate validation to the real fixture. Keep its type field raw,
            -- but remove newly materialized fields so later writes are traced.
            if original and original.__newindex then
                original.__newindex(control,key,value)
                if key~='kind'then rawset(control,key,nil)end
            end
            fields[key]=value
            if type(value)~='function' and key~='listeners' and key~='refreshCallback' then
                -- Exact inverse of the approved P0 API correction: presets now
                -- mirror interactable into raycastTarget; three pile CursorAreas
                -- use the supported raycastTarget in place of the old bad field.
                -- The real control is never given an interactable alias.
                if key=='raycastTarget' and kind=='presetButton'then return end
                recorder:add({path,pile and key=='raycastTarget' and 'interactable' or key,value})
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
