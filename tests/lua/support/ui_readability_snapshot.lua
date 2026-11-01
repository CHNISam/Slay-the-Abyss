-- Join the generated import specification with the real controller's rendered
-- controls. The existing fixture deliberately does not copy initial geometry;
-- use the import geometry only when the controller has not overridden it.
local M = {}
local function quote(value)
    return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
        :gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end
local function encode(value)
    if type(value) == 'string' then return quote(value) end
    if type(value) ~= 'table' then return tostring(value) end
    local result = {}
    if #value > 0 then
        for _,item in ipairs(value) do result[#result+1] = encode(item) end
        return '[' .. table.concat(result, ',') .. ']'
    end
    for key,item in pairs(value) do result[#result+1] = quote(key) .. ':' .. encode(item) end
    return '{' .. table.concat(result, ',') .. '}'
end
function M.capture(name, root, layout, metadata)
    local stage
    for _,spec in ipairs(layout) do if spec.name == 'stage' then stage = spec end end
    assert(stage, 'generated viewport stage missing')
    local rows = {}
    local function walk(spec, box, path, parentX, parentY, parentSX, parentSY, shown)
        assert(box, 'rendered control missing: ' .. path)
        local position, scale = spec.position or {0,0}, box.scale or spec.scale or {1,1}
        local x = parentX + (box.x or position[1]) * parentSX
        local y = parentY + (box.y or position[2]) * parentSY
        local sx,sy = parentSX * scale[1],parentSY * scale[2]
        local visible = shown and box.visible ~= false
        local size = {box.sizeDeltaX or (spec.size or {0,0})[1], box.sizeDeltaY or (spec.size or {0,0})[2]}
        local tracked = path:match('^/battlePanel/[^/]+$')
        if spec.kind == 'text' and visible or tracked then
            rows[#rows+1] = {path=path,kind=spec.kind,visible=visible,text=spec.text and box.text or '',
                rect={x,y,size[1]*sx,size[2]*sy},size=size,scale={sx,sy},
                font=spec.text and (box.fontSize or spec.text.fontSize) or 0,
                minimum=spec.text and spec.text.minFontSize or 0}
        end
        -- Native preset buttons select a state internally; the test fixture
        -- retains all four branches. Compare the actual normal/disabled state,
        -- never four superimposed copies of a single button caption.
        local state = spec.kind=='presetButton' and box.interactable == false and 'disabled' or 'normal'
        for _,child in ipairs(spec.children or {}) do
            local selected = spec.kind ~= 'presetButton' or not spec.states or child.name == state
            walk(child, box:GetChild(child.name), path .. '/' .. child.name, x,y,sx,sy,visible and selected)
        end
    end
    walk(stage,root,'',0,0,1,1,true)
    print('UI_READABILITY\t' .. name .. '\t' .. encode({nodes=rows,meta=metadata or {}}))
end
return M
