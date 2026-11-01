local C=require('abyss_combat')
local Data=require('abyss_data')
local View=require('abyss_battle_status_view')
local s=C.new(Data,{enemies={'byrd'},deck={},seed=42,hp=500,maxHp=500})
local bird=s.enemies[1]
local entry=C.copy(s.catalog.statuses.flight);entry.amount=3
local text=View.statusDetail(entry,s.rules,bird,s)
assert(text:find('受到的攻击伤害减半',1,true),'Flight must explicitly describe incoming attack damage')
assert(not text:find('普通攻击',1,true),'do not imply only the Strike card is affected')
assert(text:find('受到3次未被完全格挡的攻击后坠地。行动前补满次数。',1,true),'preserve grounding and refresh explanation')
local hp=bird.hp
C.damage(s,s.player,bird,6)
assert(bird.hp==hp-3 and bird.statuses.flight==2,'incoming normal attack damage is halved')
hp=s.player.hp
C.damage(s,bird,s.player,6)
assert(s.player.hp==hp-6,'Flight does not halve its owners outgoing attack')
hp=bird.hp
C.damage(s,s.player,bird,6,true)
assert(bird.hp==hp-6 and bird.statuses.flight==2,'fixed damage is neither halved nor a grounding hit')
print('FLIGHT_DESCRIPTION_PASS')
