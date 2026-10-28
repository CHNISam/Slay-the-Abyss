-- The approved native face uses up to three ordered icons. Wording remains
-- available in the shared read-only projection and the real tooltip fixtures.
local View,Theme=require('abyss_battle_intent_view'),require('abyss_theme')
return function(box,face,label)
    if label then assert(face.label==label,'intent wording changed') end
    assert(not box:GetChild('intentLabel').visible,'obsolete face label must stay hidden')
    local kinds=View.icons(face)
    for i,name in ipairs({'intentIcon','intentBadge','intentExtra'})do
        local image=box:GetChild(name)
        assert(image.visible==(kinds[i]~=nil),'intent icon visibility changed')
        if kinds[i] then assert(image.imageId==Theme.icon.intent[kinds[i]],'intent icon changed') end
    end
end
