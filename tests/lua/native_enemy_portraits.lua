local NativeActors=dofile('tests/lua/support/current_monster_controls.lua')
-- Source-level native UIImage SetImage coverage, not official-device evidence.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,Theme=H.F.Combat,H.F.Theme
local expected={
    looter=112030,
    guardian=112046,
    cultist=112022,
    jaw_worm=112038,
    red_louse=112013,
    green_louse=112014,
    acid_slime_s=112009,
    acid_slime_m=112009,
    acid_slime_l=112010,
    spike_slime_s=112007,
    spike_slime_m=112007,
    spike_slime_l=112008,
    blue_slaver=112031,
    red_slaver=112050,
    fungi_beast=112033,
    mad_gremlin=112022,
    sneaky_gremlin=112025,
    fat_gremlin=112023,
    wizard_gremlin=112024,
    shield_gremlin=112025,
    gremlin_nob=112037,
    lagavulin=112026,
    sentry=112027,
    hexaghost=112022,
    slime_boss=112004,
    spheric_guardian=112026,
    centurion=112017,
    mystic=112021,
    taskmaster=112031,
    book_of_stabbing=112024,
    snake_plant=112033,
    chosen=112025,
    shelled_parasite=112014,
    byrd=112065,
    snecko=112037,
    mugger=112030,
    gremlin_leader=112020,
    torch_head=112016,
    collector=112022,
    automaton=112027,
    bronze_orb=112026,
    champ=112018,
}
local host,ui,panel=H.setup({'defend'},{'cultist'})
local catalog=host.run.combat.catalog.enemies
local ids={}
for _,definition in ipairs(H.F.Data.enemies.enemies)do ids[#ids+1]=definition.id end
for _,module in ipairs({'abyss_act1_bosses','abyss_act2_enemies'})do
    for _,definition in ipairs(require(module).enemies)do ids[#ids+1]=definition.id end
end
assert(#ids==42,'all two-act definitions including bosses and summons')
local seen={}
for first=1,#ids,5 do
    local members={}
    for i=first,math.min(first+4,#ids)do
        local id=ids[i]
        assert(not seen[id] and expected[id] and catalog[id],id)
        seen[id]=true
        assert(type(Theme.icon.enemy[id])=='number' and Theme.icon.enemy[id]==expected[id],id..' exact native lookup')
        members[#members+1]=id
    end
    host.run.combat=C.new(H.F.Data,{deck={'defend'},enemies=members})
    host:refresh()
    for slot,id in ipairs(members)do
        local box=NativeActors.actor(panel,host.run.combat.enemies[slot])
        assert(box.visible and box:GetChild('portrait').imageId==expected[id],id..' real battle SetImage')
    end
end
local count=0;for id in pairs(expected)do assert(seen[id],id);count=count+1 end
assert(count==42)
-- Dynamic additions go through the production summon path, not just initial data.
for _,pair in ipairs({{'collector','torch_head'},{'automaton','bronze_orb'},{'gremlin_leader','wizard_gremlin'}})do
    local members=pair[1]=='gremlin_leader' and {'mad_gremlin','sneaky_gremlin',pair[1]} or {pair[1]}
    local battle=C.new(H.F.Data,{deck={'defend'},enemies=members})
    host.run.combat=battle
    assert(C.summonEnemies(battle,{{id=pair[2],x=200,y=0}}))
    host:refresh()
    for i,enemy in ipairs(battle.enemies)do
        assert(NativeActors.actor(panel,enemy):GetChild('portrait').imageId==expected[enemy.definitionId],pair[2]..' summoned SetImage')
    end
end
-- Missing portrait assets retain the tier fallback for a supported source actor.
-- Geometry and image lookup are separate contracts: unknown source definitions
-- are not assigned invented coordinates merely to exercise a missing image.
for _,tier in ipairs({'normal','elite','boss'})do
    local battle=C.new(H.F.Data,{deck={'defend'},enemies={'cultist'}})
    local saved=Theme.icon.enemy.cultist;Theme.icon.enemy.cultist=nil
    battle.enemies[1].tier=tier
    host.run.combat=battle;host:refresh()
    local shown=NativeActors.actor(panel,battle.enemies[1]):GetChild('portrait').imageId
    Theme.icon.enemy.cultist=saved
    assert(shown==Theme.icon.node[tier=='normal' and 'combat' or tier],tier..' fallback')
    assert(Theme.icon.enemy.cultist==expected.cultist,'restore source portrait lookup')
end
assert(require('abyss_monster_source_geometry').resolve({definitionId='future_unmapped_enemy'})==nil,'unknown source geometry must not receive invented coordinates')
assert(Theme.icon.enemy.verify==true,'device verification remains pending')
print('LUA_NATIVE_ENEMY_PORTRAITS_PASS 42 + summons + unknown fallbacks')
