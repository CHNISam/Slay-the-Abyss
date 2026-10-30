local Native=dofile('tests/lua/support/current_monster_controls.lua')
-- Real generated control regression for dynamic actor insertion and stale input.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local C=H.F.Combat
local EnemyView=require('abyss_battle_enemy_view')
local function enemyControl(ui,panel,state,index)
    local entry,slot=EnemyView.find(state,index)
    assert(entry and entry.actor==state.enemies[index] and entry.id==state.enemies[index].id,'real actor mapping')
    local box,nativeSlot=Native.actor(panel,state.enemies[index])
    assert(box.visible and box:GetChild('name').text==entry.actor.name,'mapped actor name is visible')
    assert(box:GetChild('hp').text==entry.actor.hp..'/'..entry.actor.maxHp,'mapped actor HP')
    local hit=box:GetChild('hit');for _,kind in ipairs({'down','up','click'}) do if hit.listeners[kind] then hit.listeners[kind]({touchId=700+index}) end end
    assert(panel:GetChild('statusInfo').visible and ui.info.index==index and ui.info.id==entry.id,'mapped status control retains actor ID')
    panel:GetChild('statusInfo'):GetChild('hit').click()
    return nativeSlot,box
end
local originalPrint, recovered = print, false
print=function(...) local s=tostring(select(1,...));if s:find('ABYSS_FEEDBACK recovered',1,true)then recovered=true end;originalPrint(...)end
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'acid_slime_l'})
host.run.combat=C.copy(host.run.combat) -- Install the damaged boundary before this battle's initial source display.
local s=host.run.combat;local parent=s.enemies[1];C.damage(s,s.player,parent,parent.hp-30,true);host:refresh()
assert(Native.actor(panel,s.enemies[1]):GetChild('intent').text=='' and not Native.actor(panel,s.enemies[1]):GetChild('intentLabel').visible)
dofile('tests/lua/support/intent_face_assertion.lua')(Native.actor(panel,parent),require('abyss_battle_intent_view').intentView(s,1),'分裂')
assert(require('abyss_battle_intent_view').intentView(s,1).label=='分裂')
tap('enemy1',10);local detail=inspectDetails(ui,panel);assert(detail:find('当前生命',1,true),'split detail must explain remaining HP');assert(detail:find(s.catalog.enemies.acid_slime_m.name,1,true),'split detail must name the actual Acid child');assert(not detail:find('棘刺',1,true),'Acid must not claim Spike offspring')
local oldParentBox=Native.actor(panel,parent);local oldParentHit=oldParentBox:GetChild('hit');local oldUp,oldClick=oldParentHit.listeners.up,oldParentHit.listeners.click
emit('enemy1','down',11)
tap('endTurn',12)
local deaths=0;for _,e in ipairs(ui.feedback.queue or {})do if e.kind=='death' then deaths=deaths+1;assert(e.detail.target==parent.id,'shifted child must not be mistaken for dead parent')end end
assert(deaths==1,'exactly the original parent fades')
drain()
for _=1,400 do if not next(ui.feedback.dying) then break end;host:update(.05) end
assert(not next(ui.feedback.dying))
assert(#s.enemies==3 and s.enemies[2]==parent,'source insertion order')
assert(parent.hp==0 and not EnemyView.find(s,2),'dead parent remains in core but has no display slot')
local left=enemyControl(ui,panel,s,1);local right=enemyControl(ui,panel,s,3)
assert(left~=right and oldParentBox.alive==false,'both children have native actors and the parent control is retired')
Native.count(panel,2)
assert(not recovered,'dynamic actor frames must not need recovery')
tap('card1',13);local hp1,hp3=s.enemies[1].hp,s.enemies[3].hp
if oldUp then oldUp({touchId=11})end;if oldClick then oldClick({touchId=11})end;drain()
assert(s.enemies[1].hp==hp1 and s.enemies[3].hp==hp3,'old-parent pointer must not attack new child')
tap('enemy'..right,14);drain();assert(ui.target==3 and s.enemies[3].hp==hp3-6 and s.enemies[1].hp==hp1,'fresh child target uses new identity')
local h,u,p,e,t,d=H.setup({'strike'},{'sneaky_gremlin','acid_slime_l','acid_slime_m'})
h.run.combat=C.copy(h.run.combat)
local b=h.run.combat;local old=b.enemies[2];C.damage(b,b.player,old,old.hp-30,true);h:refresh();t('endTurn',20);d()
for _=1,400 do if not next(u.feedback.dying) then break end;h:update(.05) end
assert(not next(u.feedback.dying))
assert(#b.enemies==5 and b.enemies[3]==old,'maximum supported row retains original parent')
assert(old.hp==0 and not EnemyView.find(b,3),'mixed row retains the dead core parent without a display slot')
local nativeSlots={}
for slot,index in ipairs({1,2,4,5}) do local _,sourceSlot=EnemyView.find(b,index);assert(sourceSlot==slot,'four live actors retain source core order');local actual=enemyControl(u,p,b,index);assert(not nativeSlots[actual],'native actors retain distinct identities');nativeSlots[actual]=true end
Native.count(p,4)
-- PR143's live preview/status controls must also describe newly inserted actors.
C.addStatus(b.enemies[2], 'vulnerable', 2)
u.target=2;h:refresh()
assert(p:GetChild('card1'):GetChild('label').text:find('6',1,true),'unaimed preview excludes the new child target modifiers')
local function statusTap(panel,actor,touch)
    local hit=Native.power(Native.actor(panel,actor),actor.statuses.vulnerable and 'vulnerable' or 'artifact'):GetChild('hit')
    for _,kind in ipairs({'down','up','click'}) do
        if hit.listeners[kind] then hit.listeners[kind]({touchId=touch}) end
    end
end
statusTap(p,b.enemies[2],23)
assert(p:GetChild('statusInfo').visible and u.info.id==b.enemies[2].id,'status details keep the spawned child identity')
t('hero',24)
assert(not p:GetChild('statusInfo').visible,'dismissal does not replace child details with another actor')
local lastSlot=enemyControl(u,p,b,5)
local hp=b.enemies[5].hp;t('card1',21);t('enemy'..lastSlot,22);d();assert(u.target==5 and b.enemies[5].hp==hp-6,'last existing ally stays targetable after index shift')
assert(not recovered,'mixed row feedback must not recover')


print=originalPrint
print('ACID_SPLIT_UI_PASS actual-child-name/three-and-five-slots/identity/stale-pointer/child-target')
