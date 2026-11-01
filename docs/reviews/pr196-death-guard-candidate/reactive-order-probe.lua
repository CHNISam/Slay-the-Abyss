package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local R=require('abyss_run')
local data=require('abyss_data')
local tests,failed=0,0
local function eq(actual,expected,label)
  assert(actual==expected,(label or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function check(name,fn)
  tests=tests+1
  local ok,why=pcall(fn)
  if not ok then failed=failed+1 end
  print((ok and 'PASS ' or 'FAIL ')..tests..' '..name..(ok and '' or ' | '..tostring(why)))
end
local function card(s,id,up)
  local c={uid=s.nextUid,cardId=id,upgraded=up==true}
  s.nextUid=s.nextUid+1
  return c
end
local function held(s,id,up)
  local c=card(s,id,up);s.hand[#s.hand+1]=c;return c
end
local function play(r,c)
  local ok,why=R.play(r,c.uid,1);assert(ok,why)
end
local function guardian()
  local r=R.new(data,'99');r.floor=16;r.deck={};r.relics={}
  assert(R.startRoomCombat(r,'boss'))
  local s=r.combat
  s.energy=20
  play(r,held(s,'bludgeon'))
  eq(s.enemies[1].aiPhase,'defense','real threshold shift')
  assert(R.endTurn(r))
  eq(s.enemies[1].statuses.sharp_hide,3,'real Defensive Mode action')
  eq(C.intent(s,1).id,'guardian_6','real Roll Attack next')
  s.hand={};s.draw={};s.discard={};s.exhaust={};s.events={};s.energy=20
  return r,s
end
local function hits(s,kind,target,status)
  local result={}
  for i,e in ipairs(s.events) do
    if e.kind==kind and (not target or e.detail.target==target) and (not status or e.detail.status==status) then
      result[#result+1]={index=i,event=e}
    end
  end
  return result
end
for _,block in ipairs({2,3}) do
check('Guardian multi-hit HP loss and all live BFB piles, block='..block,function()
  local r,s=guardian()
  local bh=held(s,'blood_for_blood')
  local bd,bc,be=card(s,'blood_for_blood',true),card(s,'blood_for_blood'),card(s,'blood_for_blood')
  s.draw={bd};s.discard={bc};s.exhaust={be}
  play(r,held(s,'bloodletting'))
  eq(s.player.damagedThisCombat,1,'prior self-payment')
  s.player.block=block;s.events={}
  play(r,held(s,'twin_strike'))
  local lost=block==2 and 1 or 0
  eq(s.player.hp,77-lost,'only residual Sharp Hide loses HP')
  eq(s.player.damagedThisCombat,1+lost,'per-use, not per-hit, notification')
  eq(C.cardDefinition(s,bh).cost,3-lost,'hand discount')
  eq(C.cardDefinition(s,bd).cost,2-lost,'upgraded draw discount')
  eq(C.cardDefinition(s,bc).cost,3-lost,'discard discount')
  eq(C.cardDefinition(s,be).cost,4,'exhaust exclusion')
  eq(#hits(s,'damage',s.enemies[1].id),2,'two attack hits')
  local sharp=hits(s,'status_damage','player','sharp_hide');eq(#sharp,1,'one onUseCard reaction')
  eq(sharp[1].event.detail.amount,lost,'reaction event HP amount')
  eq(sharp[1].event.detail.blocked,block,'reaction event absorbed block')
  eq(s.player.block,0,'block consumed exactly once')
end)
end
check('Rupture distinguishes one Hemokinesis payment from subsequent Sharp Hide',function()
  local r,s=guardian()
  play(r,held(s,'rupture',true))
  local b=held(s,'blood_for_blood');s.events={}
  local before=s.enemies[1].hp
  play(r,held(s,'hemokinesis'))
  eq(s.player.hp,75,'two self HP plus three enemy reaction HP')
  eq(s.player.damagedThisCombat,2,'two separately attributable loss events')
  eq(s.player.statuses.strength,2,'Rupture triggers on self payment only')
  eq(C.cardDefinition(s,b).cost,2,'BFB sees both causes')
  eq(s.enemies[1].hp,before-15,'precomputed attack excludes later Rupture gain')
  local loss=hits(s,'hp_loss','player')[1]
  local gain=hits(s,'status','player','strength')[1]
  local attack=hits(s,'damage',s.enemies[1].id)[1]
  local sharp=hits(s,'status_damage','player','sharp_hide')[1]
  assert(loss.index<gain.index and gain.index<attack.index and attack.index<sharp.index,'payment, Rupture, attack, Sharp Hide order')
end)
check('Pommel Strike draw before Sharp Hide updates newly drawn BFB before disposal',function()
  local r,s=guardian();local b=card(s,'blood_for_blood');s.draw={b}
  local attack=held(s,'pommel_strike');play(r,attack)
  eq(s.hand[1],b,'real draw transfers identity')
  eq(C.cardDefinition(s,b).cost,3,'drawn card sees later reaction')
  eq(s.player.damagedThisCombat,1,'one reaction event')
  eq(s.discard[#s.discard],attack,'physical attack disposed only after reaction')
  local sharp=hits(s,'status_damage','player','sharp_hide')[1]
  eq(sharp.event.frame.hand[1].uid,b.uid,'draw already happened in reaction frame')
  eq(sharp.event.frame.hand[1].costReduction,1,'reaction event includes notified card state')
end)
check('Lethal Sharp Hide cancels drawn Wound Fire Breathing tail and Double Tap repeat',function()
  local r,s=guardian()
  play(r,held(s,'fire_breathing'));play(r,held(s,'double_tap'))
  s.player.hp=3;s.draw={card(s,'wound')};s.events={}
  local attack=held(s,'pommel_strike');local before=s.enemies[1].hp
  play(r,attack)
  eq(r.phase,'defeat','Run commits defeat')
  eq(r.hp,0,'Run commits HP')
  eq(r.rewards,nil,'no reward transaction')
  eq(s.enemies[1].hp,before-9,'neither Fire Breathing nor duplicate attack resolves')
  eq(#hits(s,'play'),1,'queued repeated card never starts')
  eq(s.hand[1].cardId,'wound','draw occurred before lethal reaction')
  eq(s.cardInUse,attack,'lethal card remains limbo')
  for _,v in ipairs(s.discard) do assert(v~=attack,'lethal card must not discard') end
  eq(#s.exhaust,0,'no exhaust destination')
  eq(s.player.damagedThisCombat,1,'lethal HP loss still notifies')
end)
check('Nonlethal Double Tap sends two Sharp Hide notifications and disposes once',function()
  local r,s=guardian();play(r,held(s,'double_tap'))
  local b=held(s,'blood_for_blood');local attack=held(s,'twin_strike');s.events={}
  local before=s.enemies[1].hp;play(r,attack)
  eq(s.enemies[1].hp,before-20,'four attack hits')
  eq(s.player.hp,74,'one Sharp Hide per card use')
  eq(s.player.damagedThisCombat,2,'two onUseCard notifications')
  eq(C.cardDefinition(s,b).cost,2,'BFB sees both reactions')
  eq(#hits(s,'status_damage','player','sharp_hide'),2,'two reactive actions')
  local n=0;for _,v in ipairs(s.discard) do if v==attack then n=n+1 end end
  eq(n,1,'one physical discard')
  eq(s.cardInUse,nil,'nonlethal play settled')
end)
check('Sharp Hide death after final Guardian kill overrides victory and stops Run rewards',function()
  local r,s=guardian()
  -- Boundary setup: preserve real Guardian AI, status, action and Run path.
  s.enemies[1].hp=6;s.player.hp=3
  local b=held(s,'blood_for_blood');local attack=held(s,'strike');s.events={}
  play(r,attack)
  eq(s.enemies[1].hp,0,'last enemy died first')
  eq(s.player.hp,0,'owner-dead Sharp Hide still deals damage')
  eq(s.player.damagedThisCombat,1,'last damage still notifies')
  eq(C.cardDefinition(s,b).cost,3,'last damage reduces held BFB')
  eq(s.cardInUse,attack,'lethal reaction prevents disposal')
  eq(r.phase,'defeat','defeat has precedence')
  eq(r.rewards,nil,'no posthumous boss rewards')
  eq(r.victories,0,'no victory credited')
  eq(#hits(s,'victory'),0,'no earlier victory event')
end)
print('RESULT '..tests..' cases, '..failed..' failed; native Lua only, not platform acceptance.')
assert(failed==0,'reactive order boundary failure')
