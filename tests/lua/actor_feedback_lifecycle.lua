package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel=H.setup({'strike'},{'cultist'})
local feedback,battle=ui.feedback,host.run.combat
local id=battle.enemies[1].id
feedback.deaths[id]=true
feedback.poses.player={age=0,keys={{0,40,2},{1,0,1}}}
feedback:bindIdle(nil)
assert(feedback.deaths[id],'leaving combat must retain committed death history')
assert(feedback.shadow==nil and feedback.idleBattle==nil,'hidden battle retains no idle binding')
assert(next(feedback.poses)==nil and next(feedback.effects)==nil and not feedback.cardFlow:busy(),
    'preserving death history must not preserve transient visuals')
local portrait=panel:GetChild('hero'):GetChild('portrait')
local x,y,sx,sy=portrait.x,portrait.y,portrait.localScaleX,portrait.localScaleY
feedback:update(1)
assert(portrait.x==x and portrait.y==y and portrait.localScaleX==sx and portrait.localScaleY==sy,
    'retired death history must not keep an invisible animation alive')
feedback:bindIdle(battle)
assert(feedback.deaths[id],'reactivating this battle must not forget its death history')
local nextBattle=H.F.Combat.new(H.F.Data,{deck={'strike'},enemies={'cultist'},seed=12})
feedback:bindIdle(nil)
feedback:bindIdle(nextBattle)
assert(next(feedback.deaths)==nil,'a new battle with reused IDs must not inherit old deaths')
feedback.deaths[id]=true
feedback:cancel()
assert(next(feedback.deaths)==nil,'explicit cancellation remains a full reset')
print('LUA_ACTOR_FEEDBACK_LIFECYCLE_PASS death-ledger/visual-retirement/reactivation/new-battle/cancel')
