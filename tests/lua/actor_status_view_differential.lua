package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_actor')
local C=require('abyss_combat')
assert(C.statusView==A.statusView,'[STATUS_VIEW] Combat alias')
local function serialize(v,seen)
 if type(v)~='table'then return type(v)..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=serialize(k,seen)..'='..serialize(v[k],seen)end
 return '{'..table.concat(rows,';')..'}'
end
local trace={}
local originalRequire=require
local facts={strength={canGoNegative=false,isTurnBased=false,sourceAmount=-1},dexterity={canGoNegative=true,isTurnBased=true,sourceAmount=0}}
local silent,colorless
require=function(name)
 if name=='abyss_power_order'then trace[#trace+1]='require:power';return {sourceFacts=facts}end
 if name=='abyss_colorless_cards'then trace[#trace+1]='require:colorless';return {
  powerIcon=function(id)trace[#trace+1]='icon:'..id;return 'icon:'..id end,
  powerDescription=function(_,id)trace[#trace+1]='colorless:'..id;return colorless end}end
 if name=='abyss_silent_final_cards'then trace[#trace+1]='require:silent';return {
  powerDescription=function(_,id)trace[#trace+1]='silent:'..id;return silent end}end
 return originalRequire(name)
end
local ids={'strength','dexterity','focus','slow','time_warp','invincible','nemesis_intangible','mode_shift','plain'}
local defs={};for _,id in ipairs(ids)do defs[id]={name='name:'..id,kind='definition',stack='intensity',decay='none',description='description:'..id}end
local count=0
local function check(actor,label)
 count=count+1;trace={}
 local input={actor=actor,definitions=defs,event={actor=actor,powerOrder=actor.powerOrder},rng={state=27},queue={}}
 input.alias=actor.statuses;input.self=input
 local originals={}
 local function remember(value)
  if type(value)~='table' or originals[value]then return end
  local fields={};originals[value]={fields=fields,metatable=getmetatable(value)}
  for key,item in pairs(value)do fields[key]=item;remember(key);remember(item)end
 end
 remember(input)
 local function unchanged()
  for object,record in pairs(originals)do
   assert(getmetatable(object)==record.metatable,'[STATUS_VIEW] metatable identity')
   for key,item in pairs(record.fields)do assert(object[key]==item,'[STATUS_VIEW] original field identity')end
   for key in pairs(object)do assert(record.fields[key]~=nil,'[STATUS_VIEW] extra input field')end
  end
 end
 local before=serialize(input)
 local packed=table.pack(pcall(A.statusView,actor))
 local errorIdentity=false
 if not packed[1] then
  errorIdentity=packed[2]==ERROR_TOKEN
  if type(packed[2])=='string'then packed[2]=packed[2]:gsub('^.-:%d+: ','')end
 else
  assert(packed.n==2,'[STATUS_VIEW] return arity')
  local first=packed[2]
  local again=A.statusView(actor)
  assert(first~=again,'[STATUS_VIEW] fresh array')
  for i,row in ipairs(first)do assert(row~=again[i],'[STATUS_VIEW] fresh row')end
  if first[1]then first[1].amount=999;first[1].name='mutated';first[1].decay='mutated'end
  assert(before==serialize(input),'[STATUS_VIEW] readonly object graph')
  packed[2]=again
 end
 unchanged()
 assert(before==serialize(input),'[STATUS_VIEW] readonly failure graph')
 print('STATUS_BOUNDARY '..label..' '..serialize({result=packed,input=input,trace=trace,errorIdentity=errorIdentity}))
end
local function actor(monster)
 return {definitionId=monster,statuses={},statusDefinitions=defs,powerOrder={},temporaryStrength=0,temporaryDexterity=0}
end
for _,monster in ipairs({false,true,''})do
 for _,amount in ipairs({-2,0,3})do
  for _,temporary in ipairs({0,2,-1})do
   local a=actor(monster);a.temporaryStrength=temporary;a.temporaryDexterity=temporary
   for _,id in ipairs(ids)do a.statuses[id]=amount end
   a.powerOrder={'plain','strength','dexterity','focus','slow','time_warp','invincible','nemesis_intangible','mode_shift','strength','absent'}
   check(a,'selection:'..tostring(monster)..':'..amount..':'..temporary)
  end
 end
end
for _,id in ipairs(ids)do
 for _,amount in ipairs({-1,0,1})do
  local a=actor(true);a.statuses[id]=amount;check(a,'missing-order:'..id..':'..amount)
 end
end
for _,s in ipairs({false,'','silent'})do
 for _,c in ipairs({false,'','colorless'})do
  silent=s;colorless=c
  local a=actor(true);a.statuses={strength=-1};a.powerOrder={'strength'};check(a,'description:'..tostring(s)..':'..tostring(c))
 end
end
silent=nil;colorless=nil
for _,role in ipairs({'HT','AR','FR','RD','unknown'})do
 for _,value in ipairs({-1,0,1})do
  for _,cap in ipairs({false,0,-2,19})do
   for _,ends in ipairs({-1,0,2})do
    local a=actor(false)
    a.originalV4={role=role,infuse=value,chargedUsed=1,bond=value,mode=value==1 and 'ousia' or '',fan=value,fanGained=2,
      resolve=value,resolveGained=1,eye={uses=value,ends=ends},musou={uses=value,ends=ends},musouRefunded=0,healUsed=value,healCap=cap}
    a.v4Bloom={strength=value,ticks=ends};a.v4Directive={mature=value==1}
    check(a,'v4:'..role..':'..value..':'..tostring(cap)..':'..ends)
   end
  end
 end
end
for _,role in ipairs({'HT','RD'})do
 local a=actor(false);a.originalV4={role=role};check(a,'malformed:'..role)
end
local a=actor(false);a.definitionId=nil;a.statuses={focus=0,strength=0};check(a,'nil-definition-id')
for _,eye in ipairs({0,1})do for _,musou in ipairs({0,1})do
 a=actor(false);a.originalV4={role='RD',resolve=0,resolveGained=0,eye={uses=eye,ends=1},musou={uses=musou,ends=1},musouRefunded=0,healUsed=0}
 check(a,'independent-RD:'..eye..':'..musou)
end end
a=actor(false);a.statuses={plain=1};a.statusDefinitions={};check(a,'unknown-definition')
ERROR_TOKEN={identity='error-object'}
a.statusDefinitions=setmetatable({},{__index=function()error(ERROR_TOKEN)end});check(a,'error-identity')
print('STATUS_VIEW_PASS '..count)
