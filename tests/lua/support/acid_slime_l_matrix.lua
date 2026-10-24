package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data=require('abyss_combat'),require('abyss_data')
local function eq(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)) end
local function battle(deck) return C.new(Data,{enemies={'acid_slime_l'},deck=deck or {'defend'},seed=42}) end
local function observe(roll,boolean,unit,f)
 local old,calls=C.random,{}
 C.random=function(s,n)
  calls[#calls+1]=n;local v=old(s,n)
  if n==100 then return roll+1 elseif n==2 then return boolean and 2 or 1 elseif n==65536 then return unit+1 end
  return v
 end
 local ok,why=pcall(f,calls);C.random=old;assert(ok,why)
end
local function force(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end
 error('missing intent '..id)
end
local function primary(calls,start)
 local n=0;for i=start+1,#calls do if calls[i]==100 then n=n+1 end end;return n
end
-- Literal source oracle: low/middle/high branch; b is nextBoolean, p is nextFloat.
local cases={{nil,nil,'s','t','w'},{'s',nil,'s','t','w'},{'t',nil,'s','p','w'},{'w',nil,'s','t','w'},
 {'s','s','b','t','w'},{'s','t','s','t','w'},{'s','w','s','t','w'},
 {'t','s','s','p','w'},{'t','t','s','p','w'},{'t','w','s','p','w'},
 {'w','s','s','t','w'},{'w','t','s','t','w'},{'w','w','s','t','p'}}
local ids={s='acid_slime_l_1',t='acid_slime_l_3',w='acid_slime_l_2'}
return function(first,last)
 local checked=0
 for index=first,last do local h=cases[index]
  for roll=0,99 do for _,flag in ipairs({false,true})do
   observe(roll,flag,flag and 0 or 65535,function(calls)
    -- Five cards remain in draw: isolate enemy AI requests from Slimed shuffles.
    local deck=h[1] and {'defend','defend','defend','defend','defend','defend','defend','defend','defend','defend'} or nil
    local s=battle(deck);local e=s.enemies[1];local start=0
    if h[1]then force(e,ids[h[1]]);e.acidLast=ids[h[2]];start=#calls;assert(C.endTurn(s))else start=1 end
    local mode=h[roll<30 and 3 or(roll<70 and 4 or 5)]
    local want=mode
    if mode=='b'then want=flag and't'or'w'elseif mode=='p'then want=flag and's'or(roll<70 and'w'or't')end
    eq(C.intent(s,1).id,ids[want]);eq(primary(calls,start),1)
    eq(calls[start+1],100)
    local extra=(mode=='b'or mode=='p')and 1 or 0
    eq(#calls-start,1+extra)
    if extra==1 then eq(calls[start+2],mode=='b'and 2 or 65536)end
    if h[1]then eq(e.acidLast,ids[h[1]]);eq(e.acidPrevious,ids[h[2]])end
   end)
   checked=checked+1
  end end
 end
 eq(checked,(last-first+1)*200)
 print('ACID_SLIME_L_MATRIX '..first..'-'..last..' '..checked..' cases passed')
end
