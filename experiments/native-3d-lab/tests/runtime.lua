package.path='experiments/native-3d-lab/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path
local Lab=dofile('experiments/native-3d-lab/runtime.lua')
Enum={CursorEventType={CursorClick=1}}
local function control(name,children)
    local c={name=name,children={},activeInHierarchy=true,alive=true,listeners={}}
    for _,v in ipairs(children or {})do c.children[v.name]=v end
    function c:GetChild(key)return self.children[key]end
    function c:SetVisible(value)self.activeInHierarchy=value end
    function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
    function c:SetLocalScale(x,y,z)self.scale={x,y,z}end
    function c:SetAsLastSibling()self.raised=true end
    function c:AddCursorEventListener(event,fn)self.listeners[event]=fn end
    function c:RemoveCursorEventListener(event,fn)if self.listeners[event]==fn then self.listeners[event]=nil end end
    return c
end
local function makeRoot()
    local menu={control('mode'),control('hint')}
    for _,name in ipairs({'compare','model','animations','combat','cards','performance','idle','attack','hit','death','all','stop','reset','logs','tween'})do
        menu[#menu+1]=control(name,{control('hit'),control('label')})
    end
    local samples={control('sampleTitle')}
    for i=1,3 do samples[#samples+1]=control('sample'..i,{control('name'),control('cost'),control('type'),control('label'),control('note'),control('hit')})end
    return control('root',{
        control('canvasBackdrop'),control('stage',{
            control('battlePanel',{control('hero',{control('portrait'),control('border'),control('plate'),control('shadow'),control('glow'),control('hp'),control('name'),control('hit')}),control('backdrop')}),
            control('labPanel',{
                control('fold',{control('hit'),control('label')}),control('menu',menu),
                control('diagnostics',{control('title'),control('status'),control('metrics'),control('log')}),control('cardSamples',samples),
            }),
        }),
    })
end
local function fixture(available,tween)
    local sent,logs={},{}
    local catalog={cards={strike={name='打击',cost=1},defend={name='防御',cost=1}}}
    local function hand()return {{cardId='strike',uid=1},{cardId='defend',uid=2}}end
    local Run={}
    function Run.new(data,seed)return {seed=seed,phase='map',data=data}end
    function Run.startCombat(run,id)
        assert(id=='cultist_solo');run.phase='combat'
        run.combat={phase='player',turn=1,energy=3,player={hp=80,block=0},
            enemies={{id='enemy1',hp=100,block=0}},catalog=catalog,hand=hand(),draw={},discard={},exhaust={},events={}}
        return true
    end
    local Combat={canPlay=function(s,uid,target)
        for _,c in ipairs(s.hand)do if c.uid==uid then return s.energy>0 and target==1 end end
        return false
    end}
    local feedback={start=function()end,cancel=function(self)self.cancelled=(self.cancelled or 0)+1 end}
    local ui={feedback=feedback}
    function ui:playSelected(target)
        local s=self.run.combat
        local before={enemies={{hp=s.enemies[1].hp}}};local first=#s.events+1
        for i,c in ipairs(s.hand)do if c.uid==self.selected then
            table.remove(s.hand,i);s.discard[#s.discard+1]=c;s.energy=s.energy-1
            s.events[#s.events+1]={kind='play',detail={cardId=c.cardId}}
            if c.cardId=='strike'then
                s.enemies[target].hp=s.enemies[target].hp-6
                s.events[#s.events+1]={kind='damage',detail={source='player',target='enemy1',amount=6}}
            else s.player.block=s.player.block+5 end
            break
        end end
        self.selected=nil;feedback:start(before,s,first)
    end
    function ui:endTurn()
        local s=self.run.combat;s.turn=s.turn+1;s.energy=3;s.hand=hand();s.player.hp=s.player.hp-6
        s.player.block=0;s.discard={};s.events={}
    end
    local root=makeRoot()
    local view={battleUI=ui,mapUI={},nodeUI={}}
    function view:refresh()self.refreshed=(self.refreshed or 0)+1 end
    local api={tween=tween,config={buildId='test-only',nativeAvailable=available,
        models={{name='守卫',hit=true},{name='史莱姆',hit=false},{name='丘丘人',hit=false}}},
        Run=Run,Combat=Combat,Map={generate=function()return {seed=42}end},data={},clickEvent=1,
        send=function(command,model,actor,seq)sent[#sent+1]={command=command,model=model,actor=actor,seq=seq}end,
        log=function(line)logs[#logs+1]=line end}
    local callback,unsubscribed
    api.register=function(fn)callback=fn;return function()unsubscribed=true end end
    local lab=Lab.attach(view,root,api)
    return {lab=lab,view=view,root=root,sent=sent,logs=logs,api=api,
        ack=function(message,seq)callback(message,seq or lab.pending.seq)end,
        unsubscribed=function()return unsubscribed end}
end
local stats=Lab.statistics({.01,.02,.03,.04})
assert(stats.count==4 and math.abs(stats.meanMs-25)<.00001 and stats.fps==40 and stats.p95Ms==40 and stats.p99Ms==40)
assert(Lab.statistics({})==nil)

local f=fixture(true);local lab=f.lab
assert(f.view.run.seed==42 and f.view.run.combat.enemies[1].hp==100)
lab:setMode('3D');local first=lab.pending.seq
f.ack('created:initializing_4.5s');assert(lab.mode=='2D' and lab.pending)
f.ack('ready');assert(lab.mode=='3D' and not lab.pending)
local backdrop=f.root:GetChild('canvasBackdrop');assert(backdrop.activeInHierarchy==false)
local hero=f.root:GetChild('stage'):GetChild('battlePanel'):GetChild('hero')
for _,name in ipairs({'portrait','border','plate','shadow','glow'})do assert(hero:GetChild(name).activeInHierarchy==false)end
for _,name in ipairs({'hp','name','hit'})do assert(hero:GetChild(name).activeInHierarchy==true)end
lab:animation('attack');lab:update(.01);assert(lab.pending.command=='attack')
f.ack('requested');assert(lab.pending)
f.ack('completed:attack');assert(not lab.pending)
lab:stop();assert(lab.mode=='2D' and lab.job==nil and #lab.queue==0 and backdrop.activeInHierarchy==true)
assert(f.sent[#f.sent].command=='hide' and f.sent[#f.sent].actor==0)
f.ack('ready',first);assert(lab.mode=='2D','stale ready must not recreate 3D')
f.ack('hidden');assert(not lab.pending)

lab:setMode('3D');lab:update(15)
assert(lab.mode=='2D' and lab.wanted=='2D' and not lab.pending,'missing bridge must time out and recover')
local found=false;for _,line in ipairs(f.logs)do if line:find('TIMEOUT',1,true)then found=true end end;assert(found)

lab:setMode('3D');f.ack('ready');lab:animation('attack');lab:update(.01)
assert(lab.pending.command=='attack');lab:stop();f.ack('hidden')
assert(#lab.queue==0 and not lab.pending,'stop cancels queued and in-flight ownership')
lab:performance()
for i=1,600 do
    if lab.pending then
        local command=lab.pending.command
        f.ack(command=='show' and 'ready' or command=='hide' and 'hidden' or 'completed:'..command)
    end
    lab:update(.1)
end
assert(not lab.job,'finite performance job must finish')
assert(lab.results['2D'] and lab.results['3D'])
assert(lab.results['2D'].trace==lab.results['3D'].trace,'performance branches must retain the same core trace')
assert(lab.results['2D'].actions==lab.results['3D'].actions and lab.results['2D'].actions>0)
assert(lab.results['2D'].metrics.count>100 and lab.results['3D'].metrics.count>100)
assert(lab.results['2D'].actions==8,'paired runs must use the same fixed action count')
assert(lab.results['2D'].valid and lab.results['3D'].valid and lab.pairValid)

-- A delayed hide must not contaminate 2D samples; delayed ready cannot play cards early.
lab:performance();lab:update(0)
assert(lab.job.current.ready=='2D' and lab.pending.command=='hide')
lab:update(5)
assert(not lab.sampleActive and lab.automatedActions==0 and lab.job.elapsed==0)
f.ack('hidden');lab:update(2.1)
assert(lab.sampleActive and lab.job.current.sample=='2D')
for i=1,300 do
    lab:update(.1)
    if lab.job and lab.job.current.ready=='3D' then break end
end
assert(lab.pending.command=='show');local actionsBefore=lab.automatedActions
lab:update(6)
assert(lab.job.current.ready=='3D' and not lab.sampleActive and lab.automatedActions==actionsBefore)
f.ack('ready');lab:update(2.1)
assert(lab.sampleActive and lab.automatedActions==0,'3D actions start only after ready and warmup')
lab:stop();f.ack('hidden')
lab:destroy();assert(f.unsubscribed());assert(f.view.battleUI.feedback.start~=lab.feedbackWrapper)
local count=#f.sent;lab:update(50);assert(#f.sent==count)

local unavailable=fixture(false)
assert(unavailable.lab:setMode('3D')==false)
unavailable.lab:cards();assert(unavailable.lab.cardMode==1)
unavailable.lab:cards();assert(unavailable.lab.cardMode==2)
unavailable.lab:cards();assert(unavailable.lab.cardMode==0)
unavailable.lab:all()
for i=1,2500 do unavailable.lab:update(.1)end
assert(not unavailable.lab.job,'unsupported native stage must not block the rest of the menu')
assert(unavailable.lab.results['2D'] and not unavailable.lab.results['3D'].metrics)
unavailable.lab:stop();unavailable.api.Map.generate=function()error('test map failure')end
local ok=pcall(unavailable.lab.startBattle,unavailable.lab);assert(not ok)
unavailable.lab:cards();assert(unavailable.lab.cardMode==1,'one experiment failure must leave other menu actions callable')
assert(#unavailable.lab.logs<=12)

local function pairNeverPassed(fixture)
    assert(fixture.lab.pairValid==false)
    for _,line in ipairs(fixture.logs)do assert(not line:find('PASS 核心状态',1,true),line)end
end
-- Actual review reproduction: drop the first 3D hit reply, then acknowledge all other commands.
local interrupted=fixture(true);interrupted.lab:performance();local dropped
for _=1,800 do
    local p=interrupted.lab.pending
    if p then
        if not dropped and interrupted.lab.sampleActive and interrupted.lab.mode=='3D' and p.command=='hit'then dropped=p.seq end
        if p.seq~=dropped then interrupted.ack(p.command=='show' and 'ready' or p.command=='hide' and 'hidden' or 'completed:'..p.command,p.seq)end
    end
    interrupted.lab:update(.1)
end
assert(dropped,'negative control must reach a real queued hit request')
local bad=interrupted.lab.results['3D']
assert(bad and not bad.valid and bad.metrics==nil and bad.failureReason:find('超时',1,true))
pairNeverPassed(interrupted)

-- A stalled command sequence reaches maxDuration; missing metrics can never be a fair pair.
local stalled=fixture(true);stalled.lab:performance()
for _=1,900 do
    local p=stalled.lab.pending
    if p then stalled.ack(p.command=='show' and 'ready' or p.command=='hide' and 'hidden' or 'completed:'..p.command,p.seq)end
    if stalled.lab.job and stalled.lab.job.current and stalled.lab.job.current.sample=='3D'then stalled.view.battleUI.busy=true end
    stalled.lab:update(.1)
end
bad=stalled.lab.results['3D']
assert(bad and not bad.valid and bad.metrics==nil and bad.failureReason:find('最长时限',1,true))
pairNeverPassed(stalled)

local changed=fixture(true);changed.lab:performance()
for _=1,600 do
    local p=changed.lab.pending
    if p then changed.ack(p.command=='show' and 'ready' or p.command=='hide' and 'hidden' or 'completed:'..p.command,p.seq)end
    changed.lab:update(.1)
    if changed.lab.sampleActive and changed.lab.mode=='3D'then changed.lab:setMode('2D');break end
end
for _=1,100 do
    local p=changed.lab.pending;if p then changed.ack('hidden',p.seq)end
    changed.lab:update(.1)
end
assert(changed.lab.results['3D'].valid==false and changed.lab.results['3D'].metrics==nil)
pairNeverPassed(changed)

local terminal=fixture(true);terminal.lab:setMode('3D');terminal.ack('ready')
terminal.lab:animation('death');terminal.lab:update(.01);terminal.ack('completed:death')
terminal.lab:animation('attack');terminal.lab:update(.01);terminal.ack('missing_actor:show_first')
assert(not terminal.lab.pending and terminal.lab.readyMode==nil and terminal.lab.status:find('重建',1,true))
terminal.lab:modelNext();terminal.ack('ready');terminal.lab:animation('attack');terminal.lab:update(.01)
terminal.ack('busy:wait_ready_or_animation')
assert(not terminal.lab.pending and #terminal.lab.queue==0 and terminal.lab.status:find('跳过',1,true))

local starts,cancels={},{}
local tween={start=function(view,mode)starts[#starts+1]=mode;return true end,
    cancel=function(view,reason)cancels[#cancels+1]=reason end,
    status=function()return 'Tween结果：脚本帧间隔，非GPU帧率'end}
local t=fixture(true,tween)
assert(t.lab:tween() and starts[1]=='manual')
t.lab:update(.6);assert(t.lab.status:find('Tween结果',1,true))
assert(t.lab:tween() and starts[2]=='tween')
t.lab:stop();assert(cancels[#cancels]=='stop' and not t.lab.tweenWatching)
t.lab:tween();t.lab:startBattle();assert(cancels[#cancels]=='battle_reset')
tween.start=function()return false,'native Tween API unavailable'end
assert(t.lab:tween()==false and t.lab.status:find('unavailable',1,true))
t.lab:destroy();assert(cancels[#cancels]=='destroy')
print('native 3D lab runtime: lifecycle, bridge, trace parity, bounded metrics and unsupported-stage recovery passed')
