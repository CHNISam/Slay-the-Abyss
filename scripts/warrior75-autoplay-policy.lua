-- Test-only heuristic for all 75 cards, adapted from our M2 policy. It chooses
-- legal commands; scores are player decisions, never replacements for rules.
-- Never installs in the normal game manifest and
-- never writes Run, Map or inventory. The caller dispatches public UI commands.
local C=require('abyss_combat')
local Nodes=require('abyss_nodes')
local P={}
local priorities={inflame=100,metallicize=95,shrug_it_off=90,pommel_strike=85,anger=80,iron_wave=75,
    disarm=72,uppercut=68,cleave=65,twin_strike=60,carnage=55,ghostly_armor=54,thunderclap=53,
    rampage=52,offering=50,reaper=48,battle_trance=45,true_grit=40,bludgeon=32,impervious=30,
    flame_barrier=88,hemokinesis=79,immolate=86,whirlwind=74,shockwave=70,power_through=66,
    burning_pact=42,dark_embrace=55,feel_no_pain=65,corruption=47,armaments=54,fiend_fire=50}
function P.scoreCard(run,id)
    local count=0
    for _,card in ipairs(run.deck) do if card.cardId==id then count=count+1 end end
    return (priorities[id] or 10)-count*28
end
local function incoming(battle,index)
    local total=0
    for i,e in ipairs(battle.enemies) do if e.hp>0 and (not index or i==index) then
        local intent=C.intent(battle,i)
        for _,effect in ipairs(intent and intent.effects or {}) do
            if effect.op=='damage' then total=total+C.attackAmount(battle,e,battle.player,effect.value)*(effect.times or 1) end
        end
    end end
    return total
end
-- Returns uid,target,details; nil means end turn. Only visible hand/current
-- intent is read: no future draw-pile order or future random state peeking.
function P.chooseCombat(run)
    local battle=run.combat
    if run.phase~='combat' or not battle or battle.phase~='player' then return nil end
    local best,score=nil,0
    local need=math.max(0,incoming(battle)-battle.player.block)
    for handIndex,card in ipairs(battle.hand) do for target,e in ipairs(battle.enemies) do
        if e.hp>0 and C.canPlay(battle,card.uid,target) then
            local def=C.cardDefinition(battle,card)
            local value,damage,block,payment=0,0,0,0
            for _,effect in ipairs(def.effects) do
                local times=effect.times or 1
                if times=='X' then times=battle.energy end
                if effect.op=='damage' then damage=damage+math.min(e.hp+e.block,C.attackAmount(battle,battle.player,e,effect.value)*times)
                elseif effect.op=='damageAll' then
                    for _,enemy in ipairs(battle.enemies) do if enemy.hp>0 then
                        damage=damage+math.min(enemy.hp+enemy.block,C.attackAmount(battle,battle.player,enemy,effect.value)*times) end end
                elseif effect.op=='damageEqualToBlock' then damage=damage+math.min(e.hp+e.block,battle.player.block)
                elseif effect.op=='block' then block=block+C.blockAmount(battle,battle.player,effect.value)
                elseif effect.op=='doubleBlock' then block=block+battle.player.block
                elseif effect.op=='draw' then value=value+effect.value*(battle.energy>def.cost and 3 or 1)
                elseif effect.op=='energy' then value=value+effect.value*(#battle.hand>2 and 5 or 1)
                elseif effect.op=='loseHp' then value=value-effect.value*1.6;payment=payment+effect.value
                elseif effect.op=='gainStatus' and effect.status=='strength' then value=value+effect.value*7
                elseif effect.op=='gainStatus' then
                    local weight=({metallicize=5,demon_form=10,feel_no_pain=6,dark_embrace=5,
                        corruption=12,barricade=9,flame_barrier=2,rage=3,double_tap=6,
                        combust=3,brutality=4,evolve=2,fire_breathing=2,berserk=5,rupture=4})[effect.status] or 1
                    value=value+effect.value*weight
                elseif effect.op=='feed' or effect.op=='reaper' then
                    damage=damage+math.min(e.hp+e.block,C.attackAmount(battle,battle.player,e,effect.value))
                elseif effect.op=='fiendFire' then
                    damage=damage+math.min(e.hp+e.block,C.attackAmount(battle,battle.player,e,effect.value)*math.max(0,#battle.hand-1))
                elseif effect.op=='secondWind' then
                    for _,held in ipairs(battle.hand) do if held.uid~=card.uid and C.cardDefinition(battle,held).type~='attack' then block=block+C.blockAmount(battle,battle.player,effect.value) end end
                elseif effect.op=='upgradeHand' or effect.op=='dualWield' or effect.op=='recoverExhaust' or effect.op=='generateAttack' then value=value+4
                elseif effect.op=='gainTemporaryStrength' then value=value+effect.value*math.max(1,battle.energy)*1.5
                elseif effect.op=='blockPerTurn' then value=value+effect.value*4
                elseif effect.op=='gainStatusPerTurn' then value=value+effect.value*8
                elseif effect.op=='applyStatus' or effect.op=='applyStatusAll' then
                    if effect.status=='vulnerable' and (e.statuses.vulnerable or 0)==0 then value=value+5 end
                    if effect.status=='weak' and (e.statuses.weak or 0)==0 then value=value+incoming(battle,target)*.4+2 end
                    if effect.status=='strength' and effect.value<0 then value=value-effect.value*5 end
                elseif effect.op=='increaseDamageThisCombat' then value=value+effect.value*.7 end
            end
            value=value+damage+math.min(block,need)*1.6
            if damage>=e.hp+e.block then value=value+incoming(battle,target)*1.6+4 end
            value=value/math.max(.6,def.costMode=='all_energy' and battle.energy or def.cost)
            if payment>=battle.player.hp then value=-10000 end
            if value>score then score=value;best={uid=card.uid,cardId=card.cardId,target=target,handIndex=handIndex} end
        end
    end end
    return best and best.uid,best and best.target,best
end
function P.chooseReward(run)
    local best,rank=0,28
    for i,id in ipairs(require('abyss_run').rewardOptions(run)) do
        local score=P.scoreCard(run,id);if score>rank then best,rank=i,score end
    end
    return best
end
function P.chooseNode(run,map,coverage)
    coverage=coverage or {}
    local chosen,best=nil,-math.huge
    for _,node in ipairs(Nodes.available(run,map)) do
        local score=({combat=10,event=40,shop=15,camp=35,treasure=50,elite=0,boss=0})[node.type] or 0
        if not coverage[node.type] then score=score+18 end
        if node.type=='elite' then score=run.hp>65 and not coverage.elite and 60 or -20 end
        if node.type=='camp' then score=score+(run.maxHp-run.hp)*.4 end
        if node.type=='shop' then score=score+(run.gold>=125 and 40 or run.gold>=75 and 12 or -25) end
        if score>best then chosen,best=node,score end
    end
    return chosen
end
-- One suggestion at a time, so prices/UIDs come from current state. localDone
-- tracks commands dispatched in this shop, coverage tracks this run's actions.
function P.suggestNodeAction(run,map,coverage,localDone)
    coverage,localDone=coverage or {},localDone or {}
    local flow=run.nodeFlow
    if not flow or flow.complete then return nil end
    local view=Nodes.view(run,map).node
    if flow.type=='camp' then
        if not coverage.rest or run.hp<run.maxHp*.55 then return {method='rest'} end
        local card=view.upgradeCards[1]
        for _,c in ipairs(view.upgradeCards) do
            if c.cardId=='bash' or P.scoreCard(run,c.cardId)>P.scoreCard(run,card.cardId) then card=c end
        end
        return card and {method='upgrade',uid=card.uid} or {method='rest'}
    elseif flow.type=='shop' then
        if not localDone.buy_card then
            local best,rank=nil,30
            for _,offer in ipairs(view.cards) do
                if not offer.unavailable and not offer.sold and offer.price<=run.gold then
                    local score=P.scoreCard(run,offer.id);if score>rank then best,rank=offer,score end
                end
            end
            if best then return {method=Nodes.buyCardSlot and best.slot and 'buyCardSlot' or 'buyCard',
                id=best.id,slot=best.slot,coverage='buy_card'} end
        end
        if not coverage.remove_card and view.removeAvailable and run.gold>=view.removePrice then
            for _,card in ipairs(run.deck) do if card.cardId=='strike' then
                return {method='removeCard',uid=card.uid,coverage='remove_card'} end end
        end
        if not localDone.buy_potion and Nodes.buyPotion and require('abyss_run').potionCount(run)<run.data.rules.player.potionSlots then
            for slot,offer in ipairs(view.potions or {}) do
                if not offer.unavailable and not offer.sold and offer.price<=run.gold then
                    return {method='buyPotion',slot=slot,coverage='buy_potion'} end
            end
        end
        return {method='leaveShop'}
    elseif flow.type=='event' then
        local id=flow.event.id
        local choice,uid='leave',nil
        if id=='golden_shrine' then choice='pray'
        elseif id=='goop' then choice=run.hp>35 and 'gather' or 'leave'
        elseif id=='cleric' and run.hp<55 and run.gold>=35 then choice='heal'
        elseif id=='purifier' then choice='pray';uid=run.deck[1].uid
        elseif id=='upgrade_shrine' then for _,card in ipairs(view.upgradeCards) do
            choice='upgrade';uid=card.uid;if card.cardId=='bash' then break end end
        end
        return {method='chooseEvent',choice=choice,uid=uid}
    elseif flow.type=='treasure' then
        return {method=flow.roomKind=='boss_treasure' and 'claimBossTreasure' or 'claimTreasure',index=1}
    end
end
return P
