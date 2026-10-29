package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,N,Map,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local D=require('abyss_data');local F=dofile('tests/lua/support/game_ui_fixture.lua')
local UI=require('abyss_node_ui');local count=0
local function text(control,out)
 out=out or {};if control.visible==false then return out end
 if control.text then out[#out+1]=control.text end
 for _,child in pairs(control.children or {})do text(child,out)end;return out
end
for _,character in ipairs({'ironclad','raiden'})do
 -- Seed15's unmodified complete source queue starts Mark of Pain,
 -- SacredBark, Fusion Hammer. No queue sorting/filtering/replacement fixture.
 local r=Run.new(D,15,{experimental=true,character=character,campaign=true,campaignProfile='competition-two-act'})
 local map=Map.generate(r.data,15);assert(r.relicPool.queues.boss[2]=='SacredBark')
 local original=C.copy(r.relicPool.queues.boss)
 assert(Run.obtainPotion(r,'fire_potion'))
 while Map.available(map)[1].floor<16 do assert(Map.choose(map,Map.available(map)[1].id))end
 assert(N.enter(r,map,Map.available(map)[1].id))
 for _,enemy in ipairs(r.combat.enemies)do enemy.hp=0 end
 assert(Run.finishCombat(r));assert(Run.claimCardReward(r,0))
 dofile('tests/lua/support/finish_combat_rewards.lua')(r);assert(N.completeCombat(r,map))
 assert(N.enter(r,map,Map.available(map)[1].id));assert(N.openTreasure(r))
 local item=r.nodeFlow.reward.items[2]
 assert(item.sourceId=='SacredBark'and item.available and item.id=='sacred_bark','natural second Boss offer must be claimable')
 for i=1,3 do assert(r.nodeFlow.reward.items[i].sourceId==original[i])end
 assert(#r.relicPool.queues.boss==#original-3)
 local root=F.control({children=F.Layout}):GetChild('stage'):GetChild('nodePanel')
 local p=require('abyss_character_presentation').prepare(require('abyss_presentation'),r.data)
 local ui=UI.new(root,r,map,p,'click',nil,{imageSource='static',enhancedRooms=true})
 ui:setVisible(true);ui:update(2)
 local screen=table.concat(text(root),'\n');assert(screen:find('神圣树皮',1,true),'localized Boss choice missing')
 local key='treasureView/rewardItem2';assert(ui.actions[key]and ui.actions[key].enabled,'Bark Boss choice is disabled')
 local stale=ui.actions[key].handler;assert(ui:press(key))
 assert(r.phase=='act_transition'and r.floor==17 and r.relics[#r.relics]=='sacred_bark')
 local relics=r.relics;assert(not stale()and not N.claimBossTreasure(r,2));assert(r.relics==relics)
 local definition;for _,d in ipairs(r.data.relics.relics)do if d.id=='sacred_bark'then definition=d end end
 assert(definition.name=='神圣树皮'and definition.description:find('翻倍',1,true))
 assert(Run.advanceAct(r));assert(r.act==2 and r.phase=='map'and r.potions[1]=='fire_potion')
 local context=assert(Run.freezeMapContext(r));local nextMap=Map.generate(r.data,r.runSeed,2,context)
 assert(N.enter(r,nextMap,Map.available(nextMap)[1].id));assert(r.floor==18 and r.phase=='combat')
 r.combat.enemies[1].hp,r.combat.enemies[1].maxHp=200,200
 local b=r.combat;local block=b.enemies[1].block
 assert(Run.usePotion(r,1,1));assert(b.enemies[1].hp==200-math.max(0,40-block)and r.potions[1]==nil)
 assert(not Run.obtainRelic(r,'SacredBark'),'second obtain must not stack the multiplier')
 for _,enemy in ipairs(r.combat.enemies)do enemy.hp=0 end
 assert(Run.finishCombat(r));assert(Run.claimCardReward(r,0))
 dofile('tests/lua/support/finish_combat_rewards.lua')(r);assert(N.completeCombat(r,nextMap))
 while Map.available(nextMap)[1].floor<33 do assert(Map.choose(nextMap,Map.available(nextMap)[1].id))end
 r.floor,r.phase=nextMap.floor,'map';r.nodeFlow={id=nextMap.currentNodeId,floor=nextMap.floor,type='combat',complete=true,
  result='victory',mapSeed=nextMap.seed,mapSignature=nextMap.sourceSignature}
 assert(N.enter(r,nextMap,Map.available(nextMap)[1].id))
 for _,enemy in ipairs(r.combat.enemies)do enemy.hp=0 end
 assert(Run.finishCombat(r));assert(Run.claimCardReward(r,0))
 dofile('tests/lua/support/finish_combat_rewards.lua')(r);assert(N.completeCombat(r,nextMap))
 assert(N.enter(r,nextMap,Map.available(nextMap)[1].id));assert(N.claimBossTreasure(r,0))
 assert(r.phase=='victory'and r.floor==34 and r.act==2 and r.ending=='two_act_complete')
 assert(not Run.advanceAct(r)and not r.pendingAct)
 count=count+1;print('PASS actual seed15 Boss17 second choice -> Act2 Bark effect '..character)
end
print('SACRED_BARK_CHANNELS_PASS '..count)
