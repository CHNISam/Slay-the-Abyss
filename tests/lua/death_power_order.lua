-- Same-priority source death hooks share the owning native/advanced queue.
-- Controlled actors isolate order; these are not natural campaign/live checks.
local C,A,Q,D=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions'),require('abyss_data')
local AP,SF=require('abyss_act2_powers'),require('abyss_silent_final_cards')
local Run=require('abyss_run')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function fixture(mode,order,lethal)
 local data=C.copy(D);data.statuses=SF.withCardDefinitions(D).statuses
 local s=C.new(data,{enemies={'bronze_orb','cultist'},deck={'strike'},seed=42,enableStances=mode=='advanced'})
 eq(s.experimentalMechanics==true,mode=='advanced','actual dispatcher')
 local orb=s.enemies[1];orb.hp=1;orb.block=0;s.enemies[2].hp=lethal and 1 or 1000
 s.draw={{uid=901,cardId='defend',upgraded=false,damageBonus=3}}
 if order=='corpse-first'then A.applyPower(s,orb,'corpse_explosion',1,s.player)end
 C.applyEffects(s,{{op='enemyStasis',value=1}},orb,s.player)
 if order=='stasis-first'then A.applyPower(s,orb,'corpse_explosion',1,s.player)end
 eq(table.concat(orb.powerOrder,','),order=='stasis-first'and 'stasis,corpse_explosion'or 'corpse_explosion,stasis')
 return s,orb,assert(s.act2StasisCards[orb.id]),s.hand[1]
end
local function trace(s,fn)
 local out={};local oldAP,oldSF=AP.apply,SF.apply
 AP.apply=function(api,state,effect,...)
  if state==s and effect.op=='stasis_return'then out[#out+1]='S' end
  return oldAP(api,state,effect,...)
 end
 SF.apply=function(api,state,item,...)
  if state==s and item.effect.kind=='corpseDamage'then out[#out+1]='C' end
  return oldSF(api,state,item,...)
 end
 local ok,why=pcall(fn);AP.apply,SF.apply=oldAP,oldSF;assert(ok,why)
 return table.concat(out,',')
end
for _,mode in ipairs({'native','advanced'})do
 for _,order in ipairs({'stasis-first','corpse-first'})do
  for _,lethal in ipairs({false,true})do
   test(mode..' '..order..' '..(lethal and 'lethal'or 'nonlethal')..' actual Strike preserves death hook order',function()
    local s,orb,held,strike=fixture(mode,order,lethal)
    local expected=order=='stasis-first'and 'S,C'or lethal and 'C'or 'C,S'
    eq(trace(s,function()assert(C.play(s,strike.uid,1))end),expected)
    local returned
    for _,c in ipairs(s.hand)do if c.uid==held.uid then returned=c end end
    if order=='stasis-first'or not lethal then
     assert(returned,'Stasis card must return before following source actions')
     eq(returned.cardId,held.cardId);eq(returned.damageBonus,3);eq(s.act2StasisCards[orb.id],nil)
    else eq(returned,nil,'victory clears later Stasis action')end
    eq(C.outcome(s),lethal and 'victory'or nil);eq(s.actionQueue,nil);eq(s.cardActions,nil)
   end)
  end
 end
 test(mode..' late Stasis return failure restores original actors custody power history and retry order',function()
  local s,orb,held,strike=fixture(mode,'stasis-first',false)
  local before=C.copy(s);local hand,draw,custody,history=s.hand,s.draw,s.act2StasisCards,orb.powerOrder
  local old=AP.apply
  AP.apply=function(api,state,effect,...)
   local result=old(api,state,effect,...)
   if state==s and effect.op=='stasis_return'then error('death hook late fault')end
   return result
  end
  local ok=pcall(C.play,s,strike.uid,1);AP.apply=old;eq(ok,false)
  same(s,before);eq(s.hand,hand);eq(s.draw,draw);eq(s.act2StasisCards,custody)
  eq(s.enemies[1],orb);eq(s.act2StasisCards[orb.id],held);eq(orb.powerOrder,history)
  eq(trace(s,function()assert(C.play(s,strike.uid,1))end),'S,C')
 end)
end
test('public Run command preserves same death order and permanent-owner transaction',function()
 local run=Run.new(D,'42');local s,orb,held,strike=fixture('advanced','stasis-first',true)
 run.phase,run.combat='combat',s;run.combatGeneration=1;s.combatGeneration=1
 run.encounterTier,run.encounterId,run.encounterSource='normal','test_bronze_pair','explicit'
 -- Public Run owns the entire graph and reward construction on victory.
 local ok,why=Run.play(run,strike.uid,1);assert(ok,why)
 eq(run.phase,'reward');local returned
 for _,c in ipairs(run.combat.hand)do if c.uid==held.uid then returned=c end end
 assert(returned);eq(run.combat.act2StasisCards[orb.id],nil)
end)
print('DEATH_POWER_ORDER '..count..' groups; '..failed..' failed')
assert(failed==0,'death power order regression')
