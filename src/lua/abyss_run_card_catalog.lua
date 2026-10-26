-- Run-only catalogue assembly. Historical Profile.prepare remains independent.
local Copy=require('abyss_copy')
local Profiles=require('abyss_character_profiles')
local M={}
local colors={ironclad='red',silent='green',defect='blue',watcher='purple'}
-- Survivor's historical component lacks sourceId/sts_name. Fixed registration
-- cards/green/Survivor.java supplies this basic identity (outside its71 pool).
local basicSourceIds={survivor='Survivor'}
local native={armaments=true,havoc=true,sword_boomerang=true,dual_wield=true,infernal_blade=true,
 searing_blow=true,double_tap=true,feed=true,juggernaut=true}
local function carrier(data)
 -- Fact builders need these dependencies only. Do not repeatedly copy enemies,
 -- events, presentation or caller extension graphs through every component.
 return {rules=data.rules,cards=data.cards,statuses=data.statuses,relics=data.relics,potions=data.potions}
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
local function statusCompatible(a,b)
 local function priority(s)return s.priority or(s.id=='intangible'and 75 or 5)end
 return a.kind==b.kind and a.stack==b.stack and a.decay==b.decay and priority(a)==priority(b)
end
function M.prepare(source,selected,character,owned)
 assert(not selected.originalV4Role,'original V4 does not use the STS catalogue assembler')
 character=character or 'ironclad';assert(colors[character],'unknown Run catalogue character')
 -- Own the caller graph once. Factory-owned selected graphs are already private.
 local out=owned and selected or Copy.copy(selected)
 local providers={ironclad=red(source)}
 for _,id in ipairs({'silent','defect','watcher'})do
  providers[id]=character==id and out or Profiles.prepare(carrier(source),id)
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
   if not isRegular or id=='ironclad'and(not value.color or value.color=='red')or value.color==colors[id]then
    local c=Copy.copy(value)
    if isRegular then
     count=count+1;c.color=colors[id]
     local fact=assert(meta[c.id],'missing source card metadata')
     assert(c.type==fact.type and c.rarity==fact.rarity,'incompatible source card type/rarity: '..c.id)
     c.sourceId=fact.sourceId;c.healing=fact.healing==true or nil
     c.runNativeABI=native[c.id]or nil
     allMeta[c.id]=Copy.copy(fact)
    end
    local at=positions[c.id]
    if isRegular or not at or c.id=='burn'and c.burnDamage~=nil then
     at=at or #cards+1;cards[at]=c;positions[c.id]=at
    end
   end
  end
  assert(count==75,'incomplete '..id..' Run catalogue: '..count)
  for _,s in ipairs(provider.statuses.statuses)do
   local old=statuses[s.id]
   assert(not old or statusCompatible(old,s),'incompatible shared Power: '..s.id)
   if not old or id=='ironclad'then statuses[s.id]=Copy.copy(s)end
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
 out.cards.cards=cards
 out.statuses.statuses={};local ids={};for id in pairs(statuses)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do out.statuses.statuses[#out.statuses.statuses+1]=statuses[id]end
 out.cards.sourcePools=out.cards.sourcePools or {};out.cards.sourcePools.cardSourceMetadata=allMeta
 out.runCardCatalog=true;out.runCardCharacter=character
 return out
end
return M
