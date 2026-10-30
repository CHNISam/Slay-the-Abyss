local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local host,ui,panel,emit,tap,drain=H.setup({'strike'},{'fungi_beast','fungi_beast'})
local C=H.F.Combat
local EnemyView=require('abyss_battle_enemy_view')
local function same(a,b) if type(a)~='table' then assert(a==b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local s=host.run.combat;local definition=assert(s.catalog.statuses.spore_cloud,'death passive must be described')
local first,second=monsterControl(panel,'enemy1'),monsterControl(panel,'enemy2')
local function details(box,index)
    local hit=box:GetChild('hit')
    for _,kind in ipairs({'down','up','click'})do if hit.listeners and hit.listeners[kind]then hit.listeners[kind]({touchId=61})end end
    local info,lines=panel:GetChild('statusInfo'),{}
    assert(info.visible,'status details open')
    if index then assert(ui.info.index==index and ui.info.id==s.enemies[index].id,'status details retain true actor ID') end
    for i=1,H.F.Theme.layout.statusInfo.rows do
        local name=info:GetChild('name'..i)
        if name.visible then lines[#lines+1]=name.text end
    end
    info:GetChild('hit').click();assert(not info.visible,'status details close')
    return table.concat(lines,' | ')
end
assert(details(first,1):find(definition.name..' 2',1,true),'first Fungi passive visible')
assert(details(second,2):find(definition.name..' 2',1,true),'second Fungi passive visible')
local before=C.copy(s);host:refresh();tap('enemy1',3);same(s,before)
emit('enemy2','down',5) -- Keep the physical old control; never remap a held pointer.
s.enemies[1].hp=6;host:refresh();tap('card1',4);tap('enemy1',4)
local deaths,applications=0,0
for _,event in ipairs(ui.feedback.queue or {}) do
    if event.kind=='death' then deaths=deaths+1;assert(event.detail.target==s.enemies[1].id,'only the struck Fungi dies') end
    if event.kind=='status' and event.detail.status=='vulnerable' then
        applications=applications+1;assert(event.detail.target==s.player.id and event.detail.amount==2,'death cloud adds exactly two Vulnerable')
    end
end
assert(deaths==1 and applications==1,'one actual death emits one Spore Cloud application')
drain()
dofile('tests/lua/support/monster_death_fixture.lua')(host,ui,s.enemies[1].id)
assert(s.enemies[1].hp==0 and s.player.statuses.vulnerable==2,'real controls commit death power')
assert(details(panel:GetChild('hero')):find('易伤 2',1,true),'player receives visible Vulnerable')
local after=C.copy(s);local target=ui.target
emit('enemy2','up',5);emit('enemy2','click',5);drain();same(s,after)
assert(ui.target==target,'old physical control cannot follow the moved teammate')
local entry,slot=EnemyView.find(s,2)
assert(entry and entry.actor==s.enemies[2] and entry.id==s.enemies[2].id and slot==1,'living Fungi maps core2 to display1')
local living=monsterControl(panel,'enemy'..slot)
assert(living.visible and living:GetChild('name').text==entry.actor.name and living:GetChild('hp').text==entry.actor.hp..'/'..entry.actor.maxHp,'living Fungi name and HP remain visible')
for i=2,5 do assert(not monsterControl(panel,'enemy'..i),'dead and unused display slots hidden') end
assert(details(living,2):find(definition.name..' 2',1,true),'living teammate retains own passive')
print('SPORE_CLOUD_GENERATED_UI_PASS passive/read-only/real-card/target-status')
