-- Run-only catalogue assembly. Historical Profile.prepare remains independent.
local Copy=require('abyss_copy')
local Profiles=require('abyss_character_profiles')
local RedContract=require('abyss_run_red_card_contract')
local M={}
local colors={ironclad='red',silent='green',defect='blue',watcher='purple'}
-- Survivor's historical component lacks sourceId/sts_name. Fixed registration
-- cards/green/Survivor.java supplies this basic identity (outside its71 pool).
local basicSourceIds={survivor='Survivor'}
local native={armaments=true,havoc=true,sword_boomerang=true,dual_wield=true,infernal_blade=true,
 searing_blow=true,double_tap=true,feed=true,juggernaut=true}
local constantComponents
local function components()
 if not constantComponents then
  -- Compile only module-authored constants from an empty scaffold. Never read
  -- any caller here: rules/cards/statuses and extension graphs are read anew
  -- below. These private constants are never returned or installed by alias.
  local compiled={}
  for _,id in ipairs({'silent','defect','watcher'})do
   compiled[id]=Profiles.prepare({rules={player={}},cards={cards={}},
    statuses={statuses={}},relics={relics={}},potions={potions={}}},id)
  end
  constantComponents=compiled
 end
 return constantComponents
end
local function carrier(data)
 -- Fact builders need these dependencies only. Do not repeatedly copy enemies,
 -- events, presentation or caller extension graphs through every component.
 return {rules={player=data.rules.player},cards={cards=data.cards.cards},
  statuses={statuses=data.statuses.statuses},relics={relics=data.relics.relics},potions={potions=data.potions.potions}}
end
local function red(data)
 local out=require('abyss_warrior_cards').withFoundationCards(carrier(data))
 out=require('abyss_warrior_exhaust_cards').withCards(out)
 out=require('abyss_warrior_strength_cards').withCards(out)
 out=require('abyss_card_triggers').withCards(out,'ironclad')
 out=require('abyss_warrior_status_cards').withCards(out)
 return require('abyss_retrieval_cards').withCards(out,'ironclad')
end
local function regular(c)return c.type~='status'and c.type~='curse'and c.rarity~='special'end
local function metadata(data)
 local result=Copy.copy(data.cards.sourcePools and data.cards.sourcePools.cardSourceMetadata or {})
 for _,c in ipairs(data.cards.cards)do if not result[c.id]then
  result[c.id]={sourceId=c.sourceId or c.sts_name or basicSourceIds[c.id]or c.id,type=c.type,rarity=c.rarity,healing=c.healing==true}
 end end
 return result
end
local foreignCards,foreignMetadata,ruleKeys
local words={id=true,sourceId=true,sts_name=true,name=true,color=true,text=true,upgradeText=true,healing=true}
local function authoredCards()
 if not foreignCards then
  foreignCards,foreignMetadata,ruleKeys={},{},{target=true,runNativeABI=true}
  for _,id in ipairs({'silent','defect','watcher'})do
   local provider=components()[id];local facts=metadata(provider)
   for _,c in ipairs(provider.cards.cards)do if regular(c)then
    foreignCards[c.id]=c;foreignMetadata[c.id]=facts[c.id]
    for k in pairs(c)do if not words[k]then ruleKeys[k]=true end end
   end end
  end
 end
 return foreignCards,foreignMetadata
end
local function same(a,b)
 if type(a)~='table'or type(b)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function validateForeign(card)
 local authored,facts=authoredCards();local expected=authored[card.id]
 if not expected then return end
 for k in pairs(ruleKeys)do assert(same(card[k],expected[k]),'incompatible caller foreign card: '..card.id..'.'..k)end
 local fact=facts[card.id]
 assert((card.sourceId==nil or card.sourceId==fact.sourceId)and(card.color==nil or card.color==expected.color)
  and(card.healing==nil or card.healing==fact.healing),'incompatible caller foreign identity: '..card.id)
end
local function canonicalForeign(card)
 local expected=foreignCards[card.id];local fact=foreignMetadata[card.id]
 card.color,card.sourceId,card.healing=expected.color,fact.sourceId,fact.healing==true or nil
 for k in pairs(words)do if card[k]==nil and expected[k]~=nil then card[k]=Copy.copy(expected[k])end end
 return card
end
local function statusCompatible(a,b)
 local function priority(s)return s.priority or(s.id=='intangible'and 75 or 5)end
 return a.kind==b.kind and a.stack==b.stack and a.decay==b.decay and priority(a)==priority(b)
end
local nativeRuleKeys={'condition','cost','costMode','effects','ethereal','exhaust','exhaustEnergy','healing','innate',
 'rarity','repeatable','strengthMultiplier','strikeBonus','strikeTag','target','type','upgrade'}
local function adoptRed(current,definition)
 -- Adapt the SAME private source object: directory aliases retain their
 -- identity, while runtime ABI fields follow the existing red adapter chain.
 for _,key in ipairs(nativeRuleKeys)do current[key]=Copy.copy(definition[key])end
 for key in pairs(ruleKeys)do if not words[key]then current[key]=Copy.copy(definition[key])end end
 return current
end
local function fillList(target,entries)
 for i=#target,1,-1 do target[i]=nil end
 for i,value in ipairs(entries)do target[i]=value end
end
function M.prepareSelected(source,id)
 -- The historical factory reads the CURRENT five content branches. Its plain
 -- tree builders never receive unrelated caller graph extensions. Preserve
 -- those with the existing graph-copy owner, including cycles and aliases.
 local input=carrier(source);local template=components()[id]
 if template then
  local generated={};for _,s in ipairs(template.statuses.statuses)do generated[s.id]=s end
  input.statuses={statuses={}}
  for _,s in ipairs(source.statuses.statuses)do
   if generated[s.id]then assert(statusCompatible(s,generated[s.id]),'incompatible caller Power: '..s.id)
   else input.statuses.statuses[#input.statuses.statuses+1]=s end
  end
 end
 local prepared,profile=Profiles.prepare(input,id)
 local out=Copy.copy(source);local current,currentStatuses={},{}
 for i,c in ipairs(out.cards.cards)do current[i]=c end
 for i,s in ipairs(out.statuses.statuses)do currentStatuses[i]=s end
 for k,v in pairs(prepared)do
  if k=='cards'or k=='rules'or k=='statuses'or k=='relics'or k=='potions'then
   for field,value in pairs(v)do
    if k=='cards'and field=='cards'or k=='statuses'and field=='statuses'then fillList(out[k][field],value)
    elseif field=='sourcePools'and out[k][field]then
     for pool,entries in pairs(value)do out[k][field][pool]=entries end
    else out[k][field]=value end
   end
  else out[k]=v end
 end
 local positions={};for i,c in ipairs(out.cards.cards)do positions[c.id]=i end
 local authored=authoredCards()
 for _,c in ipairs(current)do
  if authored[c.id]then
   validateForeign(c);local at=positions[c.id]or #out.cards.cards+1
   out.cards.cards[at]=canonicalForeign(c);positions[c.id]=at
  elseif regular(c)and(not c.color or c.color=='red')then
   local at=positions[c.id]or #out.cards.cards+1
   out.cards.cards[at]=positions[c.id]and adoptRed(c,out.cards.cards[at])or c;positions[c.id]=at
  end
 end
 positions={};for i,s in ipairs(out.statuses.statuses)do positions[s.id]=i end
 for _,s in ipairs(currentStatuses)do
  local at=positions[s.id]
  assert(not at or statusCompatible(s,out.statuses.statuses[at]),'incompatible caller Power: '..s.id)
  out.statuses.statuses[at or #out.statuses.statuses+1]=s
 end
 return out,profile
end
function M.prepare(source,selected,character,owned)
 assert(not selected.originalV4Role,'original V4 does not use the STS catalogue assembler')
 character=character or 'ironclad';assert(colors[character],'unknown Run catalogue character')
 -- Own the caller graph once. Factory-owned selected graphs are already private.
 local out=owned and selected or Copy.copy(selected)
 local authored,facts=authoredCards()
 local overrides={}
 for _,c in ipairs(source.cards.cards)do
  if authored[c.id]then validateForeign(c);overrides[c.id]=true
  elseif character~='ironclad'and RedContract.isRed(c.id)then
   assert((not c.color or c.color=='red')and RedContract.matches(c,ruleKeys),'incompatible caller foreign card: '..c.id)
  end
 end
 local providers={ironclad=red(source)}
 local constants=components()
 for _,id in ipairs({'silent','defect','watcher'})do
  providers[id]=character==id and out or constants[id]
 end
 local sourceMeta=metadata(source)
 local cards,positions,statuses,potions={},{},{},{}
 for _,c in ipairs(out.cards.cards)do cards[#cards+1]=c;assert(not positions[c.id],'duplicate caller card');positions[c.id]=#cards end
 for _,s in ipairs(out.statuses.statuses)do assert(not statuses[s.id],'duplicate caller Power');statuses[s.id]=s end
 for _,p in ipairs(out.potions.potions)do potions[p.id]=true end
 local allMeta=Copy.copy(out.cards.sourcePools and out.cards.sourcePools.cardSourceMetadata or {})
 for _,id in ipairs({'ironclad','silent','defect','watcher'})do
  local provider=providers[id];local meta=id=='ironclad'and sourceMeta or metadata(provider)
  local count=0
  for _,value in ipairs(provider.cards.cards)do
   local isRegular=regular(value)
   -- Non-red providers retain only their own cards plus shared state/derived
   -- dependencies. Never borrow another provider's rules, pool or starter.
   if not isRegular or id=='ironclad'and not authored[value.id]and(not value.color or value.color=='red')or value.color==colors[id]then
    local at=positions[value.id]
    local c
    if overrides[value.id]and at then c=canonicalForeign(cards[at])
    elseif id=='ironclad'and isRegular and at then c=adoptRed(cards[at],value)
    else c=Copy.copy(value)end
    if isRegular then
     count=count+1;c.color=colors[id]
     local fact=assert(facts[c.id]or meta[c.id],'missing source card metadata')
     assert(c.type==fact.type and c.rarity==fact.rarity,'incompatible source card type/rarity: '..c.id)
     c.sourceId=fact.sourceId;c.healing=fact.healing==true or nil
     c.runNativeABI=native[c.id]or nil
     allMeta[c.id]=Copy.copy(fact)
    end
    if isRegular or not at or c.id=='burn'and c.burnDamage~=nil then
     at=at or #cards+1;cards[at]=c;positions[c.id]=at
    end
   end
  end
  assert(count==75,'incomplete '..id..' Run catalogue: '..count)
  for _,s in ipairs(provider.statuses.statuses)do
   local old=statuses[s.id]
   assert(not old or statusCompatible(old,s),'incompatible shared Power: '..s.id)
   if not old then statuses[s.id]=Copy.copy(s)end
  end
  for _,p in ipairs(provider.potions.potions)do if not potions[p.id]then
   out.potions.potions[#out.potions.potions+1]=Copy.copy(p);potions[p.id]=true
  end end
 end
 -- Source IntangiblePlayerPower has priority75; Colorless's historical
 -- shared definition may omit it. Rage's explicit priority is default5.
 if statuses.intangible then statuses.intangible.priority=75 end
 if statuses.rage then statuses.rage.priority=5 end
 local burn=cards[assert(positions.burn,'missing shared Burn')]
 assert(burn.burnDamage==2 and burn.upgrade and burn.upgrade.burnDamage==4,'shared Burn must preserve its real upgrade')
 burn.sourceId='Burn'
 fillList(out.cards.cards,cards)
 local ordered,ids={},{};for id in pairs(statuses)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do ordered[#ordered+1]=statuses[id]end
 fillList(out.statuses.statuses,ordered)
 out.cards.sourcePools=out.cards.sourcePools or {};out.cards.sourcePools.cardSourceMetadata=allMeta
 out.runCardCatalog=true;out.runCardCharacter=character
 return out
end
return M
