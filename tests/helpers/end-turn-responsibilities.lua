local trace,fault,called={},{},0
local function note(kind,...)
 called=called+1;trace[#trace+1]={kind=kind,args=table.pack(...)}
 if fault.at==called then error(fault.token,0)end
end
local function check(ok,why)assert(ok,'[END_TURN_RESPONSIBILITY] '..why)end
local Schedule={ownerEnd=function(state,filter,virtual)note('schedule',state,filter,virtual);return state.entries end,
 remove=function(state,p,id)note('remove',state,p,id);p.removed=id end}
local Events={emit=function(state,kind,detail)note('emit',state,kind,detail);state.events[#state.events+1]={kind=kind,detail=detail}end,
 frame=function(state)note('frame',state);return {hp=state.player.hp,noDraw=state.player.noDraw}end}
package.preload.abyss_power_schedule=function()return Schedule end
package.preload.abyss_events=function()return Events end
package.preload.abyss_relic_combat_hooks=function()return {endTurnBlock=function(state)note('relic',state);return state.relicBlock end}end
local supplied={top={{op='topA'},{kind='effect',effect={op='topB'}}},bottom={{op='bottomA'},{kind='effect',effect={op='bottomB'}}}}
for _,name in ipairs({'abyss_warrior_strength_cards','abyss_watcher_flow_cards'})do
 package.preload[name]=function()return {planHook=function(...)note(name,...);return supplied,'ignored',nil end}end
end
package.preload.abyss_card_triggers=function()return {prepareEndTurn=function(state)note('rage',state);return supplied.bottom end}end
package.preload.abyss_orbs=function()return {preparePassive=function(state,i,phase)note('orbPrepare',state,i,phase);return i%2==1 and {kind='frost',value=i}or nil end,
 resolve=function(state,action,combat)note('orbResolve',state,action,combat);state.orbResolved=action end}end
package.preload.abyss_card_actions=function()return {apply=function(combat,state,item)note('native',combat,state,item);state.native=item end}end
package.preload.abyss_defect_final_cards=function()return {removePower=function(state,id)note('defectRemove',state,id);state.player.statuses[id]=nil end}end
local M=require('abyss_end_turn_powers')
local combat={cardDefinition=function(state,c)note('definition',state,c);return c.definition end,
 block=function(state,p,n,flag)note('block',state,p,n,flag);p.block=(p.block or 0)+n end,
 retaliate=function(state,source,target,n)note('retaliate',state,source,target,n);target.hp=target.hp-n end}
local queue={pushBottom=function(state,item)note('queue',state,item);state.queued[#state.queued+1]=item end}
local function fresh()
 local p={id='p',hp=20,statuses={},temporaryStrength=2,temporaryDexterity=3,noDraw=true,
  temporaryPowerOrder={'strength','dexterity'},powerOrder={'lose_strength','lose_dexterity','regen'}}
 return {player=p,events={{kind='previous'}},entries={},queued={},hand={{definition={ethereal=false}},{definition={ethereal=true}}},enemies={{hp=10},{hp=4,escaped=true},{hp=0}},orbs={balls={{},{},{}}}}
end
local serial=0
local function run(label,state,body,at)
 trace={};called=0;fault={at=at,token={label='sentinel'}};serial=serial+1
 END_TURN_GRAPH_WRITE({state=state,trace=trace},label..':before',true)
 local result=table.pack(pcall(body))
 if not result[1]and type(result[2])=='table'then check(result[2]==fault.token,'exact injected error object')end
 local observed=result
 if not result[1]and END_TURN_ERRORS[result[2]]then
  observed={n=result.n,table.unpack(result,1,result.n)};observed[2]=END_TURN_ERRORS[result[2]];END_TURN_RELOCATED(result[2])
 end
 END_TURN_GRAPH_WRITE({state=state,trace=trace,result=observed,fault=fault},label..':after',true)
 return result
end
local powerIds={'regen','combust','rage','study','omega','establishment','lose_strength','lose_dexterity','ritual','wraith_form','shackled','no_draw','equilibrium','well_laid_plans','rebound','amplify','entangled','extension','bomb','unknown'}
for _,id in ipairs(powerIds)do for _,n in ipairs({-1,0,1,2})do
 local s=fresh();s.entries={{id=id,amount=n}};s.cardTriggerPowerOrder={{id='rage'}}
 if id=='bomb'then s.colorlessBombs={{id='bomb',turns=n,damage=7}}end
 local extension={ownerEndIds={extension=true},ownerEndPlan=function(...)note('extension',...);return supplied end}
 local r=run(id..'/'..n,s,function()return M.prepare(s,combat,extension)end)
 check(r[1],'planner should complete '..id)
 if id=='regen'then check(#r[2]==(n>0 and 1 or 0),'positive Regen only')end
 if id=='ritual'then check(#r[2]==(n>0 and 1 or 0),'positive Ritual only')end
 if id=='wraith_form'then check(#r[2]==(n<0 and 1 or 0),'negative Wraith only')end
 if id=='equilibrium'then check(s.hand[1].retain and not s.hand[2].retain,'Ethereal not retained')end
 if id=='bomb'and n==1 then check(r[2][1].effect.op=='ownerEndBombReduce'and r[2][2].effect.op=='ownerEndDamageAll','Bomb decrement before damage')end
end end
for _,registered in ipairs({false,true})do
 local s=fresh();s.entries={{id='rage',amount=2}};s.cardTriggerPowerOrder=registered and {{id='rage'},{id='rage'}}or {}
 local r=run('rage-registration/'..tostring(registered),s,function()return M.prepare(s,combat)end);check(r[1],'Rage complete')
 check(r[2][1].effect.op==(registered and 'bottomA'or 'removeStatus'),'Rage acquisition route')
end
local ops={'ownerPreCardBlock','ownerEndOrbTrigger','ownerEndOrbEffect','ownerEndNative','ownerEndRegen','ownerEndClearLoss','ownerEndClearNoDraw','ownerEndBombReduce','ownerEndDamageAll','ownerEndThorns','ownerEndRemoveDefect','unknown'}
for _,op in ipairs(ops)do for _,at in ipairs({0,1,2,3})do
 local s=fresh();s.player.statuses.regen=2;s.player.statuses.amplify=1
 local effect={op=op,value=3,stat='strength',action={kind='frost',value=2},bomb={id='bomb',turns=1},source=s.enemies[1],status='amplify'}
 effect.item={source=s.player,effect={op='damageRandom',fixed=true}}
 run(op..'/fault/'..at,s,function()return M.apply(combat,s,effect,queue)end,at)
end end
for _,stat in ipairs({'strength','dexterity','unknown'})do local s=fresh()
 local r=run('clear/'..stat,s,function()return M.apply(combat,s,{op='ownerEndClearLoss',stat=stat},queue)end)
 if stat~='unknown'then check(r[1]and s.player[stat=='strength'and 'temporaryStrength'or 'temporaryDexterity']==0,'clear temporary debt')end
end
for _,n in ipairs({0,1,2})do local s=fresh();s.player.statuses.regen=n
 local r=run('regen-apply/'..n,s,function()return M.apply(combat,s,{op='ownerEndRegen',value=n},queue)end)
 check(r[1]and s.player.statuses.regen==math.max(0,n-1),'Regen decay')
end
for _,op in ipairs({'damageRandom','silentFinal','colorless','invalid'})do local s=fresh()
 s.cardActions={{source=s.player,effect={op=op,fixed=true,kind=op=='silentFinal'and 'corpseDamage'or 'sadisticDamage'},target=op=='colorless'and s.enemies[1]or nil}}
 run('transfer/'..op,s,function()return M.transferNative(s,queue)end)
end
for _,prior in ipairs({false,{}, {'dark_embrace'}, {'dark_embrace','dark_embrace'},setmetatable({},{})})do local s=fresh()
 s.entries={{id='dark_embrace',amount=1}};s.player.statuses.dark_embrace=1;s.exhaustPowerOrder=prior
 run('exhaust/'..serial,s,function()return M.prepareExhaust(s)end)
end
for _,variant in ipairs({'relic','virtual','status','extension','bomb','none'})do local s=fresh();s.player.temporaryStrength=0;s.player.temporaryDexterity=0;s.player.noDraw=false;s.orbs=nil
 local ext={ownerEndIds={custom=true}}
 if variant=='relic'then s.relicBlock=2 elseif variant=='virtual'then s.player.temporaryStrength=1 elseif variant=='status'then s.player.statuses.rage=1 elseif variant=='extension'then s.player.statuses.custom=1 elseif variant=='bomb'then s.colorlessBombs={{turns=1}}end
 local r=run('needed/'..variant,s,function()return M.needed(s,ext)end);check(r[1]and r[2]==(variant~='none'),'needed route '..variant)
end
local s=fresh();s.player.stance='Calm';s.relicBlock=2;s.entries={{id='like_water',amount=5},{id='metallicize',amount=3}}
run('pre-cards',s,function()return M.preparePreCards(s)end)
local mismatch=fresh();mismatch.entries={{id='bomb',amount=2}};mismatch.colorlessBombs={{id='bomb',turns=1,damage=5}}
run('bomb-mismatch',mismatch,function()return M.prepare(mismatch,combat)end)
local invalid=fresh()
run('invalid-native',invalid,function()return M.apply(combat,invalid,{op='ownerEndNative',item={source=invalid.player,effect={op='invalid'}}},queue)end)
run('invalid-thorns',invalid,function()return M.apply(combat,invalid,{op='ownerEndThorns',source=invalid.player},queue)end)
END_TURN_GRAPH_WRITE({complete=true,cases=serial},'complete',true)
