local H={C=require('abyss_combat'),D=require('abyss_data'),R=require('abyss_sts_random'),
 AI=require('abyss_enemy_ai'),A=require('abyss_actor'),N=require('abyss_nemesis'),
 Run=require('abyss_run'),Q=require('abyss_encounter_queue')}
function H.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function H.same(a,b)
 H.eq(type(a),type(b));if type(a)~='table'then H.eq(a,b);return end
 for k,v in pairs(a)do H.same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
function H.battle(seed,deck,ids,data)
 local streams={seed=seed or '1'}
 for _,id in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[id]=H.R.fromSeed(streams.seed)end
 return H.C.new(data or H.D,{deck=deck or {},enemies=ids or {'nemesis'},roomSeed=streams.seed,
  roomStreams=streams,maxHp=1000,hp=1000})
end
function H.intent(e)return e.intents[e.intentIndex].id end
function H.force(s,id)
 local e=s.enemies[1]
 for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return e,move.effects end end
 error(id)
end
function H.room()
 -- Independent chapter-queue vectors fix seed1's first Act3 elite to Nemesis.
 local r=H.Run.new(H.D,'1',{experimental=true,campaign=true})
 r.act,r.floor,r.encounters=3,35,H.Q.new('1',3)
 H.eq(H.Q.peek(r.encounters,'elite'),'Nemesis');return r
end
return H
