-- Explicit offline native-engine boundary for real OnStart fixtures. Production
-- bindings stay fail-closed; only these test worlds register generated templates.
return function(engine)
    local F=dofile('tests/lua/support/game_ui_fixture.lua')
    local actor=F.monsterActors()
    local indices={templateIndex=actor.templateIndex,containerTemplateIndex=actor.containerTemplateIndex,powerTemplateIndex=actor.powerTemplateIndex}
    local templates={
        [indices.templateIndex]=assert(F.Templates.AbyssMonsterActor),
        [indices.containerTemplateIndex]=assert(F.Templates.AbyssReadyCardGroup),
        [indices.powerTemplateIndex]=assert(F.Templates.AbyssMonsterPower),
    }
    local priorCreate,priorDestroy=engine.InstantiateClientUIControl,engine.DestroyClientUIControl
    local priorBinding=package.loaded.abyss_monster_actor_binding
    local owned,serial=setmetatable({},{__mode='k'}),0
    local binding={enabled=true}
    for key,index in pairs(indices)do assert(index>0 and index%1==0);binding[key]=index end
    assert(indices.templateIndex~=indices.containerTemplateIndex and indices.templateIndex~=indices.powerTemplateIndex and indices.containerTemplateIndex~=indices.powerTemplateIndex)
    package.loaded.abyss_monster_actor_binding=binding
    engine.InstantiateClientUIControl=function(index,parent)
        local template=templates[index]
        if not template then return assert(priorCreate,'unregistered native template '..tostring(index))(index,parent)end
        assert(parent and parent.alive~=false,'invalid native parent')
        local box=F.control(template,parent)
        serial=serial+1;parent.children['nativeEntryActor'..serial]=box;owned[box]=true
        return box
    end
    engine.DestroyClientUIControl=function(box)
        if not owned[box]then return assert(priorDestroy,'destroying unowned native control')(box)end
        assert(box.alive~=false,'native control destroyed twice')
        owned[box]=nil
        return actor.destroy(box)
    end
    return function()
        engine.InstantiateClientUIControl,engine.DestroyClientUIControl=priorCreate,priorDestroy
        package.loaded.abyss_monster_actor_binding=priorBinding
    end
end
