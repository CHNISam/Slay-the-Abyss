package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function card(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error('missing '..id)
end
local function closeUp(rod,finisher)
 local r=Run.new(D,42);local uids={}
 for _,c in ipairs(r.deck)do uids[#uids+1]=c.uid end
 for _,uid in ipairs(uids)do assert(Run.removeCard(r,uid))end
 assert(Run.obtainCard(r,'bludgeon'))
 if finisher then assert(Run.obtainCard(r,'searing_blow',{upgrades=20}))end
 if rod then assert(Run.obtainRelic(r,'tungsten_rod'))end
 r.floor=D.rules.map.bossFloor -- Explicit boss entry; not a natural route claim.
 assert(Run.startCombat(r,'boss_guardian'))
 local s=r.combat;local e=s.enemies[1];eq(e.hp,240);eq(e.statuses.mode_shift,30)
 assert(Run.play(r,card(s,'bludgeon').uid,1));eq(e.hp,208);eq(e.aiPhase,'defense')
 eq(e.statuses.sharp_hide or 0,0)
 assert(Run.endTurn(r));eq(e.statuses.sharp_hide,3);eq(C.intent(s,1).id,'guardian_6')
 return r,s,e
end
local function sharp(s,first)
 local found
 for i=first,#s.events do
  local e=s.events[i]
  if e.kind=='status_damage'and e.detail.status=='sharp_hide'then
   assert(not found,'duplicate Sharp Hide event');found=e
  end
 end
 assert(found,'missing Sharp Hide event');return found.detail
end
local failed=0
for _,rod in ipairs({false,true})do
 local r,s,e=closeUp(rod,false);local hp,first=s.player.hp,#s.events+1
 assert(Run.play(r,card(s,'bludgeon').uid,1));eq(e.hp,176)
 local lost=hp-s.player.hp;local expected=rod and 2 or 3
 local event=sharp(s,first);eq(event.source,e.id);eq(event.target,s.player.id)
 eq(event.amount,lost);eq(event.blocked,0)
 print('public real Close Up rod='..tostring(rod)..' actual='..lost..' expected='..expected)
 if lost~=expected then failed=failed+1 end
end
do
 local r,s,e=closeUp(true,true);local hp,first=s.player.hp,#s.events+1
 -- Actual upgraded card executes the lethal attack; neither actor HP nor
 -- Sharp Hide is injected. The 20 upgrades are an explicit card-entry boundary.
 assert(Run.play(r,card(s,'searing_blow').uid,1));eq(e.hp,0)
 local lost=hp-s.player.hp;eq(sharp(s,first).amount,lost)
 eq(r.phase,'reward');eq(r.lastResult.outcome,'victory')
 print('public dead final Guardian actual='..lost..' expected=2')
 if lost~=2 then failed=failed+1 end
end
assert(failed==0,tostring(failed)..' real Guardian Rod regressions')
print('GUARDIAN_SHARP_HIDE_ROD_PASS 3')
