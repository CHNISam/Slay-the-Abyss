package.path='build/lua/?.lua;src/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Lab=dofile('experiments/native-3d-lab/runtime.lua')
local view,stage=F.fixture()
local function node(name,children)return {name=name,kind=name=='hit' and 'cursorArea' or 'container',size={1280,720},children=children or {}}end
local menu={node('mode'),node('hint')}
for _,name in ipairs({'compare','model','animations','combat','cards','performance','idle','attack','hit','death','all','stop','reset','logs','tween'})do
    menu[#menu+1]=node(name,{node('hit'),node('label')})
end
local samples={node('sampleTitle')}
for i=1,3 do samples[#samples+1]=node('sample'..i,{node('name'),node('cost'),node('type'),node('label'),node('note'),node('hit')})end
stage.children.labPanel=F.control(node('labPanel',{
    node('fold',{node('hit'),node('label')}),node('menu',menu),
    node('diagnostics',{node('title'),node('status'),node('metrics'),node('log')}),node('cardSamples',samples),
}),stage)
local callback,requests,errors=nil,{},{}
local lab=Lab.attach(view,stage.parent,{
    config={buildId='production-rules-offline-test',nativeAvailable=true,maxActors=3,
        models={{name='守卫',hit=true},{name='史莱姆',hit=false},{name='丘丘人',hit=false}}},
    clickEvent='click',send=function(command,model,actor,seq)requests[#requests+1]={command=command,seq=seq,actor=actor}end,
    register=function(fn)callback=fn end,
    log=function(line)if line:find('ERROR',1,true)then errors[#errors+1]=line end end,
})
assert(view.run and view.run.phase=='combat','actual GameUI must show a playable initial battle')
local first=Lab.trace(view.run)
lab:startBattle();assert(Lab.trace(view.run)==first,'restarting uses the same real shuffle and encounter')
lab:performance()
for _=1,1000 do
    if lab.pending then
        local command,seq=lab.pending.command,lab.pending.seq
        callback(command=='show' and 'ready' or command=='hide' and 'hidden' or 'completed:'..command,seq)
    end
    view:update(.1);lab:update(.1)
    if not lab.job then break end
end
assert(#errors==0,table.concat(errors,'\n'))
assert(not lab.job,'real rules paired run must terminate')
local a,b=lab.results['2D'],lab.results['3D']
assert(a and b and a.metrics and b.metrics,'both branches need real GameUI/Run samples')
assert(a.actions==8 and b.actions==8,'each branch executes the same eight real commands')
assert(a.trace==b.trace,'real production Lua rules must be identical under both presentation modes')
assert(a.valid and b.valid and lab.pairValid,'only complete initialized samples may form a fair pair')
local battlePanel=stage:GetChild('battlePanel')
local information={}
for _,box in ipairs({battlePanel:GetChild('hero'),(F.actorControl(battlePanel,'enemy1'))})do
    for _,name in ipairs({'portrait','border','plate'})do assert(box:GetChild(name).visible==false,'2D portrait artwork must be hidden')end
    for _,name in ipairs({'hp','name','hit'})do
        information[#information+1]={control=box:GetChild(name),visible=box:GetChild(name).visible}
    end
end
local enemy=F.actorControl(battlePanel,'enemy1')
for _,name in ipairs({'intent','intentHit'})do information[#information+1]={control=enemy:GetChild(name),visible=enemy:GetChild(name).visible}end
local hasHit=false
for _,r in ipairs(requests)do if r.command=='hit' and r.actor==1 then hasHit=true end end
assert(hasHit,'real card damage events must request a native hit animation')
lab:setMode('2D')
for _,record in ipairs(information)do assert(record.control.visible==record.visible,'3D artwork masking must not change HP/name/intent/target visibility from the same 2D state')end
lab:cards()
local samplePanel=stage:GetChild('labPanel'):GetChild('cardSamples')
for i=1,math.min(3,#view.run.combat.hand)do
    local sample=samplePanel:GetChild('sample'..i);local formal=battlePanel:GetChild('card'..i)
    for _,key in ipairs({'name','type','label','cost'})do
        assert(sample:GetChild(key).text==formal:GetChild(key).text,'B candidate must preserve complete formal card text: '..key)
    end
end
local slot
for i=1,math.min(3,#view.run.combat.hand)do if F.Combat.canPlay(view.run.combat,view.run.combat.hand[i].uid,1)then slot=i;break end end
assert(slot,'same real test battle must leave one playable candidate card')
local uid=view.run.combat.hand[slot].uid
assert(lab:playSample(slot),'B candidate click must invoke the real battle command')
for _,card in ipairs(view.run.combat.hand)do assert(card.uid~=uid,'the played UID must leave the actual hand')end
assert(not lab:playSample(slot),'busy/stale B candidate click must not replay a card')
for _=1,80 do view:update(.1);lab:update(.1)end
local current=view.run.combat.hand[1]
if current then
    assert(lab.sampleBindings[1].uid==current.uid,'B candidate must rebind to the new real hand')
    assert(samplePanel:GetChild('sample1'):GetChild('label').text==battlePanel:GetChild('card1'):GetChild('label').text)
end
lab:destroy()
print('native 3D lab: actual GameUI + Run paired eight-command trace identical; card events drive native requests (offline mock bridge, no official animation verification)')
