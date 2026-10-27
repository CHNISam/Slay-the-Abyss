package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F={Run=require('abyss_run'),C=require('abyss_combat'),R=require('abyss_sts_random'),Map=require('abyss_map'),Nodes=require('abyss_nodes'),D=require('abyss_data')}
function F.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function F.same(a,b,seen)
 F.eq(type(a),type(b));if type(a)~='table'then F.eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do F.same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
function F.definition(r,id)for _,d in ipairs(r.data.cards.cards)do if d.id==id then return d end end end
function F.enter(r,kind,event)
 local m=F.Map.generate(F.D,r.eventSeed or r.seed,r.act or 1);local id=F.Map.available(m)[1].id
 for _,n in ipairs(m.nodes)do if n.id==id then n.type=kind;n.eventId=event end end
 assert(F.Nodes.enter(r,m,id));return m
end
function F.win(r)
 for _=1,30 do
  if r.phase~='combat'then break end
  for _=1,15 do
   if r.phase~='combat'then break end
   local uid;for _,c in ipairs(r.combat.hand)do if F.C.canPlay(r.combat,c.uid,1)then uid=c.uid;break end end
   if not uid then break end;assert(F.Run.play(r,uid,1))
  end
  if r.phase=='combat'then assert(F.Run.endTurn(r))end
 end
 F.eq(r.phase,'reward')
end
return F
