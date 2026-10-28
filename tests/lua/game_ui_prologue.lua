-- Retirement regressions: the historical module is no longer a launch dependency.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local n=0
local function test(name,fn)fn();n=n+1;print('ok prologue retirement '..n..' - '..name)end
local function open(flag,sound)
 local ui,root=F.fixture(nil,nil,nil,nil,flag,sound)
 assert(ui:start());assert(ui.characterOpen and not ui.run)
 assert(ui:selectCharacter('traveler'));assert(ui:selectElement('ironclad'))
 assert(ui:confirmCharacter());return ui,root
end
test('historical copy remains intact as dormant source material',function()
 local Prologue=require('abyss_prologue');local Narrative=require('abyss_narrative')
 local beats=Prologue.beats(Narrative.flow.intro.full)
 assert(#beats==3 and table.concat(beats)==Narrative.flow.intro.full)
 assert(beats[1]=='岩层深处传来了异常的共鸣。' and beats[2]=='古老的封印正在崩解……' and beats[3]=='旅行者，深入遗迹，阻止深渊的侵蚀。')
 for i,beat in ipairs(beats)do F.preview('intro'..i,beat)end
end)
test('generated formal tree contains no prologue panel',function()
 local ui,root=F.fixture();assert(root:GetChild('prologuePanel')==nil and ui.prologue==nil)
 assert(root:GetChild('menuPanel'):GetChild('title').text=='杀戮原塔2')
end)
test('default entry opens selection and has no Run or map',function()
 local ui,root=F.fixture();assert(ui:start());assert(ui.characterOpen and not ui.run and not ui.map)
 assert(root:GetChild('characterPanel').visible and not root:GetChild('mapPanel').visible)
end)
test('legacy prologue true flag cannot restore playback',function()
 local ui,root=open(true);assert(ui.mode=='map' and ui.prologue==nil)
 assert(root:GetChild('mapPanel').visible and ui.mapUI.navigationEnabled)
end)
test('legacy prologue false flag uses the same formal entry',function()
 local ui=open(false);assert(ui.mode=='map' and ui.prologue==nil)
end)
test('opening emits none of the three retired sound cues',function()
 local cues={};open(true,function(cue)cues[#cues+1]=cue end)
 for _,cue in ipairs(cues)do assert(not cue:match('^prologue_'))end
end)
test('runtime never loads the historical prologue dependency',function()
 local saved=package.loaded.abyss_prologue;package.loaded.abyss_prologue=nil
 local old=package.preload.abyss_prologue
 package.preload.abyss_prologue=function()error('retired launch dependency')end
 local ok,why=pcall(function()local ui=open(true);assert(ui.mode=='map')end)
 package.loaded.abyss_prologue=saved;package.preload.abyss_prologue=old;assert(ok,why)
end)
test('map and run clock are available immediately after confirmation',function()
 local ui,root=open(true);ui:update(1);assert(ui.run.elapsedSeconds>0)
 local first=F.Nodes.available(ui.run,ui.map)[1];assert(ui.mapUI:choose(first.id));assert(ui.mode=='battle')
 assert(root:GetChild('battlePanel').visible)
end)
test('restart returns through selection and existing Neow without an animation',function()
 local ui,root=open(true);local previous=ui.run
 ui.run.phase='defeat';ui:refresh();assert(ui:start())
 assert(ui.characterOpen and ui.run==previous and ui.prologue==nil)
 assert(F.confirmStart(ui));assert(ui.run~=previous and ui.mode=='node')
 assert(ui.run.nodeFlow.event.id=='neow' and root:GetChild('nodePanel').visible)
end)
test('old imported prologue controls remain hidden and unbound',function()
 local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720)
 local legacy=F.control({name='prologuePanel',kind='container',visible=true,children={{name='advance',kind='cursorArea'}}},root)
 root.children.prologuePanel=legacy
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,prologue=true,imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
 assert(not legacy.visible and not legacy:GetChild('advance').click and ui.prologue==nil)
 assert(F.start(ui));assert(ui.mode=='map' and not legacy.visible)
end)
print('LUA_GAME_UI_PROLOGUE_PASS '..n)
