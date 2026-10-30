-- Original world intent is one image, separate from tooltip effect rows.
local Theme=require('abyss_theme')
return function(box,face,label)
    if label then assert(face.label==label,'intent wording changed') end
    assert(not box:GetChild('intentLabel').visible,'obsolete face label must stay hidden')
    assert(not box:GetChild('intentBadge').visible and not box:GetChild('intentExtra').visible,
        'tooltip effect icons must not become extra world intent images')
    local visible=face.sourceEnum and face.worldVisible==true or not face.sourceEnum
    local icon=box:GetChild('intentIcon')
    assert(icon.visible==visible,'original world intent visibility changed')
    if visible then
        assert(icon.imageId==Theme.icon.intent[face.worldKind or face.kind],'original world intent image changed')
    end
    if face.sourceEnum and face.sourceEnum:sub(1,6)=='ATTACK' then
        assert(face.worldKind=='attack' and face.sourceTexture:match('^INTENT_ATK_[1-7]$'),
            'mixed attacks use the same source damage-tier world image as ATTACK')
    elseif face.sourceEnum=='UNKNOWN' or face.sourceEnum=='STUN' then
        assert(not icon.visible,'UNKNOWN/STUN use source VFX, not a base world image')
    end
end
