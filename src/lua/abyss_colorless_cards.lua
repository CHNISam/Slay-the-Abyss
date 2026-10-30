-- PC 2.3.4 factual card rules, fixed319009. No source bodies or assets copied.
-- Shared cards are registered after character preparation; class pools stay intact.
local Actors=require('abyss_actor')
local Random=require('abyss_sts_random')
local M={}
local copy=require('abyss_copy').copy
local function e(kind,value,extra)
    local out={op='colorless',kind=kind,value=value or 0}
    for k,v in pairs(extra or {})do out[k]=v end
    return out
end
local function fx(op,n,status)return {op=op,value=n,status=status}end
local cards={}
local function card(id,name,source,kind,rarity,cost,effects,upgrade,extra)
    local d={id=id,name=name,sts_name=source,sourceId=source,color='colorless',type=kind,rarity=rarity,
        cost=cost,target='SELF',effects=effects,upgrade=upgrade or {},colorlessNative=true}
    for k,v in pairs(extra or {})do d[k]=v end
    cards[#cards+1]=d;return d
end
card('swift_strike','迅击','Swift Strike','attack','uncommon',0,{fx('damage',7)},{effects={fx('damage',10)}},{target='ENEMY',strikeTag=true,sourceTags={'STRIKE'}})
card('flash_of_steel','钢铁闪光','Flash of Steel','attack','uncommon',0,{fx('damage',3),fx('draw',1)},{effects={fx('damage',6),fx('draw',1)}},{target='ENEMY'})
card('dramatic_entrance','华丽登场','Dramatic Entrance','attack','uncommon',0,{fx('damageAll',8)},{effects={fx('damageAll',12)}},{target='ALL_ENEMY',innate=true,exhaust=true})
card('good_instincts','本能','Good Instincts','skill','uncommon',0,{fx('block',6)},{effects={fx('block',9)}})
card('finesse','巧技','Finesse','skill','uncommon',0,{fx('block',2),fx('draw',1)},{effects={fx('block',4),fx('draw',1)}})
card('bandage_up','包扎','Bandage Up','skill','uncommon',0,{fx('heal',4)},{effects={fx('heal',6)}},{healing=true,exhaust=true})
card('panacea','灵药','Panacea','skill','uncommon',0,{fx('gainStatus',1,'artifact')},{effects={fx('gainStatus',2,'artifact')}},{exhaust=true})
card('blind','致盲','Blind','skill','uncommon',0,{fx('applyStatus',2,'weak')},{target='ALL_ENEMY',effects={fx('applyStatusAll',2,'weak')}},{target='ENEMY'})
card('trip','绊倒','Trip','skill','uncommon',0,{fx('applyStatus',2,'vulnerable')},{target='ALL_ENEMY',effects={fx('applyStatusAll',2,'vulnerable')}},{target='ENEMY'})
card('master_of_strategy','运筹','Master of Strategy','skill','rare',0,{fx('draw',3)},{effects={fx('draw',4)}},{exhaust=true})
card('apotheosis','升华','Apotheosis','skill','rare',2,{e('apotheosis')},{cost=1},{exhaust=true})
card('dark_shackles','暗缚','Dark Shackles','skill','uncommon',0,{e('shackles',9)},{effects={e('shackles',15)}},{exhaust=true,target='ENEMY'})
card('deep_breath','深呼吸','Deep Breath','skill','uncommon',0,{e('deepBreath'),fx('draw',1)},{effects={e('deepBreath'),fx('draw',2)}})
-- Discovery retains the shared-character action owner while using the complete
-- colorless definition and its presentation adapter.
card('discovery','发现','Discovery','skill','uncommon',1,{e('discovery')},{exhaust=false},{exhaust=true,colorlessSharedOwner=true})
card('enlightenment','启迪','Enlightenment','skill','uncommon',0,{e('enlightenment')},{effects={e('enlightenment',1)}})
card('forethought','远虑','Forethought','skill','uncommon',0,{e('forethought')},{effects={e('forethought',1)}})
card('impatience','急切','Impatience','skill','uncommon',0,{e('impatience',2)},{effects={e('impatience',3)}})
card('jack_of_all_trades','百艺','Jack Of All Trades','skill','uncommon',0,{e('generateColorless',1)},{effects={e('generateColorless',2)}},{exhaust=true})
card('madness','狂念','Madness','skill','uncommon',1,{e('madness')},{cost=0},{exhaust=true})
card('mind_blast','念爆','Mind Blast','attack','uncommon',2,{fx('damage',0)},{cost=1},{innate=true,target='ENEMY'})
card('panic_button','紧急防御','PanicButton','skill','uncommon',0,{fx('block',30),fx('gainStatus',2,'no_block')},{effects={fx('block',40),fx('gainStatus',2,'no_block')}},{exhaust=true})
card('purity','澄净','Purity','skill','uncommon',0,{e('purity',3)},{effects={e('purity',5)}},{exhaust=true})
card('chrysalis','蝶化','Chrysalis','skill','rare',2,{e('generateDraw',3,{cardType='skill'})},{effects={e('generateDraw',5,{cardType='skill'})}},{exhaust=true})
card('metamorphosis','蜕变','Metamorphosis','skill','rare',2,{e('generateDraw',3,{cardType='attack'})},{effects={e('generateDraw',5,{cardType='attack'})}},{exhaust=true})
card('hand_of_greed','贪欲之手','HandOfGreed','attack','rare',2,{e('greed',20)},{effects={e('greed',25)}},{target='ENEMY'})
card('magnetism','磁引','Magnetism','power','rare',2,{fx('gainStatus',1,'magnetism')},{cost=1})
card('mayhem','混沌','Mayhem','power','rare',2,{fx('gainStatus',1,'mayhem')},{cost=1})
card('panache','声势','Panache','power','rare',0,{e('panache',10)},{effects={e('panache',14)}})
card('sadistic_nature','苦痛天性','Sadistic Nature','power','rare',0,{fx('gainStatus',5,'sadistic_nature')},{effects={fx('gainStatus',7,'sadistic_nature')}})
card('secret_technique','秘技','Secret Technique','skill','rare',0,{e('secret',1,{cardType='skill'})},{exhaust=false},{exhaust=true})
card('secret_weapon','秘武','Secret Weapon','skill','rare',0,{e('secret',1,{cardType='attack'})},{exhaust=false},{exhaust=true})
card('the_bomb','延时爆破','The Bomb','skill','rare',2,{e('bomb',40)},{effects={e('bomb',50)}})
card('thinking_ahead','先思','Thinking Ahead','skill','rare',0,{fx('draw',2),fx('handToDraw',1)},{exhaust=false},{exhaust=true})
card('transmutation','转化','Transmutation','skill','rare',-1,{e('transmutation')},{effects={e('transmutation',1)}},{costMode='all_energy',exhaust=true})
card('violence','猛袭','Violence','skill','rare',0,{e('violence',3)},{effects={e('violence',4)}},{exhaust=true})
card('apparition','幻影','Ghostly','skill','special',1,{fx('gainStatus',1,'intangible')},{ethereal=false},{sts_name='Apparition',exhaust=true,ethereal=true})
card('bite','噬咬','Bite','attack','special',1,{fx('damage',7),fx('heal',2)},{effects={fx('damage',8),fx('heal',3)}},{target='ENEMY',healing=true})
card('jax','激素','J.A.X.','skill','special',0,{fx('loseHp',3),fx('gainStatus',2,'strength')},{effects={fx('loseHp',3),fx('gainStatus',3,'strength')}})
card('ritual_dagger','仪式匕首','RitualDagger','attack','special',1,{e('ritual',3,{damage=15})},{effects={e('ritual',5,{damage=15})}},{target='ENEMY',exhaust=true})
local raw='dark_shackles sadistic_nature panic_button trip dramatic_entrance impatience the_bomb blind bandage_up secret_technique deep_breath violence panache secret_weapon apotheosis mayhem hand_of_greed flash_of_steel forethought enlightenment purity panacea transmutation chrysalis discovery finesse magnetism master_of_strategy good_instincts swift_strike jack_of_all_trades metamorphosis mind_blast thinking_ahead madness'
local src='madness thinking_ahead mind_blast metamorphosis jack_of_all_trades swift_strike good_instincts master_of_strategy magnetism finesse discovery chrysalis transmutation panacea purity enlightenment forethought flash_of_steel hand_of_greed mayhem apotheosis secret_weapon panache violence deep_breath secret_technique bandage_up blind the_bomb impatience dramatic_entrance trip panic_button sadistic_nature dark_shackles'
local function words(s)local a={};for id in s:gmatch('%S+')do a[#a+1]=id end;return a end
-- These source facts are immutable module data. Sort once, then give every
-- registration its own graph copy; no caller sees or can change the template.
local poolTemplate={srcColorless=words(src),colorlessRaw=words(raw),colorlessShop={uncommon={},rare={}}}
do
    local byId={}
    for _,d in ipairs(cards)do
        byId[d.id]=d.sourceId
        local pool=poolTemplate.colorlessShop[d.rarity]
        if pool then pool[#pool+1]=d.id end
    end
    for _,pool in pairs(poolTemplate.colorlessShop)do
        table.sort(pool,function(a,b)return byId[a]:lower()<byId[b]:lower()end)
    end
end
local powerNames={panache='声势',shackled='力量恢复',no_block='无法格挡',intangible='无实体',magnetism='磁引',mayhem='混沌',sadistic_nature='苦痛天性'}
local powerIcons={panache='strength',no_block='frail',intangible='barricade',magnetism='draw_next_turn',mayhem='thousand_cuts',sadistic_nature='poison'}
function M.powerIcon(id)
    return powerIcons[id] or id:match('^colorless_bomb_') and 'combust' or nil
end
function M.powerDescription(actor,id)
    local n=actor.statuses[id]or 0
    if id=='panache'then return '本回合再打出'..n..'张牌，对全体敌人造成'..(actor.panacheDamage or 0)..'点伤害；每次触发及下回合开始重置为5张。'
    elseif id=='shackled'then return '本角色回合结束时恢复'..n..'点力量，随后移除此效果。'
    elseif id=='no_block'then return '卡牌提供的格挡降为0；每轮结束减少1层，当前剩余'..n..'层。'
    elseif id=='intangible'then return '受到的每次伤害与失去生命最多1点；每轮结束减少1层，当前剩余'..n..'层。'
    elseif id=='magnetism'then return '每回合开始时生成'..n..'张随机无色牌加入手牌，排除回复生命的牌。'
    elseif id=='mayhem'then return '每回合开始的正常抽牌后，免费自动打出抽牌堆顶'..n..'张牌。'
    elseif id=='sadistic_nature'then return '向敌人成功施加减益时，造成'..n..'点伤害；力量恢复不触发。'
    elseif id:match('^colorless_bomb_')then
        for _,bomb in ipairs(actor.colorlessBombs or {})do if bomb.id==id then
            return '再经过'..n..'次己方回合结束，对全体敌人造成'..bomb.damage..'点伤害。'
        end end
    end
end
function M.withCards(data,owned)
    if data.colorlessCards then
        local present={};for _,d in ipairs(data.cards.cards)do present[d.id]=true end
        local complete=true;for _,d in ipairs(cards)do if not present[d.id]then complete=false end end
        if complete then return data end
    end
    -- Run's catalogue assembler already owns its complete private graph. Keep
    -- its containers/arrays/maps live while adding these definitions. Public
    -- registration and Combat callers retain the existing detached path.
    local out=data
    if not owned then
        out={};for k,v in pairs(data)do out[k]=v end
        out.cards={};for k,v in pairs(data.cards)do out.cards[k]=v end
        out.cards.cards={};for i,d in ipairs(data.cards.cards)do out.cards.cards[i]=d end
        out.cards.sourcePools=copy(data.cards.sourcePools or {})
        out.statuses={};for k,v in pairs(data.statuses)do out.statuses[k]=v end
        out.statuses.statuses={};for i,d in ipairs(data.statuses.statuses)do out.statuses.statuses[i]=d end
    end
    local seen={}
    for _,d in ipairs(out.cards.cards)do seen[d.id]=true end
    for _,d in ipairs(cards)do if not seen[d.id]then out.cards.cards[#out.cards.cards+1]=copy(d)end end
    for key,value in pairs(copy(poolTemplate))do out.cards.sourcePools[key]=value end
    local present={};for _,d in ipairs(out.statuses.statuses)do present[d.id]=true end
    for id,kind in pairs({panache='buff',shackled='debuff',no_block='debuff',intangible='buff',magnetism='buff',mayhem='buff',sadistic_nature='buff'})do
        if not present[id]then out.statuses.statuses[#out.statuses.statuses+1]={id=id,name=powerNames[id],description=M.powerDescription({statuses={[id]=1}},id),kind=kind,
            stack='intensity',decay=(id=='no_block'or id=='intangible')and 'round_end_minus_1'or 'none'}end
    end
    out.colorlessCards=true;return out
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
function M.apply(combat,state,item)
    local a=item.effect;local kind=a.kind
    if kind=='apotheosis'then
        for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust})do for _,c in ipairs(pile)do combat.upgrade(state,c)end end
    elseif kind=='shackles'then
        local target=item.target;local artifact=(target.statuses.artifact or 0)>0
        Actors.applyPower(state,target,'strength',-a.value,state.player)
        if not artifact then Actors.applyPower(state,target,'shackled',a.value,state.player)end
    elseif kind=='impatience'then
        for _,c in ipairs(state.hand)do if state.catalog.cards[c.cardId].type=='attack'then return end end
        combat.draw(state,a.value)
    elseif kind=='enlightenment'then
        for _,c in ipairs(state.hand)do
            if combat.cardDefinition(state,c).cost>1 then c.costForTurn=1 end
            if a.value==1 and combat.combatBaseCost(state,c)>1 then c.costOverride=1 end
        end
    elseif kind=='discovery'then
        require('abyss_card_actions').enqueueReaction(state,{op='discover',value=1,exclude='discovery'},true)
    elseif kind=='purity'or kind=='secret'or kind=='forethought'then return select(combat,state,item)
    elseif kind=='madness'then
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
    elseif kind=='generateColorless'then generate(combat,state,'colorless',a.value,'hand')
    elseif kind=='generateDraw'then generate(combat,state,a.cardType,a.value,'draw',false,true)
    elseif kind=='transmutation'then
        local n=a.energyOnUse or 0
        for _,id in ipairs(state.relics or {})do if id=='chemical_x'or id=='Chemical X'then n=n+2 end end
        generate(combat,state,'colorless',n,'hand',a.value==1,false,true)
    elseif kind=='deepBreath'then
        if #state.discard>0 then
            for _,c in ipairs(state.discard)do state.draw[#state.draw+1]=c end;state.discard={}
            Random.shuffle(assert(state.shuffleRng,'Deep Breath needs shuffle stream'),state.draw)
        end
    elseif kind=='violence'then
        local tmp={}
        for _,c in ipairs(state.draw)do if state.catalog.cards[c.cardId].type=='attack'then
            if #tmp==0 then tmp[1]=c else table.insert(tmp,combat.cardRandom(state,#tmp),c)end
        end end
        for _=1,a.value do if #tmp>0 then
            Random.shuffle(assert(state.shuffleRng,'Violence needs shuffle stream'),tmp)
            local c=table.remove(tmp,1);remove(state.draw,c.uid);actions().toHand(state,c)
        end end
    elseif kind=='panache'then
        if not state.player.statuses.panache then Actors.applyPower(state,state.player,'panache',5,state.player)end
        state.colorlessPanacheDamage=(state.colorlessPanacheDamage or 0)+a.value
        state.player.panacheDamage=state.colorlessPanacheDamage
    elseif kind=='bomb'then
        state.colorlessBombs=state.colorlessBombs or {}
        local id='colorless_bomb_'..(#state.colorlessBombs+1)
        state.player.statusDefinitions[id]={id=id,name='延时爆破',kind='buff',stack='duration',decay='none',description='到期造成'..a.value..'点伤害。'}
        Actors.applyPower(state,state.player,id,3,state.player)
        state.colorlessBombs[#state.colorlessBombs+1]={id=id,turns=3,damage=a.value}
        state.player.colorlessBombs=state.colorlessBombs
    elseif kind=='mayhem'then
        actions().enqueue(state,e('mayhemPlay',a.value))
    elseif kind=='mayhemPlay'then
        for _=1,a.value do
            local live={};for i,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then live[#live+1]=i end end
            if #live>0 then combat.autoplayTop(state,live[combat.cardRandom(state,#live)],false,true)
            elseif not combat.outcome(state)then combat.autoplayTop(state,nil,false,true)end
        end
    elseif kind=='sadisticDamage'then combat.damage(state,state.player,item.target,a.value,true)
    elseif kind=='greed'or kind=='ritual'then
        local target=item.target;local before=target.hp
        combat.damage(state,state.player,target,a.damage or a.value,nil,nil,a.resolved and a.resolved[target.id])
        if before>0 and target.hp<=0 and not target.escaped and not target.halfDead and not target.minion and (target.statuses.minion or 0)<=0 then
            if kind=='greed'then
                state.player.gold=state.player.gold+a.value
                require('abyss_events').emit(state,'gold',{amount=a.value,source='hand_of_greed'})
            else
                local c=item.instance;growBattleInstances(state,c,a.value)
                state.ritualDaggerGrowth=state.ritualDaggerGrowth or {}
                local key=c.deckUid
                if key then state.ritualDaggerGrowth[key]=(state.ritualDaggerGrowth[key]or 0)+a.value end
            end
        end
    else error('unimplemented colorless action: '..tostring(kind))end
end
return M
