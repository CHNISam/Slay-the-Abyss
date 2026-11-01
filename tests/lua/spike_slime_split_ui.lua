local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
-- Real generated control regression for dynamic actor insertion and stale input.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local C=H.F.Combat
local EnemyView=require('abyss_battle_enemy_view')
local function enemyControl(ui,panel,state,index)
    local entry,slot=EnemyView.find(state,index)
    assert(entry and entry.actor==state.enemies[index] and entry.id==state.enemies[index].id,'real actor mapping')
    local box,nativeSlot=monsterControl(panel,'enemy'..slot)
    assert(box.visible and box:GetChild('name').text==entry.actor.name,'mapped actor name is visible')
    assert(box:GetChild('hp').text==entry.actor.hp..'/'..entry.actor.maxHp,'mapped actor HP')
    local _,tapActor=H.controls(panel);tapActor('enemy'..nativeSlot,69)
    assert(panel:GetChild('statusInfo').visible and ui.info.index==index and ui.info.id==entry.id,'mapped status control retains actor ID')
    panel:GetChild('statusInfo'):GetChild('hit').click()
    return slot,box,nativeSlot
end
local originalPrint, recovered = print, false
print=function(...) local s=tostring(select(1,...));if s:find('ABYSS_FEEDBACK recovered',1,true)then recovered=true end;originalPrint(...)end
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'spike_slime_l'})
local s=host.run.combat;local parent=s.enemies[1];parent.hp=36;host:refresh();tap('card1',8);tap('enemy1',9);drain()
assert(monsterControl(panel,'enemy1'):GetChild('intent').text=='' and not monsterControl(panel,'enemy1'):GetChild('intentLabel').visible)
dofile('tests/lua/support/intent_face_assertion.lua')(monsterControl(panel,'enemy1'),require('abyss_battle_intent_view').intentView(s,1),'分裂')
assert(require('abyss_battle_intent_view').intentView(s,1).label=='分裂')
tap('enemy1',10);local detail=inspectDetails(ui,panel);assert(detail:find('当前生命',1,true),'split detail must explain remaining HP')
local heldParent=monsterControl(panel,'enemy1'):GetChild('hit')
emit('enemy1','down',11)
tap('endTurn',12)
local deaths=0;for _,e in ipairs(ui.feedback.queue or {})do if e.kind=='death' then deaths=deaths+1;assert(e.detail.target==parent.id,'shifted child must not be mistaken for dead parent')end end
assert(deaths==1,'exactly the original parent fades')
drain()
dofile('tests/lua/support/monster_death_fixture.lua')(host,ui,parent.id)
assert(#s.enemies==3 and s.enemies[2]==parent,'source insertion order')
assert(parent.hp==0 and not EnemyView.find(s,2),'dead parent remains in core but has no display slot')
local left=enemyControl(ui,panel,s,1);local right,_,rightNative=enemyControl(ui,panel,s,3)
assert(left==1 and right==2 and not monsterControl(panel,'enemy3'),'both children occupy live display slots, parent hidden')
for i=4,5 do assert(not monsterControl(panel,'enemy'..i),'unused display slots hidden') end
assert(not recovered,'dynamic actor frames must not need recovery')
tap('card1',13);local hp1,hp3=s.enemies[1].hp,s.enemies[3].hp
for _,kind in ipairs({'up','click'})do if heldParent.listeners[kind]then heldParent.listeners[kind]({touchId=11})end end;drain()
assert(s.enemies[1].hp==hp1 and s.enemies[3].hp==hp3,'old-parent pointer must not attack new child')
tap('enemy'..rightNative,14);drain();assert(ui.target==3 and s.enemies[3].hp==hp3-6 and s.enemies[1].hp==hp1,'fresh child target uses new identity')
local h,u,p,e,t,d=H.setup({'strike'},{'sneaky_gremlin','spike_slime_l','spike_slime_m'})
local b=h.run.combat;local old=b.enemies[2];old.hp=36;h:refresh();t('card1',18);t('enemy2',19);d();t('endTurn',20);d()
dofile('tests/lua/support/monster_death_fixture.lua')(h,u,old.id)
assert(#b.enemies==5 and b.enemies[3]==old,'maximum supported row retains original parent')
assert(old.hp==0 and not EnemyView.find(b,3),'mixed row retains the dead core parent without a display slot')
for slot,index in ipairs({1,2,4,5}) do assert(enemyControl(u,p,b,index)==slot,'four live actors retain source order and identity') end
for i=1,5 do assert((monsterControl(p,'enemy'..i)~=nil)==(i<=4),'source instance visibility '..i)end
-- PR143's live preview/status controls must also describe newly inserted actors.
C.addStatus(b.enemies[2], 'vulnerable', 2)
u.target=2;h:refresh()
assert(p:GetChild('card1'):GetChild('label').text:find('6',1,true),'unaimed preview excludes the new child target modifiers')
local function statusTap(panel,index,touch)
    local hit=monsterControl(panel,'enemy'..index):GetChild('intentHit')
    for _,kind in ipairs({'down','up','click'}) do
        if hit.listeners[kind] then hit.listeners[kind]({touchId=touch}) end
    end
end
statusTap(p,2,23)
assert(p:GetChild('statusInfo').visible and u.info.id==b.enemies[2].id,'status details keep the spawned child identity')
t('hero',24)
assert(not p:GetChild('statusInfo').visible,'dismissal does not replace child details with another actor')
local _,_,lastSlot=enemyControl(u,p,b,5)
local hp=b.enemies[5].hp;t('card1',21);t('enemy'..lastSlot,22);d();assert(u.target==5 and b.enemies[5].hp==hp-6,'last existing ally stays targetable after index shift')
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
