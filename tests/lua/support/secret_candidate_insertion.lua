-- Legal public acquisition, controlled pile order made only from actual copies.
local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b,label)
 label=label or 'same';if a==b then return end;assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(kind,upgraded,samples)
 for _,sample in ipairs(samples)do
  local id=kind=='skill'and'secret_technique'or'secret_weapon'
  local run=Run.new(D,sample.seed);assert(Run.obtainCard(run,id));local master=run.deck[#run.deck]
  if upgraded then assert(Run.upgradeCard(run,master.uid))end
  assert(run.floor==1);assert(Run.startCombat(run,'cultist_solo'));local s=run.combat
  local originals={};for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do originals[#originals+1]=c end end
  table.sort(originals,function(a,b)return a.uid<b.uid end)
  local used,secret,candidates={},{},{}
  for _,c in ipairs(originals)do if c.cardId==id then secret=c;used[c]=true end end
  assert(secret.uid)
  for _,c in ipairs(originals)do
   if #candidates<sample.count and s.catalog.cards[c.cardId].type==kind and c~=secret then
    candidates[#candidates+1]=c;used[c]=true
   end
  end
  assert(#candidates==sample.count)
  local other;for _,c in ipairs(originals)do if not used[c]and s.catalog.cards[c.cardId].type~=kind then other=c;used[c]=true;break end end
  assert(other)
  s.hand={secret};s.draw={other};for _,c in ipairs(candidates)do s.draw[#s.draw+1]=c end
  s.discard={};s.exhaust={};for _,c in ipairs(originals)do if not used[c]then s.discard[#s.discard+1]=c end end
  same(R.snapshot(s.cardRandomRng),sample.initial,'initial independent stream')
  local trace={};local raw=R.randomInt
  R.randomInt=function(owner,maximum,...)
   local before=R.snapshot(owner);local value=raw(owner,maximum,...)
   trace[#trace+1]={maximum=maximum,value=value,before=before,after=R.snapshot(owner)};return value
  end
  if sample.count==0 then
   local before=C.copy(run,{[run.data]=run.data});assert(not Run.play(run,secret.uid));same(run,before,'zero eligible rejects atomically')
  else
   assert(Run.play(run,secret.uid))
   same(trace,sample.trace,'secret candidate construction draws')
   same(R.snapshot(s.cardRandomRng),sample.after,'secret candidate complete stream')
   if sample.count==1 then
    assert(not s.pendingChoice and #s.hand==1 and s.hand[1].uid==candidates[1].uid)
   else
    local choice=assert(s.pendingChoice);local expected={}
    for _,ordinal in ipairs(sample.order)do expected[#expected+1]=candidates[ordinal].uid end
    same(choice.uids,expected,'source candidate UID insertion order')
    local token=choice.token;local before=C.copy(run,{[run.data]=run.data})
    assert(not Run.chooseCard(run,token,other.uid));same(run,before,'nonmember reject atomic')
    assert(not Run.chooseCard(run,token+999,expected[1]));same(run,before,'wrong token reject atomic')
    same(choice.uids,expected,'validation must not reshuffle candidates')
    assert(Run.chooseCard(run,token,expected[1]))
    assert(not s.pendingChoice and #s.hand==1 and s.hand[1].uid==expected[1])
    before=C.copy(run,{[run.data]=run.data});assert(not Run.chooseCard(run,token,expected[1]));same(run,before,'old completed token atomic')
   end
   local pile=upgraded and s.discard or s.exhaust;local found=0
   for _,c in ipairs(pile)do if c.uid==secret.uid then found=found+1 end end
   assert(found==1,'base exhausts; upgraded discards exact played UID')
  end
  same(trace,sample.trace,'no validation or retrieval reconsumption')
  same(R.snapshot(s.cardRandomRng),sample.after,'final independent stream')
  R.randomInt=raw
 end
 print('SECRET_CANDIDATE_INSERTION_PASS '..kind..' '..tostring(upgraded)..' '..#samples)
end
