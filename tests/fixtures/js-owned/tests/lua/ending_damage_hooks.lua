package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,H=require('abyss_combat'),require('abyss_actor'),require('abyss_corrupt_heart')
local D=require('abyss_data');local count=0
local function check(name,fn)fn();count=count+1;print('PASS ending damage '..count..' '..name)end
local function fresh()
 local s=assert(C.new(D,{seed=42,enemies={'cultist'}}))
 if not s.catalog.enemies.corrupt_heart then H.register(s.catalog,C.copy)end
 local e=s.enemies[1];e.definitionId,e.ai,e.hp,e.maxHp='corrupt_heart',{kind='corrupt_heart'},750,750
 e.statuses={};A.bindStatuses(e,s.catalog.statuses)
 for _,power in ipairs(H.preBattle(s,e))do assert(A.applyPower(s,e,power.status,power.value,e))end
 return s,e
end
check('normal damage commits the cap after block and preserves the zero Power',function()
 local s,e=fresh();assert(A.damage(s,s.player,e,500,true)==300)
 assert(e.hp==450 and e.statuses.invincible==0)
 local found=false;for _,power in ipairs(A.statusView(e))do if power.id=='invincible'then found=power.amount==0 end end
 assert(found,'spent Invincible must remain visible')
 assert(A.damage(s,s.player,e,10,false)==0 and A.loseHp(s,e,20)==0 and e.hp==450)
end)
check('preview is read-only and Boot cannot exceed the final remaining budget',function()
 local s,e=fresh();s.relics={'boot'}
 for _=1,3 do assert(A.attackAmount(s,s.player,e,500)==500 and e.statuses.invincible==300)end
 assert(A.damage(s,s.player,e,299,false)==299)
 assert(A.damage(s,s.player,e,1,false)==1 and e.statuses.invincible==0)
 assert(e.hp==450)
end)
check('absorbed damage spends no budget and retaliation/direct HP loss share it',function()
 local s,e=fresh();e.block=500
 assert(A.damage(s,s.player,e,500,true)==0 and e.statuses.invincible==300)
 assert(A.retaliate(s,s.player,e,290)==290 and e.statuses.invincible==10)
 assert(A.loseHp(s,e,30)==10 and e.statuses.invincible==0)
 assert(A.retaliate(s,s.player,e,7)==0 and e.hp==450)
end)
check('only Heart owner turn resets before poison; player turn never resets it',function()
 local s,e=fresh();assert(A.damage(s,s.player,e,300,true)==300)
 A.startTurnEffects(s,s.player);assert(e.statuses.invincible==0)
 assert(A.applyPower(s,e,'poison',7,s.player));A.startTurnEffects(s,e)
 assert(e.hp==443 and e.statuses.invincible==293 and e.statuses.poison==6)
end)
check('source Painful Stabs minus-one membership is legal and makes one Wound per unblocked NORMAL hit',function()
 local s,e=fresh();assert(A.applyPower(s,e,'painful_stabs',-1,e))
 assert(e.statuses.painful_stabs==-1)
 local before=#s.discard
 assert(C.damage(s,e,s.player,5,false)==5);assert(#s.discard==before+1 and s.discard[#s.discard].cardId=='wound')
 s.player.block=10;assert(C.damage(s,e,s.player,5,false)==0 and #s.discard==before+1)
 assert(A.retaliate(s,e,s.player,1)==0 and #s.discard==before+1)
end)
print('ENDING_DAMAGE_HOOKS_PASS '..count..' real Actor boundaries; controlled Heart identity, not full encounter/live evidence')
