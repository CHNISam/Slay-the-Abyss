package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local E=dofile(EFFECTS_SOURCE)
local A=require('abyss_card_actions')
local original=A.supports
local function eq(a,b,label) assert(a==b,'[EFFECTS_SUPPORTED] '..label..': '..tostring(a)..' ~= '..tostring(b)) end
local function graph(value,seen)
 local t=type(value)
 if t=='function' then return 'function' end
 if t~='table' then return t..':'..tostring(value) end
 seen=seen or {n=0};if seen[value] then return 'ref:'..seen[value] end
 seen.n=seen.n+1;seen[value]=seen.n
 local keys={};for key in pairs(value) do keys[#keys+1]=key end
 table.sort(keys,function(a,b) return type(a)..tostring(a)<type(b)..tostring(b) end)
 local rows={};for _,key in ipairs(keys) do rows[#rows+1]=graph(key,seen)..'='..graph(rawget(value,key),seen) end
 if getmetatable(value) then rows[#rows+1]='meta='..graph(getmetatable(value),seen) end
 return '{'..table.concat(rows,';')..'}'
end
local calls,reads={},{}
local function check(label,input,ok,reason,custom)
 calls,reads={},{}
 A.supports=function(op) calls[#calls+1]=op; if custom then return custom(op,#calls) end;return original(op) end
 local envelope={input=input};local before=graph(envelope)
 math.randomseed(771);local expectedRandom=math.random();math.randomseed(771)
 local result=table.pack(pcall(E.supported,input))
 eq(math.random(),expectedRandom,label..' real Lua RNG unchanged')
 eq(graph(envelope),before,label..' full graph/alias/metatable/RNG immutable')
 eq(result[1],true,label..' no unexpected exception')
 eq(result[2],ok,label..' bool');eq(result[3],reason,label..' reason')
 eq(result.n,ok and 2 or 3,label..' return arity')
 print(label..'|'..graph(result)..'|'..graph(calls)..'|'..graph(reads)..'|'..before)
 return result
end
check('nil',nil,false,'invalid_effect')
for _,v in ipairs({false,17,'x',{}, {op='damage'}, {[2]={op='damage'}}, {[0]={op='damage'}}, {[1.5]={op='damage'}}, {[1]={op='damage'},x=true}, {false}, {{op=12}}, {{op=''}}}) do
 check('invalid '..graph(v),v,false,type(v)=='table' and v[1] and type(v[1])=='table' and v[1].op=='' and '' or 'invalid_effect')
end
check('basic',{{op='damage'},{op='block',fixed=true,target='all_allies'},{op='draw'}},true)
check('scry later defeats early bad entry',{false,{op='scry',value=0}},false,'unsupported_scry_sequence')
check('scry whitelist',{{op='energy'},{op='scry',value=0}},false,'unsupported_scry_sequence')
for _,op in ipairs({'scry','gainMantra','gainDevotion','requestDiscard'}) do
 for _,value in ipairs({-1,0,1,10,11,2147483647,2147483648,0.5,'1',false}) do
  local valid=type(value)=='number' and value%1==0 and value>=0 and value<=(op=='requestDiscard' and 10 or 2147483647)
  check(op..' '..tostring(value),{{op=op,value=value}},valid,not valid and (op=='requestDiscard' and 'discard_must_end_card' or op=='scry' and 'invalid_scry_amount' or 'invalid_mantra_amount') or nil)
 end
end
local function conditional(kind,body,extra)
 local c={op='conditional',['if']=kind,['then']=body};for k,v in pairs(extra or {}) do c[k]=v end;return c
end
check('conditional alone',{conditional('target_vulnerable',{{op='draw'}})},false,'conditional')
check('damageAll no target preflight',{{op='damageAll'},conditional('target_vulnerable',{{op='draw'}})},false,'conditional')
for _,kind in ipairs({'target_vulnerable','target_poison'}) do
 check(kind..' legal',{{op='damage'},conditional(kind,{{op='energy'},{op='draw'}})},true)
 check(kind..' damage',{{op='damage'},conditional(kind,{{op='damage'}})},kind=='target_poison',kind~='target_poison' and 'damage' or nil)
 check(kind..' nested',{{op='damage'},conditional(kind,{{op='damage'},conditional(kind,{{op='draw'}})})},false,kind=='target_poison' and 'conditional' or 'damage')
end
check('else',{{op='damage'},conditional('target_poison',{{op='draw'}},{['else']={}})},false,'conditional')
check('conditional metadata fixed',{{op='damage'},conditional('target_poison',{{op='draw'}},{fixed=true,target='bad'})},false,'invalid_fixed_block')
check('conditional metadata target',{{op='damage'},conditional('target_poison',{{op='draw'}},{target='bad'})},false,'invalid_effect_target')
check('fixed before target',{{op='block',fixed=1,target='bad'}},false,'invalid_fixed_block')
check('defect before metadata',{{op='defectFinal',fixed=1,target='bad'}},false,'invalid_defect_final')
local poison={};local errorObject={sentinel='getter'}
local function watched(fields,key,value,throws)
 return setmetatable(fields,{__index=function(_,k) reads[#reads+1]=k;if k==key then if throws then error(errorObject) end;return value end end})
end
check('discard rejects before value',{watched({op='requestDiscard'},'value',nil,true),{op='draw'}},false,'discard_must_end_card');eq(#reads,1,'only targetGroup reads, no value read');for _,key in ipairs(reads) do eq(key,'targetGroup','no amount getter') end
check('dynamic second false',{{op='custom',fixed=true}},false,'invalid_fixed_block',function(_,n) return n==1 end);eq(#calls,2,'two dynamic calls')
check('dynamic accepted',{{op='custom',fixed=true}},true,nil,function() return true end);eq(#calls,2,'two dynamic successful calls')
local n=0
local changing=setmetatable({op='scry'},{__index=function(_,key)
 reads[#reads+1]=key
 if key=='value' then n=n+1;return n==1 and 0 or -1 end
end})
check('repeated amount reads',{changing},false,'invalid_scry_amount');eq(n,3,'value must be read three times before negative check')
local changingIf=setmetatable({op='conditional',['then']={{op='damage'}}},{__index=function(_,key)
 reads[#reads+1]=key
 if key=='if' then n=n+1;return n<3 and 'target_poison' or 'target_vulnerable' end
end})
n=0;check('conditional re-reads branch',{{op='damage'},changingIf},false,'damage');eq(n,3,'if read twice in guard then again for recursion')
local shared={op='draw'};check('alias',{{op='damage'},conditional('target_poison',{shared,shared})},true)
local hole={[2]={op='applyStatusAll',targetGroup='weak_then_vulnerable'}};check('marked hole',hole,false,'invalid_target_group')
check('marker beats bad op',{{op=false},{op='applyStatusAll',targetGroup='bad'}},false,'invalid_target_group')
poison.self=poison;poison.targetGroup='bad';check('marked cycle',{poison},false,'invalid_target_group')
local key={targetGroup='bad'};check('marked key',{[key]=false},false,'invalid_target_group')
local grouped={{op='applyStatusAll',status='weak',value=1,targetGroup='weak_then_vulnerable'},{op='applyStatusAll',status='vulnerable',value=1,targetGroup='weak_then_vulnerable'}}
check('valid target group',grouped,true)
-- A thrown table must retain identity, and no validator may swallow it.
reads={};A.supports=original
local throwing=watched({op='scry'},'value',nil,true)
local before=graph(throwing);local r=table.pack(pcall(E.supported,{throwing}));eq(r[1],false,'getter error');eq(r[2],errorObject,'table error identity');eq(r.n,2,'error arity');eq(graph(throwing),before,'throw input unchanged');print('error identity|'..graph(r)..'|'..graph(reads))
print('EFFECTS_SUPPORTED_PASS')

