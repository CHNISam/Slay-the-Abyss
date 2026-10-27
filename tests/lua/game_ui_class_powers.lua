local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 5
local sliceRegistered=0
package.path="src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;"..package.path
local F=require("support.game_ui_fixture")
local X=require("support.experimental_ui_fixture")
local Run=require("abyss_run")
local Combat=require("abyss_combat")
local cases={
    {'ironclad','rupture','rupture',1},{'ironclad','combust','combust',5},
    {'ironclad','brutality','brutality',1},{'ironclad','berserk','berserk',1},
    {'ironclad','rage','rage',3},{'silent','after_image','after_image',1},
    {'silent','thousand_cuts','thousand_cuts',1},{'silent','envenom','envenom',1},
    {'silent','outmaneuver','energized',2},{'silent','dodge_and_roll','next_turn_block',4},
    {'defect','charge_battery','energized_blue',1},{'defect','heat_sinks','heat_sinks',1},
    {'defect','storm','storm',1},
    {"silent","accuracy","accuracy",4}, {"silent","noxious_fumes","noxious_fumes",2},
    {"defect","defragment","focus",1},{"defect","biased_cognition","bias",1},
    {"watcher","rushdown","rushdown",2},{"watcher","mental_fortress","mental_fortress",4},
    {"watcher","nirvana","nirvana",3},{"watcher","prostrate","mantra",2},
    {"watcher","devotion","devotion",2},{"ironclad","metallicize","metallicize",3},
    {"ironclad","demon_form","demon_form",2},
    {"ironclad","corruption","corruption",1},{"ironclad","feel_no_pain","feel_no_pain",3},
    {"ironclad","dark_embrace","dark_embrace",1},{"defect","loop","loop",1},
    {"defect","electrodynamics","electrodynamics",1},{"silent","infinite_blades","infinite_blades",1},
}
local count=0
for _,case in ipairs(cases) do
    sliceRegistered=sliceRegistered+1
    if sliceRegistered>=sliceFirst and sliceRegistered<=sliceLast then
    local id,cardId,status,value=table.unpack(case)
    local ui,root=X.new();assert(ui:start(id))
    -- A deterministic branch fixture, not a natural-acquisition assertion.
    ui.run.deck={}
    for i=1,12 do ui.run.deck[i]={uid=i,cardId=cardId,upgraded=false} end
    ui.run.nextDeckUid=13
    assert(Run.startCombat(ui.run,"cultist_solo"));ui:refresh()
    local slot
    for i,instance in ipairs(ui.run.combat.hand) do if instance.cardId==cardId then slot=i;break end end
    assert(slot,"source card not in initial hand")
    F.click(root,"battlePanel","card"..slot);F.click(root,"battlePanel","playArea")
    assert(ui.run.combat.player.statuses[status]==value,cardId.." did not apply")
    assert(not ui.battleUI.busy);ui:refresh()
    local found=false
    for _,entry in ipairs(Combat.statusView(ui.run.combat.player)) do
        if entry.id==status then
            assert(entry.name:find("[\128-\255]"),"missing Chinese status name "..status)
            assert(entry.description:find("[\128-\255]"),"missing Chinese status description "..status)
            found=true
        end
    end
    assert(found,status)
    count=count+1;print("ok class power "..count.." - actual "..cardId.." feedback and status render")
    print("GAME_UI_CLASS_POWERS_CASE "..sliceRegistered)
    end
end
print("GAME_UI_CLASS_POWERS_PASS "..count)

assert(sliceRegistered==30,"all thirty original class power cases must register")
assert(count==sliceLast-sliceFirst+1,"every selected original class power case must execute")
print("GAME_UI_CLASS_POWERS_SLICE "..sliceFirst.." "..sliceLast.." "..count)
