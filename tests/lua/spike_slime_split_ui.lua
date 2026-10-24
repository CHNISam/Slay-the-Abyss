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
local hp=b.enemies[5].hp;t('card1',21);t('enemy5',22);d();assert(b.enemies[5].hp==hp-6,'last existing ally stays targetable after index shift')
assert(not recovered,'mixed row feedback must not recover')
print=originalPrint
print('SPIKE_SPLIT_UI_PASS visible-intent/details/identity-frames/child-target/stale-parent-pointer')
