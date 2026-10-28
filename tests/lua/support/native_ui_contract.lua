-- Parameter shapes: docs/art/CARD_TEXT_HEIGHT_COMPAT.md (official API 658-666)
-- and docs/design/CARD_DRAG_PLATFORM.md (cursor-area callback API 823-827).
-- Keep event enums opaque. Listener ownership/duplicates and control capabilities
-- belong to each scenario; this module owns no controls, listeners or scene state.
local M = {}
-- Cursor areas receive pointer events but do not expose the preset-button
-- interactable property. Keep this absent so __newindex sees every attempt.
function M.control(box,spec)
    if spec.kind~='cursorArea' then return box end
    rawset(box,'interactable',nil)
    local previous=getmetatable(box) or {}
    local guarded={}
    for key,value in pairs(previous)do guarded[key]=value end
    guarded.__newindex=function(self,key,value)
        assert(key~='interactable','cursorArea cannot set interactable, no such native field')
        if previous.__newindex then return previous.__newindex(self,key,value) end
        rawset(self,key,value)
    end
    return setmetatable(box,guarded)
end
function M.sizeDelta(width,height)
    -- Finite values keep offline geometry assertions usable. This is a fixture
    -- guard, not a claim about native numeric limits; signed deltas are allowed.
    assert(type(width)=='number' and type(height)=='number'
        and width==width and height==height
        and math.abs(width)<math.huge and math.abs(height)<math.huge,
        'SetSizeDelta requires finite numeric width and height in this fixture')
end
function M.listener(event,callback)
    assert(event~=nil,'listener event is required')
    assert(type(callback)=='function','listener callback must be a function')
end
return M
