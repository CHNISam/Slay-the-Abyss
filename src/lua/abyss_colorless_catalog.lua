-- Static colorless definitions and registration. No combat runtime ownership.
local copy=require('abyss_copy').copy
local M={}
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
local function alreadyComplete(data)
    if not data.colorlessCards then return false end
    local present={};for _,d in ipairs(data.cards.cards)do present[d.id]=true end
    local complete=true;for _,d in ipairs(cards)do if not present[d.id]then complete=false end end
    return complete
end
local function registrationTarget(data,owned)
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
    return out
end
local function registerCards(out)
    local seen={}
    for _,d in ipairs(out.cards.cards)do seen[d.id]=true end
    for _,d in ipairs(cards)do if not seen[d.id]then out.cards.cards[#out.cards.cards+1]=copy(d)end end
    for key,value in pairs(copy(poolTemplate))do out.cards.sourcePools[key]=value end
end
local function registerStatuses(out)
    local present={};for _,d in ipairs(out.statuses.statuses)do present[d.id]=true end
    for id,kind in pairs({panache='buff',shackled='debuff',no_block='debuff',intangible='buff',magnetism='buff',mayhem='buff',sadistic_nature='buff'})do
        if not present[id]then out.statuses.statuses[#out.statuses.statuses+1]={id=id,name=powerNames[id],description=M.powerDescription({statuses={[id]=1}},id),kind=kind,
            stack='intensity',decay=(id=='no_block'or id=='intangible')and 'round_end_minus_1'or 'none'}end
    end
end
function M.withCards(data,owned)
    if alreadyComplete(data) then return data end
    local out=registrationTarget(data,owned)
    registerCards(out)
    registerStatuses(out)
    out.colorlessCards=true;return out
end
return M
