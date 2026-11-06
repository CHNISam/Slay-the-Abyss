package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Q,R,D=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions'),require('abyss_sts_random'),require('abyss_data')
local Run=require('abyss_run')
local count=0
local function eq(a,b,label)assert(a==b,'[COMBAT_LIFECYCLE] '..label..': '..tostring(a)..' ~= '..tostring(b))end
-- Canonical full graph: no state/catalog/rules/event omissions. Reference IDs
-- include abandoned piles and the original instances retained by the caller.
local function graph(value,seen)
 local kind=type(value)
 if kind=='string'then return string.format('%q',value)end
 if kind~='table'and kind~='function'then return kind..':'..tostring(value)end
 seen=seen or {n=0}
 if seen[value]then return 'ref:'..seen[value]end
 seen.n=seen.n+1;seen[value]=seen.n
 if kind=='function'then return 'function:'..seen.n..'meta='..graph(getmetatable(value),seen)end
 local keys={};for key in next,value do
  assert(type(key)=='number'or type(key)=='string'or type(key)=='boolean','[COMBAT_LIFECYCLE] unsupported graph key')
  keys[#keys+1]=key
 end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={'table:'..seen[value]}
 for _,key in ipairs(keys)do rows[#rows+1]=graph(key,seen)..'='..graph(rawget(value,key),seen)end
 rows[#rows+1]='meta='..graph(getmetatable(value),seen)
 return '{'..table.concat(rows,';')..'}'
end
local function refs(s)
 local instances={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do
  for _,card in ipairs(pile)do instances[#instances+1]=card end
 end
 return {state=s,hand=s.hand,draw=s.draw,discard=s.discard,exhaust=s.exhaust,player=s.player,enemies=s.enemies,
  shuffle=s.shuffleRng,cardRng=s.cardRandomRng,events=s.events,instances=instances}
end
local function emit(label,value)
 if COMBAT_LIFECYCLE_TRACE then print('COMBAT_GRAPH '..label..' '..graph(value))end
end
local function invoke(root,label,fn)
 local result=table.pack(pcall(fn));if not result[1]and type(result[2])=='string'then
  result[2]=result[2]:gsub('^[^\n]-:%d+: ','')
 end
 root.result=result;emit(label,root);return table.unpack(result,1,result.n)
end
local function battle(options)
 options=options or {};options.seed=42;options.cardRandomSeed='42';options.enemies=options.enemies or {'cultist'}
 options.deck=options.deck or {'strike','defend'}
 local s=C.new(D,options);s.events={};return s,s.enemies[1]
end
local function test(name,fn)fn();count=count+1;print('ok combat lifecycle '..count..' '..name)end
local function zones(s,draw,discard)
 s.hand={};s.draw={};s.discard={};local uid=1000
 for i,ids in ipairs({draw or {},discard or {}})do
  local pile=i==1 and s.draw or s.discard
  for _,id in ipairs(ids)do uid=uid+1;pile[#pile+1]={uid=uid,cardId=id,upgraded=false}end
 end
end
if not COMBAT_LIFECYCLE_GROUP or COMBAT_LIFECYCLE_GROUP=='damage'then
 test('direct damage Envenom Heart caps fixed/snapshot and owner boundaries',function()
  for _,owner in ipairs({'standalone','effects','card','choice','shared','enemy'})do
   for _,fixed in ipairs({false,true})do
    local s,e=battle({enemies={'corrupt_heart'}});e.hp=60;e.block=2;e.statuses.invincible=3;s.player.statuses.envenom=2
    if owner=='effects'then s.resolvingEffects=true elseif owner=='card'then s.resolvingCard=true
    elseif owner=='choice'then s.pendingChoice={cards={}} elseif owner=='enemy'then
     s.phase='enemy';s.drainingCardActions=true;s.cardActions={{effect={op='enemyAction',stage='effectsComplete'}}}
    end
    local reactions=owner=='shared'and {}or nil;local root=refs(s);root.reactions=reactions
    local ok,lost=invoke(root,owner..tostring(fixed),function()return C.damage(s,s.player,e,8,fixed,reactions)end)
    eq(ok,true,'damage succeeds');eq(lost,3,'Heart capped actual');eq(e.hp,57,'actual HP')
    if fixed then eq(e.statuses.poison,nil,'fixed damage cannot Envenom')end
    if not fixed and owner=='standalone'then eq(e.statuses.poison,2,'normal Envenom settles')end
   end
  end
 end)
 test('thorns deaths curl and revival preserve direct and shared reaction order',function()
  for _,enemy in ipairs({'jaw_worm','awakened_one','darkling'})do
   local s,e=battle({enemies={enemy}});s.player.hp=4;e.hp=2;e.block=0
   A.applyPower(s,e,'thorns',3,e);A.applyPower(s,e,'curl_up',4,e)
   s.events={};local root=refs(s)
   local ok,lost=invoke(root,enemy,function()return C.damage(s,s.player,e,9,false)end)
   eq(ok,true,'lethal direct accepted');eq(lost,2,'capped HP loss')
  end
 end)
 test('V4 reduction preview and invalid snapshot error preserve original owner',function()
  local s,e=battle();s.originalV4={enemyAction={attacking=true,enemy=e,soften=2}};s.originalV4Preview={}
  local root=refs(s);eq(invoke(root,'v4-preview',function()return C.damage(s,e,s.player,8,false)end),true,'V4 incoming')
  eq(invoke(root,'v4-outgoing',function()return C.damage(s,s.player,e,8,false,nil,8)end),true,'V4 outgoing')
  eq(#s.originalV4Preview,1,'player preview only');eq(s.originalV4Preview[1].actual,8,'preview actual')
  local ok,why=invoke(root,'invalid-normal',function()return C.damage(s,s.player,e,8,false,nil,-1)end)
  eq(ok,false,'invalid snapshot throws');assert(why:find('invalid normal damage snapshot',1,true),'[COMBAT_LIFECYCLE] original error')
 end)
 test('direct damage preserves object errors, aliases and error metatables',function()
  local s,e=battle();local root=refs(s)
  local marker=setmetatable({target=e,state=s},{tag='damage-object-error'})
  local callback=function()return marker end
  marker.self=marker;marker.callback=callback;root.errorObject=marker;s.lifecycleError=marker
  root.callback=callback;s.lifecycleCallback=callback
  local damage=A.damage;A.damage=function()error(marker,0)end
  local ok,why=invoke(root,'damage-object-error',function()return C.damage(s,s.player,e,3,false)end)
  A.damage=damage;eq(ok,false,'object throws');eq(why,marker,'same thrown object');eq(root.result[2],s.lifecycleError,'error alias retained')
  A.damage=function()error(callback,0)end
  ok,why=invoke(root,'damage-function-error',function()return C.damage(s,s.player,e,3,false)end)
  A.damage=damage;eq(ok,false,'function throws');eq(why,root.callback,'same thrown function')
  eq(root.result[2],s.lifecycleCallback,'function error alias retained');eq(marker.callback,callback,'nested function alias')
 end)
end
if not COMBAT_LIFECYCLE_GROUP or COMBAT_LIFECYCLE_GROUP=='draw'then
 test('draw noDraw/full/empty/source split keeps all pile and instance identities',function()
  for _,source in ipairs({false,true})do for _,mode in ipairs({'split','empty-discard','empty','full','locked','zero','negative'})do
   local s=battle();zones(s,mode=='empty'and {}or {'defend'},mode=='empty-discard'and {}or {'strike','defend','strike'})
   if mode=='empty'then s.discard={}end
   if source then s.shuffleRng=R.fromSeed('177')end
   if mode=='full'then for i=1,s.rules.player.maxHand do s.hand[i]={cardId='defend',uid=2000+i}end end
   if mode=='locked'then s.player.noDraw=true end
   local root=refs(s);local counter=source and s.shuffleRng.counter
   local n=mode=='zero'and 0 or mode=='negative'and -1 or 4
   local ok,drawn=invoke(root,tostring(source)..mode,function()return C.draw(s,n)end)
   eq(ok,true,'draw accepted');eq(s.hand,root.hand,'hand table remains');eq(s.exhaust,root.exhaust,'exhaust table remains')
   if mode=='split'then eq(#drawn,4,'draw across piles');eq(s.draw,root.discard,'discard becomes draw');eq(drawn[1],root.draw[1]or s.hand[1],'old pile card retained')end
   if mode=='full'or mode=='locked'or mode=='zero'or mode=='negative'or mode=='empty'then
    eq(s.draw,root.draw,'untouched draw owner');eq(s.discard,root.discard,'untouched discard owner')
    if source then eq(s.shuffleRng.counter,counter,'no shuffle on blocked draw')end
   elseif source then eq(s.shuffleRng.counter,counter+1,'one source nextLong per shuffle')end
  end end
 end)
 test('Void immediate/queued and dynamic definitions preserve onDraw dispatch',function()
  for _,queued in ipairs({false,true})do
   local s=battle();zones(s,{'void'});s.energy=3
   if queued then require('abyss_action_queue').start(s,{})end
   local root=refs(s);local base,definition=C.combatBaseCost,C.cardDefinition;local calls={}
   C.combatBaseCost=function(state,card)calls[#calls+1]='base';return base(state,card)end
   C.cardDefinition=function(state,card)calls[#calls+1]='definition';return definition(state,card)end
   local ok=invoke(root,'void'..tostring(queued),function()return C.draw(s,1)end)
   C.combatBaseCost,C.cardDefinition=base,definition;root.calls=calls;emit('dynamic',root)
   eq(ok,true,'Void draw accepted');eq(calls[1],'base','dynamic base');eq(calls[2],'definition','dynamic card')
   eq(s.energy,queued and 3 or 2,'Void energy timing')
  end
 end)
end
if not COMBAT_LIFECYCLE_GROUP or COMBAT_LIFECYCLE_GROUP=='owners'then
 test('public Run potion keeps Evolve below initial draws and transactional rollback',function()
  for _,invalid in ipairs({false,true})do
   local run=Run.new(D,42);assert(Run.obtainPotion(run,'snecko_oil'));assert(Run.startCombat(run,'cultist_solo'))
   local s=run.combat;zones(s,{invalid and 'invalid_draw_fixture'or 'defend','defend','defend','defend','defend','dazed'})
   require('abyss_warrior_status_cards').applyPower(s,'evolve',1)
   local root=refs(s);root.run=run;local energy=s.energy
   local ok,result,why=invoke(root,'run-potion'..tostring(invalid),function()return Run.usePotion(run,1)end)
   eq(ok,true,'Run owns exception');eq(result,not invalid,'Run result')
   if invalid then eq(why,'potion_effect_failed','rollback error');eq(s.hand,root.hand,'rollback hand');eq(s.draw,root.draw,'rollback draw');eq(s.energy,energy,'rollback energy')
   else eq(#s.hand,6,'Evolve extra draw');eq(s.hand[6].costOverride,nil,'Evolve after RandomizeHandCost')end
  end
 end)
 test('Combat effects retain shared TOP/BOTTOM queue and standalone settlement',function()
  local s,e=battle();zones(s,{'defend','dazed'});require('abyss_warrior_status_cards').applyPower(s,'evolve',1)
  local root=refs(s)
  local ok=invoke(root,'effects-draw',function()return C.applyEffects(s,{{op='draw',value=1}},s.player,s.player)end)
  eq(ok,true,'effects return');eq(#s.hand,2,'standalone drains Evolve');eq(s.cardActions,nil,'owner queue completed')
  local s2,e2=battle();local root2=refs(s2);A.applyPower(s2,e2,'thorns',2,e2)
  eq(invoke(root2,'play',function()return C.play(s2,s2.hand[1].uid,1)end),true,'public Combat play')
 end)
 test('native Evolve stays BOTTOM behind the existing RandomizeHandCost owner',function()
  local s=battle();zones(s,{'defend','dazed'});s.hand[1]={cardId='defend',uid=1999}
  s.experimentalMechanics=false;s.player.statuses.evolve=1;s.player.powerOrder={'evolve'}
  local counter=s.cardRandomRng.counter
  local root=refs(s);Q.enqueue(s,{op='randomizeHandCost'})
  eq(invoke(root,'draw-under-card-owner',function()return C.draw(s,1)end),true,'native draw')
  eq(invoke(root,'drain-existing-owner',function()return Q.drain(C,s)end),true,'native drain')
  eq(#s.hand,3,'native Evolve draw');eq(s.hand[1].costOverride~=nil,true,'initial card randomized')
  eq(s.hand[3].costOverride,nil,'BOTTOM draw follows randomization')
  eq(s.cardRandomRng.counter,counter+1,'BOTTOM draw follows randomization RNG')
 end)
end
print('COMBAT_LIFECYCLE_PASS '..count)
