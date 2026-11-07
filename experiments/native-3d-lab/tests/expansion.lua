package.path='build/lua/?.lua;src/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local view,stage=F.fixture()
local function node(name,kind,children)return {name=name,kind=kind or 'container',size={100,40},children=children or {}}end
local buttons={node('status','text')}
for _,name in ipairs({'shape','selector','assets'})do buttons[#buttons+1]=node(name,'container',{node('hit','cursorArea')})end
stage.children.expansionPanel=F.control(node('expansionPanel','container',buttons),stage)
local phase,cancels,toggles,handler,requests=0,0,{},nil,{}
local selector={}
local failSend=false
package.loaded.abyss_3d_expansion_config={shape={commandSignal='SHAPE3D_COMMAND',ackSignal='SHAPE3D_ACK',commands={'show','move','hide'}},selector={}}
package.loaded.abyss_3d_material_sample={toggle=function(_,on)toggles[#toggles+1]=on;return 'material'end,destroy=function()end}
package.loaded.abyss_3d_selector={attach=function()selector={
 cancel=function(self)cancels=cancels+1;self.pending=nil end,start=function(self,mode)phase=phase+1;self.pending=mode=='native'and{}or nil;return true end,
 update=function()end,destroy=function()end,status=function()return 'selector'end};return selector end}
Enum={CursorEventType={CursorClick='click'}}
local stops=0
local lab={stop=function(self)stops=stops+1;self.job=nil;self:setMode('2D')end}
function lab:setMode(mode)self.mode=mode;self.sceneOnlyEnabled=false end
function lab:all()self.job={stages={{}},index=0}end
function lab:cards()self.manualCards=true end
function lab:sceneOnly(on)self:stop();self.sceneOnlyEnabled=on end
local originalStop,originalScene,originalRefresh,originalAll,originalCards=lab.stop,lab.sceneOnly,view.refresh,lab.all,lab.cards
local E=dofile('experiments/native-3d-lab/expansion-runtime.lua').attach(view,stage.parent,{
 lab=lab,log=function()end,send=function(name,params)if failSend then error('injected send failure')end;requests[#requests+1]={name=name,params=params}end,
 register=function(_,callback)handler=callback;return function()handler=nil end end})
local panel=stage.children.expansionPanel
local function click(name)panel:GetChild(name):GetChild('hit').click()end
click('shape');assert(lab.sceneOnlyEnabled and #requests==1)
click('shape');assert(#requests==1,'busy shape must not enqueue another command')
handler({'requested:whole_object_motion',1});click('shape');assert(#requests==1)
handler({'ready:whole_object_not_rigged',1});click('shape');assert(#requests==2)
handler({'completed:move',1});assert(E.pending.seq==2,'late previous reply must not consume current request')
lab:stop();assert(not lab.sceneOnlyEnabled and requests[#requests].params[1].value=='hide')
local stopped=stops
handler({'hidden',3});assert(stops==stopped,'late shape hide must not stop the next original experiment')
failSend=true;click('shape');assert(not E.pending and not E.shapeOn and not lab.sceneOnlyEnabled,'send error must immediately release scene ownership')
failSend=false;click('shape');E:update(11);assert(not E.pending and not E.shapeOn and not lab.sceneOnlyEnabled,'timeout must release scene ownership')
-- Failure after successful display must retain a server-side cleanup obligation.
E.pending=nil;click('shape');handler({'ready:whole_object_not_rigged',E.seq})
failSend=true;click('shape');assert(not E.shapeOn and E.needsShapeCleanup)
failSend=false;local prior=#requests;lab:stop()
assert(#requests==prior+1 and requests[#requests].params[1].value=='hide','shown model must be cleaned after a later send error')
handler({'hidden',E.seq});assert(not E.needsShapeCleanup)
click('shape');handler({'ready:whole_object_not_rigged',E.seq});click('shape');E:update(11)
prior=#requests;lab:stop();assert(#requests==prior+1 and requests[#requests].params[1].value=='hide','shown model must be cleaned after a later timeout')
handler({'hidden',E.seq})
click('assets');assert(toggles[#toggles]==true)
view:refresh();assert(toggles[#toggles]==true,'material must survive formal refresh')
lab:stop();assert(toggles[#toggles]==false,'stop must restore material')
click('selector');assert(phase==1 and cancels>0)
-- Only normal completion appends the new specimens; replacing/stopping the old job must not.
lab:all();lab.job=nil;E:update(.1);assert(not E.auto and not E.awaitOld)
lab:all();lab:stop();E:update(.1);assert(not E.auto and not E.awaitOld)
lab:all();lab.job.index=2;lab.job=nil;E:update(.1)
assert(E.auto and E.pending.command=='show','old all normal completion must start expanded samples')
handler({'ready:whole_object_not_rigged',E.seq});E:update(2)
assert(E.pending.command=='move','shape stages must advance on matching ACK')
E:update(2);assert(E.pending.command=='move','a new stage must wait for its ACK')
handler({'completed:timed_whole_motion_requires_visual_check',E.seq});E:update(.1)
assert(E.pending.command=='hide');handler({'hidden',E.seq});E:update(2);E:update(2);E:update(3);E:update(3)
assert(selector.pending and E.auto,'native selector must wait for a real result')
E:update(2);assert(E.auto,'elapsed time must not invent a selection')
selector.pending=nil;E:update(.1);assert(not E.auto,'native result/timeout ends the added sequence')
lab:all();lab.job.index=2;lab.job=nil;E:update(.1);lab:cards()
assert(not E.auto and lab.manualCards,'original manual action must take ownership before it runs')
lab:all();lab.job.index=2;lab.job=nil;E:update(.1);lab:stop();assert(not E.auto and not E.awaitOld)
E:destroy();assert(lab.stop==originalStop and lab.sceneOnly==originalScene and view.refresh==originalRefresh)
assert(lab.all==originalAll and lab.cards==originalCards,'destroy must restore all wrapped public methods')
local count=#requests;click('shape');assert(#requests==count,'destroyed controller must reject old clicks')
print('expansion controller: busy/late ACK, faults, auto append/wait/interrupt, stop, restore and teardown passed (mock new bridges)')
