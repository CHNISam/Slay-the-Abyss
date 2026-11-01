package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions')
for _,id in ipairs({'conclude','vault'})do
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',enableStances=true,deck={id},enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 local c=table.remove(s.hand,1);s.draw={c}
 -- A real native action precedes the queued experimental card, leaving an
 -- empty native queue until its drain boundary. Early-end must wait for it.
 A.enqueue(s,{op='draw',value=0});C.autoplayTop(s,1,false,true);A.drain(C,s)
 assert(s.turn==2 and s.phase=='player',id..' must end the turn after an automatic use')
 assert(not s.cardActions and not s.pendingPlay and not s.endTurnAfterCard)
end
print('WATCHER_EARLY_TURN_AUTOPLAY native tail followed by automatic Conclude/Vault ends exactly once passed')
