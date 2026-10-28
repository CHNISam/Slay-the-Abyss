-- STS319009 Strawberry/Pear/Mango/Waffle.onEquip and AbstractCreature health.
-- Called only on the private Run acquisition transaction. No random actions.
local Health=require('abyss_potion_health')
local Events=require('abyss_events')
local M={}
local increases={strawberry=7,pear=10,mango=14,lees_waffle=7}
local function integer(n)return type(n)=='number'and n%1==0 and n>=0 and n<=2147483647 end
local function relics(run)
 local result={}
 for _,id in ipairs(run.relics or {})do
  result[#result+1]=id=='Mark of the Bloom'and'mark_of_bloom'or id=='Magic Flower'and'magic_flower'or id
 end
 return result
end
local function heal(run,actor,battle,requested,onHpChanged)
 -- AbstractCreature.heal refuses a dying actor; it is not a revival source.
 if actor.isDying or actor.hp<=0 then return end
 local amount=Health.modifyHealing(requested,relics(run),battle~=nil)
 local before=actor.hp
 actor.hp=math.min(actor.maxHp,actor.hp+0.0+amount)
 if battle then
  Events.emit(battle,'heal',{target=actor.id,amount=actor.hp-before})
  onHpChanged(battle,actor,before)
 end
end
function M.equip(run,id,onHpChanged)
 local amount=assert(increases[id],'unsupported maximum-health relic')
 assert(run.phase~='combat'or type(run.combat)=='table'and type(run.combat.player)=='table','missing active health owner')
 local battle=run.phase=='combat'and run.combat or nil
 assert(not battle or not battle.originalV4,'source maximum-health context unavailable')
 local actor=battle and battle.player or run
 assert(type(actor)=='table'and integer(actor.maxHp)and actor.maxHp>=1
  and integer(actor.hp)and actor.hp<=actor.maxHp,'invalid relic health')
 -- Preserve the existing finite runtime capacity rather than partially granting
 -- ownership and wrapping a signed integer. This is a safety refusal, not a
 -- claim that the source Java overflow path is meaningful ordinary gameplay.
 assert(actor.maxHp+0.0+amount<=2147483647,'maximum health capacity')
 actor.maxHp=actor.maxHp+0.0+amount
 -- Source increaseMaxHp invokes ordinary heal(amount,true) even when Waffle
 -- passes showEffect=false. Waffle then invokes heal of the NEW maximum.
 heal(run,actor,battle,amount,onHpChanged)
 if id=='lees_waffle'then heal(run,actor,battle,actor.maxHp,onHpChanged)end
 if battle then run.hp,run.maxHp=actor.hp,actor.maxHp end
end
return M
