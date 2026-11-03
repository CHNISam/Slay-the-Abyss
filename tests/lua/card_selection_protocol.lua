package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A=require('abyss_combat'),require('abyss_card_actions')
local Data=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,'[SELECTION_CONTRACT] '..label..': '..tostring(a)..' ~= '..tostring(b))end
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
for _,name in ipairs({'apply','applyChoice','choose','enqueue'})do
 local old=A[name]
 A[name]=function(...)
  local args=table.pack(...);local result=table.pack(old(...))
  if ABYSS_SELECTION_TRACE then print('SELECTION_TRACE '..name..' '..serialize({state=args[name=='enqueue'and 1 or 2],result=result}))end
  return table.unpack(result,1,result.n)
 end
end
local function battle()
 local s=C.new(Data,{seed=42,deck={'strike'},enemies={'cultist'},cardRandomSeed='42'})
 s.hand={{uid=101,cardId='strike'},{uid=102,cardId='defend'},{uid=103,cardId='bash'}}
 s.draw={};s.discard={};s.exhaust={};s.cardActions=nil
 return s
end
local function begin(s,op,value)A.apply(C,s,{effect={op=op,value=value},source=s.player})end
local function choose(s,uid)return A.choose(C,s,s.pendingChoice.token,uid)end
local function test(name,fn)fn();count=count+1;print('ok selection '..count..' '..name)end
test('multi recovery exact count, toggle tokens and selected order',function()
 local s=battle();s.discard=s.hand;s.hand={};local first,second,third=table.unpack(s.discard)
 begin(s,'discardToHand',2);local p=s.pendingChoice;eq(p.required,2,'required')
 assert(choose(s,third.uid));local token=p.token
 local ok,why=A.choose(C,s,token-1,second.uid);eq(ok,false,'old token');eq(why,'stale_card_choice','old token reason')
 ok,why=choose(s,0);eq(ok,false,'underfilled');eq(why,'invalid_card_choice','underfilled reason')
 assert(choose(s,third.uid));eq(#p.selected,0,'toggle removes')
 assert(choose(s,third.uid));assert(choose(s,first.uid))
 ok,why=choose(s,second.uid);eq(ok,false,'overfilled');eq(why,'invalid_card_choice','overfilled reason')
 assert(choose(s,0));eq(s.hand[1],third,'first selected identity');eq(s.hand[2],first,'second selected identity')
 eq(s.discard[1],second,'unselected retained');eq(third.costForTurn,0,'recovery cost');eq(s.cardRandomRng.counter,0,'no RNG')
end)
test('multi discard commit and exhaust preserve ordered original identities',function()
 for _,op in ipairs({'discardRedraw','exhaustMany'})do
  local s=battle();local first,_,third=table.unpack(s.hand)
  if op=='discardRedraw'then s.draw={{uid=201,cardId='defend'},{uid=202,cardId='strike'}}end
  begin(s,op,1);assert(choose(s,third.uid));assert(choose(s,first.uid));assert(choose(s,0))
  local pile=op=='exhaustMany'and s.exhaust or s.discard
  eq(pile[1],third,'ordered first');eq(pile[2],first,'ordered second')
  if op=='discardRedraw'then eq(#s.hand,3,'draw selected count');eq(s.hand[2].uid,202,'draw top first')end
 end
end)
test('live eligibility rejects stale single and multiple candidates before commit',function()
 local s=battle();begin(s,'dualWield',1);local p=s.pendingChoice
 local ok,why=choose(s,102);eq(ok,false,'excluded skill');eq(why,'invalid_card_choice','excluded reason')
 s.hand[1].cardId='defend';ok,why=choose(s,101);eq(ok,false,'now ineligible');eq(why,'stale_card_choice','stale single reason');eq(s.pendingChoice,p,'pending identity')
 s=battle();begin(s,'exhaustMany',1);assert(choose(s,101));p=s.pendingChoice
 table.remove(s.hand,1);ok,why=choose(s,0);eq(ok,false,'stale selected');eq(why,'stale_card_choice','stale multi reason');eq(s.pendingChoice,p,'selected owner retained')
end)
test('singleton and manual dual wield retain distinct source replacement rules',function()
 for _,manual in ipairs({false,true})do
  local s=battle();local original=s.hand[1]
  if not manual then s.hand={original}else table.insert(s.hand,1,{uid=104,cardId='defend'})end
  begin(s,'dualWield',1)
  if manual then assert(choose(s,original.uid));eq(s.hand[1].uid,103,'eligible returned before skills');eq(s.hand[2].uid,104,'other order retained')
  else eq(s.hand[1],original,'singleton retains source')end
  local copies=0;for _,v in ipairs(s.hand)do if v.cardId=='strike'and v~=original then copies=copies+1 end end
  eq(copies,manual and 2 or 1,'copy count');eq(original.cardId,'strike','original unchanged')
 end
end)
test('pile choices, zero/full recovery and unsupported operations retain boundaries',function()
 for _,op in ipairs({'recoverExhaust','discardToDraw','handToDraw','exhaustChoose','upgradeHand'})do
  local s=battle();local card=s.hand[1];s.hand={card}
  if op=='recoverExhaust'then s.exhaust={card,{uid=105,cardId='exhume'}};s.hand={}
  elseif op=='discardToDraw'then s.discard={card};s.hand={}end
  begin(s,op,1);eq(s.pendingChoice,nil,'singleton immediate')
  if op=='recoverExhaust'then eq(s.hand[1],card,'recover original');eq(#s.exhaust,1,'exhume excluded')
  elseif op=='upgradeHand'then eq(card.upgraded,true,'upgrade original')
  elseif op=='exhaustChoose'then eq(s.exhaust[1],card,'exhaust original')
  else eq(s.draw[#s.draw],card,'draw original')end
 end
 local s=battle();s.discard={{uid=201,cardId='strike'}};begin(s,'discardToHand',0);eq(s.pendingChoice,nil,'zero no selection')
 s.rules.player.maxHand=#s.hand;local events=#s.events
 A.applyChoice(C,s,{effect={op='discardToHand'}},201);eq(#s.events,events,'full hand no resolved event');eq(#s.discard,1,'full hand source retained')
 local ok,why=pcall(A.applyChoice,C,s,{effect={op='unsupported'}},101);eq(ok,false,'unsupported fails');assert(tostring(why):find('invalid choice operation',1,true))
end)
test('public chooseCard restores complete original graph after late multi-exhaust failure',function()
 local s=battle();begin(s,'exhaustMany',1);assert(choose(s,101));assert(choose(s,103))
 local saved={};local function capture(t)
  if type(t)~='table'or saved[t]then return end
  local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;capture(k);capture(v)end
 end
 capture(s);local old=C.cardDefinition
 C.cardDefinition=function(state,card)if #state.exhaust>0 then error('late_selection_failure',0)end;return old(state,card)end
 local ok,why=pcall(C.chooseCard,s,s.pendingChoice.token,0);C.cardDefinition=old
 eq(ok,false,'failure thrown');eq(why,'late_selection_failure','same exception')
 for original,values in pairs(saved)do
  for k,v in pairs(values)do eq(original[k],v,'restored original '..tostring(k))end
  for k,v in pairs(original)do eq(v,values[k],'no inserted key '..tostring(k))end
 end
 assert(C.chooseCard(s,s.pendingChoice.token,0));eq(#s.exhaust,2,'retry same choice')
end)
print('CARD_SELECTION_PROTOCOL_PASS '..count)
