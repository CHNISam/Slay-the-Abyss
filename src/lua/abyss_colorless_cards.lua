-- PC 2.3.4 factual card rules, fixed319009. No source bodies or assets copied.
-- Shared cards are registered after character preparation; class pools stay intact.
local Actors=require('abyss_actor')
local Random=require('abyss_sts_random')
local Catalog=require('abyss_colorless_catalog')
local function catalogIndex(_,key)
    if key=='withCards' or key=='powerIcon' or key=='powerDescription' then return Catalog[key] end
end
local function catalogNewIndex(self,key,value)
    if key=='withCards' or key=='powerIcon' or key=='powerDescription' then Catalog[key]=value
    else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=catalogIndex,__newindex=catalogNewIndex})
local function e(kind,value,extra)
    local out={op='colorless',kind=kind,value=value or 0}
    for k,v in pairs(extra or {})do out[k]=v end
    return out
end
local function actions()return require('abyss_card_actions')end
function M.adapt(state,instance,d)
    local first=type(d.effects)=='table' and d.effects[1]
    if type(first)=='table' then
        if d.id=='mind_blast' and state.draw then first.value=#state.draw end
        if d.id=='ritual_dagger'then first.damage=instance.misc or 15 end
    end
    if instance.freeToPlayOnce and d.cost>0 then d.cost=0 end
    return d
end
function M.canUse(state,d)
    local needsClassPool=d.id=='discovery' or d.id=='chrysalis' or d.id=='metamorphosis'
    for _,effect in ipairs(d.effects)do if effect.op=='generateAttack'then needsClassPool=true end end
    if needsClassPool then
        for _,rarity in ipairs({'common','uncommon','rare'})do
            for _,id in ipairs(state.sourcePools and state.sourcePools.src and state.sourcePools.src[rarity] or {})do
                if not state.catalog.cards[id]then return false,'incomplete_generation_pool:'..id end
            end
        end
    end
    if d.id=='secret_weapon'or d.id=='secret_technique'then
        local kind=d.id=='secret_weapon'and 'attack'or 'skill'
        for _,c in ipairs(state.draw)do if state.catalog.cards[c.cardId].type==kind then return true end end
        return false,'no_matching_draw_card'
    end
    return true
end
function M.describe(d,dynamic)
    local parts={};local labels={weak='虚弱',vulnerable='易伤',strength='力量',artifact='人工制品',intangible='无实体',no_block='无法从卡牌获得格挡',magnetism='每回合开始生成无色牌',mayhem='每回合开始自动打出抽牌堆顶牌',sadistic_nature='施加减益时造成伤害'}
    for i,f in ipairs(d.effects)do
        local n=dynamic and ('{effects.'..(i-1)..'.value}')or tostring(f.value)
        local text
        if f.op=='damage'or f.op=='damageAll'then
            if d.id=='mind_blast' and not dynamic then text='造成等同于抽牌堆张数的伤害'
            else text='造成'..n..'点伤害'..(f.op=='damageAll'and '（全体敌人）'or '') end
        elseif f.op=='block'then text='获得'..n..'点格挡'
        elseif f.op=='draw'then text='抽'..n..'张牌'
        elseif f.op=='heal'then text='回复'..n..'点生命'
        elseif f.op=='loseHp'then text='失去'..n..'点生命'
        elseif f.op=='gainStatus'then text='获得'..n..'层'..assert(labels[f.status])
        elseif f.op=='applyStatus'or f.op=='applyStatusAll'then text='施加'..n..'层'..assert(labels[f.status])..(f.op=='applyStatusAll'and '（全体敌人）'or '')
        elseif f.op=='handToDraw'then text='将一张手牌放到抽牌堆顶'
        elseif f.op=='colorless'then
            local k=f.kind
            if k=='apotheosis'then text='升级本场战斗所有牌'
            elseif k=='shackles'then text='目标本回合失去'..n..'点力量'
            elseif k=='deepBreath'then text='将弃牌洗入抽牌堆'
            elseif k=='discovery'then text='从三张随机牌中选一张入手，本回合费用为0'
            elseif k=='enlightenment'then text='手牌费用高于1的降至1，持续'..(f.value==1 and '本场战斗'or '本回合')
            elseif k=='forethought'then text='将'..(f.value==1 and '任意张手牌'or '一张手牌')..'置于牌底，下次打出免费'
            elseif k=='impatience'then text='手牌没有攻击牌时抽'..n..'张牌'
            elseif k=='generateColorless'then text='生成'..n..'张随机无色牌入手'
            elseif k=='generateDraw'then text='生成'..n..'张随机'..(f.cardType=='skill'and '技能'or '攻击')..'牌洗入抽牌堆，本场费用为0'
            elseif k=='madness'then text='随机一张手牌的费用在本场战斗降为0'
            elseif k=='purity'then text='选择至多'..n..'张手牌消耗'
            elseif k=='greed'then text='造成'..(dynamic and ('{effects.'..(i-1)..'.damage}')or tostring(f.value))..'点伤害；击杀非召唤敌人获得'..tostring(f.value)..'金币'
            elseif k=='ritual'then text='造成'..(dynamic and ('{effects.'..(i-1)..'.damage}')or tostring(f.damage))..'点伤害；击杀非召唤敌人永久增加'..tostring(f.value)..'点伤害'
            elseif k=='panache'then text='每回合每打出五张牌，对全体敌人造成'..n..'点伤害'
            elseif k=='secret'then text='从抽牌堆选择一张'..(f.cardType=='skill'and '技能'or '攻击')..'牌入手'
            elseif k=='bomb'then text='第三次己方回合结束时，对全体敌人造成'..n..'点伤害'
            elseif k=='transmutation'then text='生成X张随机无色牌'..(f.value==1 and '并升级'or '')..'入手，本回合费用为0'
            elseif k=='violence'then text='随机将抽牌堆'..n..'张攻击牌加入手牌'end
        end
        parts[#parts+1]=assert(text,'missing colorless description: '..d.id)
    end
    if d.innate then parts[#parts+1]='固有'end
    if d.exhaust then parts[#parts+1]='消耗'end
    if d.ethereal then parts[#parts+1]='虚无'end
    return table.concat(parts,'。')..'。'
end
function M.onUse(state,definition)
    if definition.dontTriggerOnUseCard then return end
    local p=state.player
    if (p.statuses.panache or 0)>0 then
        p.statuses.panache=p.statuses.panache-1
        if p.statuses.panache==0 then
            p.statuses.panache=5
            return {op='damageAll',value=state.colorlessPanacheDamage,fixed=true}
        end
    end
end
function M.startTurn(state,onlyReset)
    local p=state.player
    if p.statuses.panache then p.statuses.panache=5 end
    if onlyReset then return end
    for _,id in ipairs(Actors.powerSequence(p,{'magnetism','mayhem'}))do
        actions().enqueue(state,e(id=='magnetism'and 'generateColorless'or 'mayhem',p.statuses[id]))
    end
end
function M.endOwnerTurn(state,actor)
    if (actor.statuses.shackled or 0)>0 then
        local amount=actor.statuses.shackled
        Actors.applyPower(state,actor,'strength',amount,actor)
        actor.statuses.shackled=nil;require('abyss_power_schedule').remove(state,actor,'shackled')
    end
    if actor~=state.player then return end
    for _,bomb in ipairs(state.colorlessBombs or {})do
        if bomb.turns>0 then
            bomb.turns=bomb.turns-1;actor.statuses[bomb.id]=bomb.turns>0 and bomb.turns or nil
            if bomb.turns==0 then actions().enqueue(state,{op='damageAll',value=bomb.damage,fixed=true})end
        end
    end
end
function M.debuffApplied(state,target,id,amount,source)
    local n=state.player.statuses.sadistic_nature or 0
    if n<=0 or source~=state.player or target==state.player or id=='shackled'then return end
    local debuff=target.statusDefinitions[id].kind=='debuff'or (id=='strength'or id=='dexterity')and amount<=0
    if debuff then actions().enqueue(state,{op='colorless',kind='sadisticDamage',value=n},state.player,target)end
end
local function remove(pile,uid)
    for i,c in ipairs(pile)do if c.uid==uid then return table.remove(pile,i)end end
end
local function pool(state,kind)
    local result={}
    if kind=='colorless'then
        for _,id in ipairs(state.sourcePools.srcColorless)do if not state.catalog.cards[id].healing then result[#result+1]=id end end
    else
        for _,rarity in ipairs({'common','uncommon','rare'})do
            for _,id in ipairs(assert(state.sourcePools.src[rarity]))do
                local d=state.catalog.cards[id]
                if d.type==kind and not d.healing then result[#result+1]=id end
            end
        end
    end
    assert(#result>0,'missing complete generation pool');return result
end
local function generate(combat,state,kind,count,pile,upgraded,permanentZero,turnZero)
    local ids=pool(state,kind)
    local generated={}
    for _=1,count do
        local c=actions().fresh(combat,state,ids[combat.cardRandom(state,#ids)])
        if upgraded or (state.player.statuses.master_reality or 0)>0 then combat.upgrade(state,c)end
        if permanentZero and combat.combatBaseCost(state,c)>0 then c.costOverride=0;c.costForTurn=0
        elseif turnZero then c.costForTurn=0 end
        generated[#generated+1]=c
    end
    -- Card.use selects the whole batch before queued draw-pile insertions
    -- consume cardRandomRng. Interleaving them changes subsequent card IDs.
    for _,c in ipairs(generated)do
        if pile=='draw'then
            if #state.draw==0 then state.draw[1]=c else table.insert(state.draw,combat.cardRandom(state,#state.draw),c)end
        else actions().toHand(state,c)end
    end
end
local function eligible(state,kind,cardType)
    local result={};local pile=kind=='secret'and state.draw or state.hand
    for _,c in ipairs(pile)do if not cardType or state.catalog.cards[c.cardId].type==cardType then result[#result+1]=c.uid end end
    return result
end
local function secretOrder(state,uids)
    local ordered={}
    for _,uid in ipairs(uids)do
        if #ordered==0 then ordered[1]=uid
        else table.insert(ordered,Random.randomInt(state.cardRandomRng,#ordered-1)+1,uid)end
    end
    return ordered
end
local function applySelected(combat,state,item,uid)
    local kind=item.effect.kind
    if kind=='secret'then actions().toHand(state,assert(remove(state.draw,uid),'stale secret choice'))
    elseif kind=='purity'then
        local c=assert(remove(state.hand,uid),'stale purity choice');actions().exhaust(combat,state,c)
    elseif kind=='forethought'then
        local c=assert(remove(state.hand,uid),'stale forethought choice')
        if combat.combatBaseCost(state,c)>0 then c.freeToPlayOnce=true end
        table.insert(state.draw,1,c)
    end
end
local function select(combat,state,item)
    local effect=item.effect;local uids=eligible(state,effect.kind,effect.cardType)
    if #uids==0 then return end
    -- Source CardGroup.addToRandomSpot runs once when the action opens, never
    -- while validating the cached choice or redrawing its view.
    if effect.kind=='secret'then uids=secretOrder(state,uids)end
    local multiple=effect.kind=='purity'or effect.kind=='forethought'and effect.value==1
    if #uids==1 and not multiple then return applySelected(combat,state,item,uids[1])end
    state.choiceSerial=(state.choiceSerial or 0)+1
    state.pendingChoice={op='colorless',token=state.choiceSerial,uids=uids,item=item,
        multiple=multiple,selected={},maximum=effect.kind=='purity'and effect.value or nil}
end
function M.choose(combat,state,token,uid)
    local choice=state.pendingChoice
    if not choice or choice.op~='colorless'or choice.token~=token then return false,'stale_card_choice'end
    local valid={};for _,id in ipairs(eligible(state,choice.item.effect.kind,choice.item.effect.cardType))do valid[id]=true end
    for _,id in ipairs(choice.selected)do if not valid[id]then return false,'stale_card_choice'end end
    if choice.multiple and uid==0 then
        state.pendingChoice=nil
        for _,id in ipairs(choice.selected)do applySelected(combat,state,choice.item,id)end
        actions().drain(combat,state);return true
    end
    if not valid[uid]then return false,'invalid_card_choice'end
    if not choice.multiple then
        state.pendingChoice=nil;applySelected(combat,state,choice.item,uid);actions().drain(combat,state);return true
    end
    for i,id in ipairs(choice.selected)do if id==uid then
        table.remove(choice.selected,i);state.choiceSerial=state.choiceSerial+1;choice.token=state.choiceSerial;return true
    end end
    if choice.maximum and #choice.selected>=choice.maximum then return false,'invalid_card_choice'end
    choice.selected[#choice.selected+1]=uid;state.choiceSerial=state.choiceSerial+1;choice.token=state.choiceSerial;return true
end
local function growBattleInstances(state,original,amount)
    local seen={}
    local uuid=original.uuid or original.uid
    local function grow(c)
        if c and not seen[c] and (c.uuid or c.uid)==uuid then
            seen[c]=true;c.misc=(c.misc or 15)+amount
        end
    end
    grow(original);grow(state.cardInUse)
    for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust})do for _,c in ipairs(pile)do grow(c)end end
    for _,queued in ipairs(state.queuedCards or {})do grow(queued.card)end
    for _,queued in ipairs(state.cardActions or {})do grow(queued.instance)end
end
local actionHandlers={}
function actionHandlers.apotheosis(combat,state)
    for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust})do for _,c in ipairs(pile)do combat.upgrade(state,c)end end
end
function actionHandlers.shackles(_,state,item,a)
    local target=item.target;local artifact=(target.statuses.artifact or 0)>0
    Actors.applyPower(state,target,'strength',-a.value,state.player)
    if not artifact then Actors.applyPower(state,target,'shackled',a.value,state.player)end
end
function actionHandlers.impatience(combat,state,_,a)
    for _,c in ipairs(state.hand)do if state.catalog.cards[c.cardId].type=='attack'then return end end
    combat.draw(state,a.value)
end
function actionHandlers.enlightenment(combat,state,_,a)
    for _,c in ipairs(state.hand)do
        if combat.cardDefinition(state,c).cost>1 then c.costForTurn=1 end
        if a.value==1 and combat.combatBaseCost(state,c)>1 then c.costOverride=1 end
    end
end
function actionHandlers.discovery(_,state)
    require('abyss_card_actions').enqueueReaction(state,{op='discover',value=1,exclude='discovery'},true)
end
actionHandlers.purity=select
actionHandlers.secret=select
actionHandlers.forethought=select
function actionHandlers.madness(combat,state)
    local better,possible=false,false
    for _,c in ipairs(state.hand)do
        if combat.cardDefinition(state,c).cost>0 then better=true end
        if combat.combatBaseCost(state,c)>0 then possible=true end
    end
    if better or possible then
        local c
        repeat c=state.hand[combat.cardRandom(state,#state.hand)]until (better and combat.cardDefinition(state,c).cost or combat.combatBaseCost(state,c))>0
        c.costOverride,c.costForTurn=0,0
    end
end
function actionHandlers.generateColorless(combat,state,_,a)
    generate(combat,state,'colorless',a.value,'hand')
end
function actionHandlers.generateDraw(combat,state,_,a)
    generate(combat,state,a.cardType,a.value,'draw',false,true)
end
function actionHandlers.transmutation(combat,state,_,a)
    local n=a.energyOnUse or 0
    for _,id in ipairs(state.relics or {})do if id=='chemical_x'or id=='Chemical X'then n=n+2 end end
    generate(combat,state,'colorless',n,'hand',a.value==1,false,true)
end
function actionHandlers.deepBreath(_,state)
    if #state.discard>0 then
        -- Constructor callbacks queue their effects before EmptyDeck/Shuffle/
        -- Draw. Collect in held order; reverse TOP insertion preserves it.
        local effects={};local uncommon,shop=require('abyss_relic_family_combat').uncommon,require('abyss_relic_family_combat').shop
        local uncommonQueries=require('abyss_relic_queries').uncommon
        local shopQueries=require('abyss_relic_queries').shop
        for _,id in ipairs(state.relics or {})do
            if uncommonQueries.localId(id)=='sundial'then
                for _,effect in ipairs(uncommon.onShuffle(state))do effects[#effects+1]=effect end
            elseif shopQueries.localId(id)=='the_abacus'then effects[#effects+1]=shop.onShuffle(state,true)end
        end
        actions().enqueueReaction(state,e('deepBreathShuffle'),true)
        for i=#effects,1,-1 do actions().enqueueReaction(state,effects[i],true)end
    end
end
function actionHandlers.deepBreathShuffle(_,state)
    Random.shuffle(assert(state.shuffleRng,'Deep Breath needs shuffle stream'),state.discard)
    -- Soul.shuffle immediately appends iterator-order cards to old draw.
    for _,c in ipairs(state.discard)do state.draw[#state.draw+1]=c end;state.discard={}
    -- ShuffleAction(draw,false) spends a second long, without callbacks.
    Random.shuffle(assert(state.shuffleRng,'Deep Breath needs shuffle stream'),state.draw)
end
function actionHandlers.violence(combat,state,_,a)
    local tmp={}
    for _,c in ipairs(state.draw)do if state.catalog.cards[c.cardId].type=='attack'then
        if #tmp==0 then tmp[1]=c else table.insert(tmp,combat.cardRandom(state,#tmp),c)end
    end end
    for _=1,a.value do if #tmp>0 then
        Random.shuffle(assert(state.shuffleRng,'Violence needs shuffle stream'),tmp)
        local c=table.remove(tmp,1);remove(state.draw,c.uid);actions().toHand(state,c)
    end end
end
function actionHandlers.panache(_,state,_,a)
    if not state.player.statuses.panache then Actors.applyPower(state,state.player,'panache',5,state.player)end
    state.colorlessPanacheDamage=(state.colorlessPanacheDamage or 0)+a.value
    state.player.panacheDamage=state.colorlessPanacheDamage
end
function actionHandlers.bomb(_,state,_,a)
    state.colorlessBombs=state.colorlessBombs or {}
    local id='colorless_bomb_'..(#state.colorlessBombs+1)
    state.player.statusDefinitions[id]={id=id,name='延时爆破',kind='buff',stack='duration',decay='none',description='到期造成'..a.value..'点伤害。'}
    Actors.applyPower(state,state.player,id,3,state.player)
    state.colorlessBombs[#state.colorlessBombs+1]={id=id,turns=3,damage=a.value}
    state.player.colorlessBombs=state.colorlessBombs
end
function actionHandlers.mayhem(_,state,_,a)
    actions().enqueue(state,e('mayhemPlay',a.value))
end
function actionHandlers.mayhemPlay(combat,state,_,a)
    for _=1,a.value do
        local live={};for i,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then live[#live+1]=i end end
        if #live>0 then combat.autoplayTop(state,live[combat.cardRandom(state,#live)],false,true)
        elseif not combat.outcome(state)then combat.autoplayTop(state,nil,false,true)end
    end
end
function actionHandlers.sadisticDamage(combat,state,item,a)
    combat.damage(state,state.player,item.target,a.value,true)
end
local function eligibleKill(target,before)
    return before>0 and target.hp<=0 and not target.escaped and not target.halfDead and not target.minion and (target.statuses.minion or 0)<=0
end
local function rewardGreed(combat,state,a)
    if not require('abyss_relic_queries').hooks.owns(state,'ectoplasm')then
        state.player.gold=state.player.gold+a.value
        if state.scoreStats then state.scoreStats.goldGained=state.scoreStats.goldGained+a.value end
        require('abyss_act2_event_relics').gainGold(state,a.value,function(n)
            return actions().apply(combat,state,{effect={op='heal',value=n},source=state.player})
        end)
        require('abyss_events').emit(state,'gold',{amount=a.value,source='hand_of_greed'})
    end
end
local function growRitual(state,item,a)
    local c=item.instance;growBattleInstances(state,c,a.value)
    state.ritualDaggerGrowth=state.ritualDaggerGrowth or {}
    local key=c.deckUid
    if key then state.ritualDaggerGrowth[key]=(state.ritualDaggerGrowth[key]or 0)+a.value end
end
local function resolveKill(combat,state,item,a,kind)
    local target=item.target;local before=target.hp
    combat.damage(state,state.player,target,a.damage or a.value,nil,nil,a.resolved and a.resolved[target.id])
    if eligibleKill(target,before) then
        if kind=='greed'then rewardGreed(combat,state,a)
        else growRitual(state,item,a)end
    end
end
actionHandlers.greed=resolveKill
actionHandlers.ritual=resolveKill
function M.apply(combat,state,item)
    local a=item.effect;local kind=a.kind
    local handler=actionHandlers[kind]
    if not handler then error('unimplemented colorless action: '..tostring(kind))end
    return handler(combat,state,item,a,kind)
end
return M
