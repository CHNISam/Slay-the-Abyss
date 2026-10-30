-- Isolated Feedback adapter tests exercise its explicit five-slot raw fallback.
-- Host/gesture suites bind the real native monster manager instead.
return function(stage,control)
    local template=assert(require('abyss_ui_templates').AbyssMonsterActor)
    for index=1,5 do
        local definition={}
        for key,value in pairs(template)do definition[key]=value end
        definition.name='enemy'..index
        definition.children={}
        for _,child in ipairs(template.children or {})do
            if child.name~='monsterArt' then definition.children[#definition.children+1]=child end
        end
        stage.children[definition.name]=control(definition)
    end
    return stage
end
