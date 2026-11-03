-- Real Host contract: preserve eager render ordering across native callbacks.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Surfaces=require('abyss_monster_surfaces')
local function fixture()
 local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
 local panel=root:GetChild('battlePanel')
 return host,root,panel,F.actorControl(panel,'enemy1')
end
local function check(name,body)
 if not ABYSS_VISIBILITY_CASE or ABYSS_VISIBILITY_CASE==name then body()end
end
-- Error-order boundary: both real native rendering and later sibling visibility reject.
check("priority",function()
 local host,root,panel,actor=fixture();local rm,vm={},{};local reached=false
 panel:GetChild('start').SetVisible=function()error(rm)end
 root:GetChild('mapPanel').SetVisible=function()reached=true;error(vm)end
 local ok,why=pcall(host.openDeck,host)
 assert(not ok)
 assert(why==rm and not reached,'render error must precede later page setter');
 print('CASE priority marker='..(why==rm and 'render' or why==vm and 'visibility' or 'other')..' map_reached='..tostring(reached))
end)
-- Active refresh must retain its committed display work before a later setter fails.
check("active",function()
 local host,root,panel=fixture();assert(panel:GetChild('energy').text=='3/3')
 host.run.combat.energy=1;local vm={}
 root:GetChild('mapPanel').SetVisible=function()error(vm)end
 local ok,why=pcall(host.refresh,host);assert(not ok and why==vm)
 assert(panel:GetChild('energy').text=='1/3','active display must commit before sibling failure');
 print('CASE active_energy value='..panel:GetChild('energy').text..' active='..tostring(host.battleUI.active))
end)
-- Failing the first page setter is before this refresh's activation/render boundary.
check("early",function()
 local host,root,panel=fixture();assert(host:openDeck())
 local count,render=0,host.battleUI.render;local vm={}
 host.battleUI.render=function(self,...)count=count+1;return render(self,...)end
 root:GetChild('menuPanel').SetVisible=function()error(vm)end
 local before=host.battleUI.rewardRender
 local ok,why=pcall(host.refresh,host);assert(not ok and why==vm)
 assert(count==0 and host.battleUI.rewardRender==before,'pre-activation failure must not render');
 print('CASE early_menu renders='..count..' rewardRender_delta='..(host.battleUI.rewardRender-before))
end)
-- Native callback commits a real lethal Run command without requesting a new Host refresh.
check("lethal",function()
 local host,root,panel,actor=fixture();local battle=host.run.combat
 battle.enemies[1].hp=1;battle.enemies[1].block=0;host:refresh()
 local uid
 for _,card in ipairs(battle.hand)do
  if battle.catalog.cards[card.cardId].type=='attack' and F.Combat.canPlay(battle,card.uid,1)then uid=card.uid;break end
 end
 assert(uid,'initial hand has usable attack')
 local vm={};local page=root:GetChild('mapPanel');local setter=page.SetVisible
 page.SetVisible=function()
  assert(Run.play(host.run,uid,1));assert(host.run.phase=='reward');error(vm)
 end
 local ok,why=pcall(host.openDeck,host);assert(not ok and why==vm)
 local manager=Surfaces.get(panel)
 assert(actor.alive and not actor.visible and manager:find(battle.enemies[1].id)==actor,'lethal reentry must preserve already hidden actor on failure');
 print('CASE lethal phase='..host.run.phase..' alive='..tostring(actor.alive)..' visible='..tostring(actor.visible)..' same='..tostring(manager:find(battle.enemies[1].id)==actor))
 page.SetVisible=setter;local retried,err=pcall(host.refresh,host)
 print('CASE lethal_retry ok='..tostring(retried)..' old_alive='..tostring(actor.alive)..' phase='..host.run.phase)
 assert(retried,tostring(err))
end)
-- The setter makes an earlier native render operation invalid before throwing.
check("condition",function()
 local host,root,panel,actor=fixture();local vm,rm={},{}
 root:GetChild('mapPanel').SetVisible=function()
  panel:GetChild('start').SetVisible=function()error(rm)end
  error(vm)
 end
 local ok,why=pcall(host.openDeck,host);assert(not ok and why==vm)
 assert(actor.alive and not actor.visible,'later setter cannot retroactively invalidate hidden actor');
 print('CASE changed_render_condition alive='..tostring(actor.alive)..' visible='..tostring(actor.visible))
end)

if ABYSS_VISIBILITY_CASE then return end

-- Real Host lifecycle regression: a failed sibling page setter must not leave
-- suspended native monster actors visible. This is offline native API injection.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
for _,page in ipairs({'mapPanel','nodePanel'})do
 local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
 local panel=root:GetChild('battlePanel')
 local actor=F.actorControl(panel,'enemy1')
 assert(actor.visible and actor.alive)
 local original= root:GetChild(page).SetVisible
 local marker={page=page}
 root:GetChild(page).SetVisible=function()error(marker)end
 local ok,why=pcall(host.openDeck,host)
 assert(not ok and why==marker,'visibility failure must propagate unchanged')
 assert(host.deckUI.visible and not host.battleUI.active,'cover state was not committed')
 assert(actor.alive and not actor.visible,'failed page setter left suspended actor visible')
 root:GetChild(page).SetVisible=original
 host:refresh()
 assert(F.actorControl(panel,'enemy1')==actor and actor.alive and not actor.visible,'covered retry replaced actor')
 assert(host:closeDeck())
 assert(F.actorControl(panel,'enemy1')==actor and actor.alive and actor.visible,'uncover retry did not restore retained actor')
 print('ok '..page..' failure preserves actor lifecycle and error identity')
end


-- Two observable paints are required around arbitrary native callbacks. The
-- first commits activation; the second reflects a successful reentrant command.
do
 local host,root,panel,actor=fixture()
 local ui=host.battleUI;local render,count=ui.render,0
 ui.render=function(self,...)count=count+1;return render(self,...)end
 assert(host:openDeck());assert(count==2 and actor.alive and not actor.visible)
 count=0;assert(host:closeDeck());assert(count==2 and actor.alive and actor.visible)
 print('CASE normal cover/uncover ordered renders=2')
end
-- An early render error may itself reenter a newer view. Do not compensate by
-- destroying or repainting that newer active or covered view after unwind.
for _,coverAgain in ipairs({false,true})do
 local host,root,panel,actor=fixture()
 local start=panel:GetChild('start');local setter=start.SetVisible;local marker={}
 start.SetVisible=function(self,value)
  self.SetVisible=setter
  assert(host:closeDeck())
  if coverAgain then assert(host:openDeck())end
  error(marker)
 end
 local ok,why=pcall(host.openDeck,host)
 assert(not ok and why==marker and actor.alive)
 assert(host.deckUI.visible==coverAgain and host.battleUI.active==not coverAgain)
 assert(actor.visible==not coverAgain,'old unwind modified newer actor')
 assert(host:disable());assert(not actor.alive)
 print('CASE reentrant render preserves newer view '..tostring(coverAgain))
end
