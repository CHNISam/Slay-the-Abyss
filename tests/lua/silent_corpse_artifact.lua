package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local P=require('abyss_character_profiles');local A=require('abyss_actor')
local data=P.prepare(require('abyss_data'),'silent')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
for artifact=0,2 do
 local s=C.new(data,{deck={'corpse_explosion'},enemies={'jaw_worm'},seed=42,experimental=true,enableStances=true})
 s.energy=3;s.enemies[1].hp=300;s.enemies[1].maxHp=300
 A.applyPower(s,s.player,'sadistic_nature',5,s.player);if artifact>0 then A.applyPower(s,s.enemies[1],'artifact',artifact,s.enemies[1])end
 assert(C.play(s,s.hand[1].uid,1))
 eq(s.enemies[1].statuses.artifact or 0,0)
 eq(s.enemies[1].statuses.poison,artifact==0 and 6 or nil)
 eq(s.enemies[1].statuses.corpse_explosion,artifact<2 and 1 or nil)
 local callbacks=0
 for _,event in ipairs(s.events)do if event.kind=='status_damage'and event.detail.status=='poison'then error('no poison tick occurs during this real cast')end
  if event.kind=='damage'and event.detail.source==s.player.id then callbacks=callbacks+1 end
 end
 eq(callbacks,2-artifact);eq(s.enemies[1].hp,300-5*(2-artifact))
 print('ok real Corpse Explosion Artifact '..artifact..' and only successful debuffs trigger Sadistic Nature once')
end
