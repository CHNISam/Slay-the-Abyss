local Select=require('abyss_character_select')
local Data,Presentation=require('abyss_data'),require('abyss_presentation')
local state=Select.new(Data,Presentation,'competition-candidate')
assert(state:select('traveler') and state.info.id=='ironclad')
local old=state.info
for _,id in ipairs({'silent','defect','watcher'})do
    assert(not state:selectElement(id) and state.info==old)
end
for _,id in ipairs({'hutao','arlecchino','furina','raiden','unknown'})do
    assert(not state:select(id) and state.info==old)
end
assert(state:selectElement('ironclad') and state.info.id=='ironclad')
assert(Select.allowed('competition-candidate','ironclad'))
assert(not Select.allowed('competition-candidate','defect'))
assert(not Select.allowed('wrong-profile','ironclad'))
assert(not pcall(Select.new,Data,Presentation,'wrong-profile'))
local production=Select.new(Data,Presentation,'production')
assert(production:select('traveler') and production.info.id=='ironclad')
assert(not production:select('raiden') and production.notice==nil)
local alpha=Select.new(Data,Presentation,'alpha')
assert(alpha:select('traveler') and not alpha:select('raiden') and not alpha:selectElement('defect'))
local development=Select.new(Data,Presentation,'dev')
for _,id in ipairs(Select.characters)do assert(development:select(id))end
assert(development:select('traveler'))
for _,id in ipairs(Select.elements)do assert(development:selectElement(id))end

local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function host(profile)
    local canvas=F.control({children=F.Layout})
    local root=F.Viewport.apply(canvas,1280,720)
    local ui=F.GameUI.new(root,Data,Presentation,'click',{seed='1',characterProfile=profile,
        campaign=true,campaignProfile='competition-two-act',imageSource='static',color=function()return {}end})
    assert(ui:start())
    return ui,root:GetChild('characterPanel')
end
local candidate,panel=host('competition-candidate')
for i=1,4 do assert(not panel:GetChild('character'..i).visible)end
assert(panel:GetChild('traveler').visible)
assert(candidate:selectCharacter('traveler'))
for i=2,4 do assert(not panel:GetChild('elements'):GetChild('element'..i).visible)end
assert(not candidate:selectCharacter('furina'))
assert(not candidate:selectElement('silent'))
candidate.characterSelection.info={id='hutao'}
assert(not candidate:confirmCharacter() and not candidate.run and candidate.seed=='1')
assert(candidate:selectCharacter('traveler') and candidate:confirmCharacter())
assert(not candidate.run.characterProfile and not candidate.run.data.originalV4Role)
local closed,closedPanel=host('production')
assert(not closed:selectCharacter('raiden') and not closed:confirmCharacter() and not closed.run)
assert(not closedPanel:GetChild('hint').text:find('待验收',1,true))
assert(closed:selectCharacter('traveler') and closed:confirmCharacter() and closed.run)

-- Execute the actual entry; only GameUI is replaced to inspect the native mode
-- contract. No GUI, desktop input or platform-ready claim is involved.
local function native(testValue,throwing,workKey)
    local seen,updates
    local original=package.loaded.abyss_game_ui
    local narrative=package.loaded.abyss_narrative
    package.loaded.abyss_narrative={build=workKey and {workKey=workKey} or nil}
    package.loaded.abyss_game_ui={new=function(_,_,_,_,platform)
        seen=platform.characterProfile
        return {resize=function()end,update=function()end}
    end}
    package.loaded.abyss_viewport={apply=function()return {}end}
    script={object={},GetParam=function()return false end,EnableUpdate=function(_,v)updates=v end}
    Enum={CursorEventType={CursorClick='click'},ImageSource={StaticReference='static'}}
    game={GetUICanvasSize=function()return 1280,720 end,
        IsTestPlay=function()if throwing then error('unavailable')end return testValue end}
    Color={}
    dofile('src/lua/abyss_ui.lua');OnStart()
    package.loaded.abyss_game_ui=original
    package.loaded.abyss_narrative=narrative
    assert(updates==true)
    return seen
end
assert(native(true)=='competition-candidate')
assert(native(false)=='production')
assert(native(nil)=='production')
assert(native(true,true)=='production')
assert(native(false,false,'alpha-test')=='competition-candidate')
assert(native(nil,false,'alpha-test')=='competition-candidate')
assert(native(false,false,'competition')=='production')
assert(native(false,false,'unknown')=='production')
assert(native(false,false,'Alpha-test')=='production')
assert(native(true,false,'competition')=='competition-candidate')
print('COMPETITION_CHARACTER_ADMISSION_PASS 5')
