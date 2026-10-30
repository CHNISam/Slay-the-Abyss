-- Controlled battle/deck/room fixtures, explicitly NOT natural route/native
-- evidence. Rewards, cost/effect resolution and rollback use real public APIs.
local H={}
H.Run,H.C,H.Data,H.R,H.A,H.E=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_actor'),require('abyss_events')
function H.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function H.same(a,b,path)
 if a==b then return end;path=path or 'state';H.eq(type(a),type(b))
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do H.same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
function H.run(ids,deck,setup)
 local data=H.C.copy(H.Data);data.rules.player.startingRelics={}
 local r=H.Run.new(data,'42')
 if deck then
  local originals={};for _,card in ipairs(r.deck)do originals[#originals+1]=card.uid end
  for _,uid in ipairs(originals)do assert(H.Run.removeCard(r,uid))end
  for _,entry in ipairs(deck)do
   if type(entry)=='table'then assert(H.Run.obtainCard(r,entry.cardId,{upgraded=entry.upgraded}))
   else assert(H.Run.obtainCard(r,entry))end
  end
 end
 -- Relic acquisition follows deck fixture preparation, so a real Necronomicon
 -- curse is retained in every battle instead of overwritten by a test deck.
 for _,id in ipairs(ids or {})do assert(H.Run.obtainRelic(r,id))end
 if setup then setup(r)end
 return r
end
function H.battle(ids,deck,setup)
 local r=H.run(ids,deck,setup);assert(H.Run.startCombat(r,'cultist_solo'));return r,r.combat
end
function H.card(r,id)
 for _,c in ipairs(r.combat.hand)do if c.cardId==id then return c end end
 error('fixture card not drawn: '..id)
end
function H.play(r,id,target)return H.Run.play(r,H.card(r,id).uid,target or 1)end
function H.reject(run,command,reason)
 local before=H.C.copy(run,{[run.data]=run.data});local owners={}
 for key,value in pairs(run)do if type(value)=='table'then owners[key]=value end end
 local ok,why=command();H.eq(ok,false);if reason then H.eq(why,reason)end;H.same(run,before)
 for key,value in pairs(owners)do H.eq(run[key],value)end
end
local count=0
function H.test(name,body)body();count=count+1;print('PASS '..name)end
function H.finish(marker)print(marker..' '..count..' passed')end
return H
