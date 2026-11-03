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

-- Successful covers still use one final paint, rather than repairing the
-- failure by restoring the old redundant render on every page refresh.
local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local ui,panel=host.battleUI,root:GetChild('battlePanel')
local actor=F.actorControl(panel,'enemy1')
local render,renders=ui.render,0
ui.render=function(self,...)renders=renders+1;return render(self,...)end
assert(host:openDeck());assert(renders==1 and actor.alive and not actor.visible)
renders=0;assert(host:closeDeck());assert(renders==1 and actor.alive and actor.visible)
print('ok normal cover/uncover paints once and retains actor')
-- An active page failure is not a request to unmount or hide the battle.
local page=root:GetChild('mapPanel');local setter=page.SetVisible;local marker={}
page.SetVisible=function()error(marker)end
local ok,why=pcall(host.refresh,host)
assert(not ok and why==marker and actor.alive and actor.visible and ui.active)
-- If a native actor hide itself fails, the existing render lifecycle retires
-- its surfaces. Preserve the original sibling error, then allow fresh retry.
actor.SetVisible=function()error('native actor hide rejected')end
ok,why=pcall(host.openDeck,host)
assert(not ok and why==marker and not actor.alive,'failed hide must release native actor')
page.SetVisible=setter
host:refresh();assert(host:closeDeck())
local replacement=F.actorControl(panel,'enemy1')
assert(replacement~=actor and replacement.alive and replacement.visible)
print('ok failed native actor hide cleans up and recovers without masking page error')
-- A failure before render reaches its actor lifecycle must still release; a
-- failed release remains retryable via the Host's existing cleanup ownership.
for _,rejectRelease in ipairs({false,true})do
 local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
 local ui=host.battleUI;local actor=F.actorControl(root:GetChild('battlePanel'),'enemy1')
 local render,release=ui.render,ui.releaseMonsterSurfaces
 local marker={};root:GetChild('mapPanel').SetVisible=function()error(marker)end
 ui.render=function()error('render failed before actor lifecycle')end
 if rejectRelease then ui.releaseMonsterSurfaces=function()error('release rejected')end end
 local ok,why=pcall(host.openDeck,host)
 assert(not ok and why==marker,'cleanup replaced original page error')
 if rejectRelease then
  assert(host.monsterCleanupPending and actor.alive,'failed cleanup ownership lost')
 else assert(not actor.alive and not host.monsterCleanupPending,'fallback did not release actor')end
 ui.render,ui.releaseMonsterSurfaces=render,release
 -- Force the already-disabled retry branch, isolating pending cleanup from
 -- unrelated failing page setters. No native handles may survive it.
 if rejectRelease then host.disabled=true;assert(host:disable()==false);assert(not host.monsterCleanupPending and not actor.alive)end
 print('ok early render failure cleanup, rejected release='..tostring(rejectRelease))
end
for _,coverAgain in ipairs({false,true})do
local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local ui,panel=host.battleUI,root:GetChild('battlePanel')
local actor=F.actorControl(panel,'enemy1')
local page=root:GetChild('mapPanel');local pageSetter=page.SetVisible
local marker={page='map'}
page.SetVisible=function(self,value)
 self.SetVisible=pageSetter
 error(marker)
end
local start=panel:GetChild('start');local startSetter=start.SetVisible
local entered=false
start.SetVisible=function(self,value)
 self.SetVisible=startSetter
 entered=true
 assert(host:closeDeck(),'reentrant uncover must succeed')
 assert(ui.active and actor.alive and actor.visible,'new active scene should be valid before unwind')
 if coverAgain then assert(host:openDeck());assert(not ui.active and actor.alive and not actor.visible)end
 error('old recovery render failed after newer uncover',0)
end
local ok,why=pcall(host.openDeck,host)
assert(not ok and why==marker and entered,'reentrant cover must preserve original error')
print('ui_active='..tostring(ui.active)..', deck_visible='..tostring(host.deckUI.visible)..', actor_alive='..tostring(actor.alive)..', actor_visible='..tostring(actor.visible))
assert(actor.alive and actor.visible==not coverAgain,'obsolete cleanup destroyed the newer battle view')
assert(ui.active==not coverAgain and host.deckUI.visible==coverAgain)
print('ok reentrant recovery respects newer view, covered='..tostring(coverAgain))
end
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local api=F.monsterActors()
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{
 seed=1,monsterActors=api,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local ui,panel=host.battleUI,root:GetChild('battlePanel');local actor=F.actorControl(panel,'enemy1')
local page=root:GetChild('mapPanel');local setter=page.SetVisible;local marker={}
page.SetVisible=function(self,v)self.SetVisible=setter;error(marker)end
local render=ui.render
ui.render=function(self,...)self.render=render;error('fail before actor lifecycle',0)end
local destroy=api.destroy;local entered=false
api.destroy=function(control)
 api.destroy=destroy
 entered=true
 host:closeDeck() -- New refresh throws because native surface clear is still in progress.
 return destroy(control)
end
local ok,why=pcall(host.openDeck,host)
local surfaces=require('abyss_monster_surfaces').get(panel)
print('original_error='..tostring(not ok and why==marker)..', entered='..tostring(entered)..', active='..tostring(ui.active)..', actor_alive='..tostring(actor.alive)..', pending='..tostring(host.monsterCleanupPending)..', retained='..#surfaces.retained)
assert(not ok and why==marker and entered)
assert(host.monsterCleanupPending,'failed native release lost retry ownership after reentry')
assert(host:disable());assert(not actor.alive and #surfaces.retained==0 and not host.monsterCleanupPending)
print('ok native release reentry keeps retry ownership until disable succeeds')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local api=F.monsterActors()
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{
 seed=1,monsterActors=api,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local ui,panel=host.battleUI,root:GetChild('battlePanel');local actor=F.actorControl(panel,'enemy1')
local page=root:GetChild('mapPanel');local setter=page.SetVisible;local marker={}
page.SetVisible=function(self,v)self.SetVisible=setter;error(marker)end
local render=ui.render
ui.render=function(self,...)self.render=render;error('fail before actor lifecycle',0)end
local destroy=api.destroy;local entered=false
api.destroy=function(control)
 api.destroy=destroy
 entered=true
 local changed=pcall(host.closeDeck,host)
 assert(not changed) -- Native teardown may continue after the callback rejects.
 assert(host:disable())
 error('native destroy rejected after disabling newer view',0)
end
local ok,why=pcall(host.openDeck,host)
local surfaces=require('abyss_monster_surfaces').get(panel)
print('original_error='..tostring(not ok and why==marker)..', entered='..tostring(entered)..', active='..tostring(ui.active)..', actor_alive='..tostring(actor.alive)..', pending='..tostring(host.monsterCleanupPending)..', retained='..#surfaces.retained)
assert(not ok and why==marker and entered)
print('disabled='..tostring(host.disabled))
assert(host:disable()==false)
print('after_disable_retry_alive='..tostring(actor.alive)..', retained='..#surfaces.retained)
assert(not actor.alive,'already-disabled retry lost retained native actor')
