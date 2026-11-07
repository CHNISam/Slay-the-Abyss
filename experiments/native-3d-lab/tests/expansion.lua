package.path='build/lua/?.lua;src/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local view,stage=F.fixture()
local function node(name,kind,children)return {name=name,kind=kind or 'container',size={100,40},children=children or {}}end
local buttons={node('status','text')}
for _,name in ipairs({'shape','selector','assets'})do buttons[#buttons+1]=node(name,'container',{node('hit','cursorArea')})end
stage.children.expansionPanel=F.control(node('expansionPanel','container',buttons),stage)
local phase,cancels,toggles,handler,requests=0,0,{},nil,{}
local failSend=false
package.loaded.abyss_3d_expansion_config={shape={commandSignal='SHAPE3D_COMMAND',ackSignal='SHAPE3D_ACK',commands={'show','move','hide'}},selector={}}
package.loaded.abyss_3d_material_sample={toggle=function(_,on)toggles[#toggles+1]=on;return 'material'end,destroy=function()end}
package.loaded.abyss_3d_selector={attach=function()return {
 cancel=function()cancels=cancels+1 end,start=function()phase=phase+1;return true end,
 update=function()end,destroy=function()end,status=function()return 'selector'end}end}
Enum={CursorEventType={CursorClick='click'}}
local stops=0
local lab={stop=function(self)stops=stops+1;self.sceneOnlyEnabled=false end}
function lab:sceneOnly(on)self:stop();self.sceneOnlyEnabled=on end
local originalStop,originalScene,originalRefresh=lab.stop,lab.sceneOnly,view.refresh
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
E:destroy();assert(lab.stop==originalStop and lab.sceneOnly==originalScene and view.refresh==originalRefresh)
local count=#requests;click('shape');assert(#requests==count,'destroyed controller must reject old clicks')
print('expansion controller: busy/late ACK, stop, background refresh and teardown passed (mock new bridges)')
