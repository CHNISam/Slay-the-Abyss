-- Strict source-chest reward identity for the existing Sapphire footer.
-- Canonical encoding is length-delimited, not a probabilistic hash. No effect,
-- RNG or inventory capability is consulted: unavailable base relics may be forgone.
local M={}
local rootFields={items=true,gold=true,relicId=true,relicSourceId=true,relicUnavailable=true,extraRelics=true,sapphireKey=true}
local itemFields={
 gold={kind=true,amount=true,slot=true},
 relic={kind=true,id=true,sourceId=true,requestedId=true,tier=true,available=true,trace=true,origin=true,linkedSlot=true,slot=true},
 sapphire={kind=true,relicId=true,linkedSlot=true,slot=true}}
local function plain(t)return type(t)=='table'and getmetatable(t)==nil end
local function integer(n)return type(n)=='number'and n%1==0 and n>=1 and n<=2147483647 end
local function exact(t,fields)
 if not plain(t)then return false end
 for key in pairs(t)do if not fields[key]then return false end end
 return true
end
local function array(t)
 if not plain(t)then return false end
 local count=0;for key in pairs(t)do if not integer(key)then return false end;count=count+1 end
 return count==#t
end
local function trace(rows)
 if not array(rows)then return false end
 for _,entry in ipairs(rows)do
  if not exact(entry,{tier=true,['end']=true,id=true})or type(entry.tier)~='string'
   or type(entry.id)~='string'or type(entry['end'])~='boolean'then return false end
 end
 return true
end
local function item(row)
 if not plain(row)or not itemFields[row.kind]or not exact(row,itemFields[row.kind])or not integer(row.slot)then return false end
 if row.kind=='gold'then return type(row.amount)=='number'and row.amount%1==0 and row.amount>=0 and row.amount<=2147483647 end
 if row.kind=='sapphire'then return type(row.relicId)=='string'and integer(row.linkedSlot)end
 return type(row.id)=='string'and type(row.sourceId)=='string'and type(row.requestedId)=='string'
  and type(row.tier)=='string'and type(row.available)=='boolean'and type(row.origin)=='string'
  and (row.linkedSlot==nil or integer(row.linkedSlot))and trace(row.trace)
end
local function canonical(value)
 local kind=type(value)
 if kind=='string'then return 's'..#value..':'..value end
 if kind=='number'then return 'n'..string.format('%.0f',value)..';'end
 if kind=='boolean'then return value and 't' or 'f'end
 local keys={};for key in pairs(value)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)return canonical(a)<canonical(b)end)
 local result={'{'};for _,key in ipairs(keys)do result[#result+1]=canonical(key);result[#result+1]=canonical(value[key])end
 result[#result+1]='}';return table.concat(result)
end
function M.pair(reward)
 if not exact(reward,rootFields)or not array(reward.items)then return nil,'treasure_reward_shape_unsupported'end
 local base,key,gold,extra,slots=nil,nil,nil,{},{}
 for _,row in ipairs(reward.items)do
  if not item(row)or slots[row.slot]then return nil,'treasure_reward_shape_unsupported'end
  slots[row.slot]=true
  if row.kind=='gold'then if gold then return nil,'treasure_reward_shape_unsupported'end;gold=row
  elseif row.kind=='sapphire'then if key then return nil,'treasure_reward_shape_unsupported'end;key=row
  elseif row.origin=='base'then if base then return nil,'treasure_reward_shape_unsupported'end;base=row
  elseif row.origin=='boss'then return nil,'boss_treasure_choice_required'
  else extra[#extra+1]=row end
 end
 if not base or not key then return nil,'treasure_choice_unavailable'end
 if base.linkedSlot~=key.slot or key.linkedSlot~=base.slot or key.relicId~=base.id
  or reward.relicId~=base.id or reward.relicSourceId~=base.sourceId or reward.relicUnavailable~=not base.available
  or not exact(reward.sapphireKey,{relicId=true,linkedSlot=true,slot=true})
  or reward.sapphireKey.relicId~=base.id or reward.sapphireKey.linkedSlot~=base.slot or reward.sapphireKey.slot~=key.slot
  or reward.gold~=(gold and gold.amount or nil)then return nil,'treasure_reward_shape_unsupported'end
 if #extra>0 then
  if not array(reward.extraRelics)or #reward.extraRelics~=#extra then return nil,'treasure_reward_shape_unsupported'end
  for i,row in ipairs(reward.extraRelics)do
   if not item(row)or canonical(row)~=canonical(extra[i])then return nil,'treasure_reward_shape_unsupported'end
  end
 elseif reward.extraRelics~=nil then return nil,'treasure_reward_shape_unsupported'end
 return {relicId=base.id,relicAvailable=base.available,baseSlot=base.slot,keySlot=key.slot,itemsSignature=canonical(reward)}
end
return M
