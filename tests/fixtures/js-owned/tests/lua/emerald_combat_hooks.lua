package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local D=require('abyss_data')
local function boost(roll)return{version=1,act=1,nodeId='f8_l2',x=1,y=7,roll=roll}end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS emerald combat '..count..' '..name)end
test('constructor applies each source boost after preBattle and before opening draw callbacks',function()
 for roll=0,3 do
  local plain=assert(C.new(D,{seed=42,enemies={'cultist','cultist'}}))
  local observed=false
  local s=assert(C.new(D,{seed=42,enemies={'cultist','cultist'},emeraldBoost=boost(roll),beforeFirstTurn=function(state)
   observed=true
   for i,e in ipairs(state.enemies)do
    if roll==0 then assert(e.statuses.strength==2)
    elseif roll==1 then
     local extra=math.floor(require('abyss_sts_random').float32(plain.enemies[i].maxHp*.25)+.5)
     assert(e.maxHp==plain.enemies[i].maxHp+extra and e.hp==e.maxHp)
    elseif roll==2 then assert(e.statuses.metallicize==4)
    else assert(e.statuses.regenerate_monster==3)end
   end
   return true
  end}))
  assert(observed and #s.enemies==2)
 end
end)
test('ordinary monster Regen heals at group end without decay or player Mark interference',function()
 local s=assert(C.new(D,{seed=42,enemies={'cultist'},emeraldBoost=boost(3)}))
 s.relics={'mark_of_bloom'};local e=s.enemies[1];e.hp=e.maxHp-5
 assert(C.endTurn(s));assert(e.hp==e.maxHp-2 and e.statuses.regenerate_monster==3)
end)
test('Awakened native Regen plus elite boost is resolved once',function()
 local s=assert(C.new(D,{seed=42,enemies={'awakened_one'},emeraldBoost=boost(3)}))
 local e=s.enemies[1];assert(e.statuses.regenerate_monster==13);e.hp=e.maxHp-20
 assert(C.endTurn(s));assert(e.hp==e.maxHp-7,'Awakened must not heal twice')
end)
test('generic Regen retains its source owner-end order before later Shackled',function()
 local A=require('abyss_actor')
 local s=assert(C.new(D,{seed=42,enemies={'cultist'},emeraldBoost=boost(3)}))
 local e=s.enemies[1];e.hp=e.maxHp-5
 assert(A.applyPower(s,e,'strength',-2,s.player));assert(A.applyPower(s,e,'shackled',2,s.player))
 local first=#s.events;assert(C.endTurn(s))
 local healing,restoring
 for i=first+1,#s.events do local event=s.events[i]
  if event.kind=='heal'and event.detail.target==e.id and event.detail.status=='regenerate_monster'then healing=i end
  if event.kind=='status'and event.detail.target==e.id and event.detail.status=='strength'and event.detail.amount==2 then restoring=i end
 end
 assert(healing and restoring and healing<restoring,'monster owner-end Power order must remain stable: '..tostring(healing)..' / '..tostring(restoring))
 assert(e.statuses.strength==0 and not e.statuses.shackled)
end)
test('invalid or failed construction rejects without publishing a battle',function()
 local bad=boost(3);bad.act=4
 local called,result=pcall(C.new,D,{seed=42,enemies={'cultist'},emeraldBoost=bad})
 assert(not called or result==nil)
 local accepted,why=C.new(D,{seed=42,enemies={'cultist'},emeraldBoost=boost(3),beforeFirstTurn=function()return false,'late_setup_fault'end})
 assert(accepted==nil and why=='late_setup_fault')
end)
print('EMERALD_COMBAT_HOOKS_PASS '..count..' real constructor/end-turn; controlled boost, not natural key acceptance')
