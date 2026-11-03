package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Q,D=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions'),require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,'[ACTOR_DAMAGE] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function serialize(v,seen)
 if type(v)=='function'then return 'function'end
 if type(v)~='table'then return type(v)..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do if k~='catalog'and k~='rules'and k~='sourcePools'and k~='statusDefinitions'then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=serialize(k,seen)..'='..serialize(v[k],seen)end
 return '{'..table.concat(rows,';')..'}'
end
for _,name in ipairs({'damage','retaliate','resolveDamageReactions'})do
 local old=A[name]
 A[name]=function(...)
  local args=table.pack(...);local result=table.pack(old(...))
  if ABYSS_ACTOR_DAMAGE_TRACE then print('ACTOR_TRACE '..name..' '..serialize({args=args,result=result}))end
  return table.unpack(result,1,result.n)
 end
end
local function battle(enemies)
 local s=C.new(D,{seed=42,cardRandomSeed='42',enemies=enemies or {'cultist'},deck={'strike','defend'}})
 s.events={};return s,s.enemies[1]
end
local function test(name,fn)fn();count=count+1;print('ok actor damage '..count..' '..name)end
test('fixed and normal damage preserve Intangible block and Boot ordering',function()
 for _,fixed in ipairs({false,true})do for _,base in ipairs({0,1,5,9})do
  for _,block in ipairs({0,3})do for _,intangible in ipairs({false,true})do
   local s,e=battle();e.hp=50;e.block=block;s.relics={'boot'}
   if intangible then e.statuses.intangible=1 end
   local amount=intangible and math.min(base,1)or base
   local absorbed=math.min(block,amount);local expected=amount-absorbed
   if not fixed and expected>0 and expected<5 then expected=5 end
   eq(A.damage(s,s.player,e,base,fixed),expected,'integer damage')
   eq(e.block,block-absorbed,'block consumed');eq(e.hp,50-expected,'HP lost')
   eq(s.cardRandomRng.counter,0,'no card RNG');eq(s.events[1].detail.blocked,absorbed,'damage frame absorption')
  end end
 end end
end)
test('normal snapshots keep finite integer bound and bypass modifiers before final Intangible',function()
 for _,value in ipairs({-1,1.5,math.huge,0/0,9007199254740992.0,'1'})do
  local s,e=battle();local ok,why=pcall(A.damage,s,s.player,e,1,false,{},value)
  eq(ok,false,'invalid snapshot');assert(tostring(why):find('invalid normal damage snapshot',1,true))
  eq(#s.events,0,'invalid snapshot no events')
 end
 for _,value in ipairs({0,1,9007199254740991.0})do
  local s,e=battle();e.hp=50;e.statuses.intangible=1;s.player.statuses.strength=9
  eq(A.damage(s,s.player,e,99,false,{},value),math.min(value,1),'snapshot exact then Intangible')
 end
 local s,e=battle();local ok=pcall(A.damage,s,s.player,e,1,true,{},1);eq(ok,false,'fixed snapshot refused')
 e.hp=0;eq(A.damage(s,s.player,e,1,false,{},-1),0,'inactive target short circuit')
 e.hp=20;s.player.hp=0;eq(A.damage(s,s.player,e,1,false,{},-1),0,'inactive owner short circuit')
end)
test('Buffer Torii and Tungsten keep distinct normal and fixed last-loss stages',function()
 for _,fixed in ipairs({false,true})do for _,buffer in ipairs({false,true})do
  for _,amount in ipairs({0,1,5,6})do
   local s,e=battle();s.relics={'torii','tungsten_rod'}
   if buffer then s.player.statuses.buffer=1 end
   local expected=amount
   if buffer then expected=0 elseif not fixed and amount>1 and amount<=5 then expected=1 end
   expected=math.max(0,expected-1)
   eq(A.damage(s,e,s.player,amount,fixed),expected,'incoming pipeline')
   eq(s.player.statuses.buffer,buffer and amount==0 and 1 or nil,'Buffer only consumed on positive loss')
  end
 end end
end)
test('shared area retains owner reaction identity and reverse TOP before Curl FIFO',function()
 local s=battle({'cultist','cultist'});local a,b=s.enemies[1],s.enemies[2]
 a.hp,a.block,b.hp,b.block=2,0,20,0
 A.applyPower(s,a,'thorns',2,a);A.applyPower(s,a,'spore_cloud',1,a)
 A.applyPower(s,b,'thorns',3,b);A.applyPower(s,b,'angry',1,b);A.applyPower(s,b,'curl_up',4,b)
 local reactions={};local first={source=s.player,target=a,status='poison',amount=1}
 local second={source=s.player,target=b,status='poison',amount=1};s.events={};s.resolvingEffects=true
 eq(A.damage(s,s.player,a,3,false,reactions,nil,first),2,'first actual HP')
 eq(reactions[1],first,'owner action reference')
 eq(A.damage(s,s.player,b,3,false,reactions,nil,second),3,'second HP')
 local found=false;for _,v in ipairs(reactions)do if v==second then found=true end end;eq(found,true,'second owner reference')
 eq(s.player.hp,80,'retaliation deferred');eq(b.block,0,'Curl not inline');eq(b.curlUpTriggered,true,'Curl locked before queue')
 s.resolvingEffects=nil;A.resolveDamageReactions(s,reactions);Q.drain(C,s)
 eq(s.player.hp,75,'both Thorns survive');eq(b.block,4,'Curl BOTTOM');eq(b.statuses.angry,1,'Angry original retained');eq(b.statuses.strength,1,'Angry action')
 local damage={};for _,ev in ipairs(s.events)do if ev.kind=='damage'or ev.kind=='status_damage'then damage[#damage+1]=ev.detail end end
 eq(damage[1].target,a.id,'first target');eq(damage[2].target,b.id,'second target')
 eq(damage[3].source,b.id,'last target Thorns first');eq(damage[4].source,a.id,'first target Thorns last')
end)
test('public card failure restores original actors queues events and RNG graph',function()
 local s,e=battle();local playing
 for _,v in ipairs(s.hand)do if v.cardId=='strike'then playing=v end end
 s.catalog.cards.strike.effects={{op='damage',value=6},{op='applyStatus',status='strength',value=1}}
 local saved={};local function capture(t)
  if type(t)~='table'or saved[t]then return end
  local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;capture(k);capture(v)end
 end;capture(s)
 local old=A.applyPower;A.applyPower=function(state,target,id,...)
  if state==s and id=='strength'then error('late_damage_pipeline_failure',0)end
  return old(state,target,id,...)
 end
 local ok,why=pcall(C.play,s,playing.uid,1);A.applyPower=old
 eq(ok,false,'late throw');eq(why,'late_damage_pipeline_failure','same error')
 for original,values in pairs(saved)do
  for k,v in pairs(values)do eq(original[k],v,'restored original '..tostring(k))end
  for k,v in pairs(original)do eq(v,values[k],'no inserted key '..tostring(k))end
 end
 assert(C.play(s,playing.uid,1));eq(e.hp,saved[e].hp-6,'retry one hit')
end)
print('ACTOR_DAMAGE_PIPELINE_PASS '..count)
