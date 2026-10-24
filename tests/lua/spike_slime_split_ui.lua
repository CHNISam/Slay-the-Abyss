-- Real generated control regression for dynamic actor insertion and stale input.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C=H.F.Combat
local originalPrint, recovered = print, false
print=function(...) local s=tostring(select(1,...));if s:find('ABYSS_FEEDBACK recovered',1,true)then recovered=true end;originalPrint(...)end
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'spike_slime_l'})
local s=host.run.combat;local parent=s.enemies[1];C.damage(s,s.player,parent,parent.hp-30,true);host:refresh()
assert(panel:GetChild('enemy1'):GetChild('intent').text=='分裂','split intent must be visible before action')
tap('enemy1',10);assert(panel:GetChild('notice').text:find('当前生命',1,true),'split detail must explain remaining HP')
emit('enemy1','down',11)
tap('endTurn',12)
local deaths=0;for _,e in ipairs(ui.feedback.queue or {})do if e.kind=='death' then deaths=deaths+1;assert(e.detail.target==parent.id,'shifted child must not be mistaken for dead parent')end end
assert(deaths==1,'exactly the original parent fades')
drain()
assert(#s.enemies==3 and s.enemies[2]==parent,'source insertion order')
assert(panel:GetChild('enemy1').visible and not panel:GetChild('enemy2').visible and panel:GetChild('enemy3').visible,'both children visible, parent hidden')
assert(not recovered,'dynamic actor frames must not need recovery')
tap('card1',13);local hp1,hp3=s.enemies[1].hp,s.enemies[3].hp
emit('enemy1','up',11);emit('enemy1','click',11);drain()
assert(s.enemies[1].hp==hp1 and s.enemies[3].hp==hp3,'old-parent pointer must not attack new child')
tap('enemy3',14);drain();assert(s.enemies[3].hp==hp3-6 and s.enemies[1].hp==hp1,'fresh child target uses new identity')
local h,u,p,e,t,d=H.setup({'strike'},{'sneaky_gremlin','spike_slime_l','spike_slime_m'})
local b=h.run.combat;local old=b.enemies[2];C.damage(b,b.player,old,old.hp-30,true);h:refresh();t('endTurn',20);d()
assert(#b.enemies==5 and b.enemies[3]==old,'maximum supported row retains original parent')
for i=1,5 do assert(p:GetChild('enemy'..i).visible==(i~=3),'five-slot visibility '..i)end
-- PR143's live preview/status controls must also describe newly inserted actors.
C.addStatus(b.enemies[2], 'vulnerable', 2)
u.target=2;h:refresh()
assert(p:GetChild('card1'):GetChild('label').text:find('9',1,true),'live preview follows the new child target')
local function statusTap(panel,index,touch)
    local hit=panel:GetChild('enemy'..index):GetChild('statusRow'):GetChild('hit')
    for _,kind in ipairs({'down','up','click'}) do
        if hit.listeners[kind] then hit.listeners[kind]({touchId=touch}) end
    end
end
statusTap(p,2,23)
assert(p:GetChild('statusInfo').visible and u.info.id==b.enemies[2].id,'status details keep the spawned child identity')
t('hero',24)
assert(not p:GetChild('statusInfo').visible,'dismissal does not replace child details with another actor')
local hp=b.enemies[5].hp;t('card1',21);t('enemy5',22);d();assert(b.enemies[5].hp==hp-6,'last existing ally stays targetable after index shift')
assert(not recovered,'mixed row feedback must not recover')

-- Merged detail dismissal must never resurrect an enemy's one-shot ownership.
local test,finish=H.suite('SPIKE_SPLIT_STATUS_INPUT')
local function statusCase(name,sequence)
    test(name,function()
        local hh,uu,pp,ee,tt,dd=H.setup({'strike'},{'jaw_worm','cultist'})
        local ss=hh.run.combat
        tt('card1',9)
        local hp,energy,hand=ss.enemies[2].hp,ss.energy,#ss.hand
        sequence(hh,uu,pp,ee,tt)
        dd()
        assert(ss.energy==energy and ss.enemies[2].hp==hp and #ss.hand==hand,'interrupted pointer cannot spend or damage')
        -- A genuinely new Down may reuse the rejected pointer's numeric touch ID.
        tt('enemy2',11);dd()
        assert(ss.energy==energy-1 and ss.enemies[2].hp==hp-6,'fresh tap after interruption must still play once')
        ee('enemy2','click',11);dd()
        assert(ss.energy==energy-1 and ss.enemies[2].hp==hp-6,'successful pointer is also one-shot')
    end)
end
statusCase('two touches cannot revive a status-dismissal target',function(hh,uu,pp,ee,tt)
    statusTap(pp,2,10)
    assert(pp:GetChild('statusInfo').visible)
    ee('enemy2','down',11);assert(not pp:GetChild('statusInfo').visible)
    ee('hero','down',12);ee('enemy2','click',11)
end)
for _,up in ipairs({true,false}) do
    statusCase('swallowed '..(up and 'released' or 'held')..' pointer is consumed',function(hh,uu,pp,ee,tt)
        ee('enemy2','down',11);tt('hero',12)
        assert(pp:GetChild('statusInfo').visible)
        if up then ee('enemy2','up',11) end
        ee('enemy2','click',11);assert(not pp:GetChild('statusInfo').visible)
        ee('enemy2','click',11)
    end)
end
statusCase('opening details invalidates an older target even when another touch closes it',function(hh,uu,pp,ee,tt)
    ee('enemy2','down',11);tt('hero',12)
    assert(pp:GetChild('statusInfo').visible)
    tt('hero',13);assert(not pp:GetChild('statusInfo').visible)
    ee('enemy2','up',11);ee('enemy2','click',11)
end)
finish()
print=originalPrint
print('SPIKE_SPLIT_UI_PASS visible-intent/details/identity-frames/child-target/stale-parent-pointer')
