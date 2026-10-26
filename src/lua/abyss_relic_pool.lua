-- Shared source-ID queues, independently implemented from STS 319009d5
-- AbstractDungeon/RelicLibrary. Catalog order is pinned host-JDK HashMap order,
-- not registration/alphabetical order; PC binary parity remains unverified.
local R=require('abyss_sts_random')
local M={}
local tiers={'common','uncommon','rare','shop','boss'}
local tierSet={common=true,uncommon=true,rare=true,shop=true,boss=true}
local limits={elite={50,83},event={50,83},shovel={50,83},shop={48,82},
 ['small-chest']={75,100},['medium-chest']={35,85},['large-chest']={0,75}}
local function plain(t)assert(type(t)=='table' and getmetatable(t)==nil,'expected plain table');return t end
local function exact(t,keys)
 plain(t);for k in pairs(t)do assert(keys[k],'unexpected field '..tostring(k))end
end
local function copy(t)
 if type(t)~='table' then return t end
 local out={};for k,v in pairs(plain(t))do out[k]=copy(v)end;return out
end
local function list(t)
 plain(t);local n=0
 for k,v in pairs(t)do assert(type(k)=='number' and k%1==0 and k>=1 and type(v)=='string' and #v>0,'invalid ID list');n=n+1 end
 assert(n==#t,'sparse ID list');return t
end
local function set(t)
 local out={};for _,id in ipairs(list(t or {}))do assert(not out[id],'duplicate ID');out[id]=true end;return out
end
local function catalogIndex(c)
 plain(c);assert(type(c.sourceCommit)=='string' and #c.sourceCommit>0,'missing source identity')
 exact(c.queues,tierSet);local ids={}
 for _,tier in ipairs(tiers)do
  for _,id in ipairs(list(c.queues[tier]))do assert(not ids[id],'duplicate source ID');ids[id]=tier end
 end
 plain(c.spawnGates or {})
 return ids
end
local function contains(t,id)for _,v in ipairs(t or {})do if v==id then return true end end;return false end
local function allowed(g,c)
 if not g or g.kind=='always' then return true end
 local floor,act,room=c.floor or 1,c.act or 1,c.room or 'monster'
 if g.kind=='max-floor' then return (c.endless or floor<=g.floor) and room~=g.excludeRoom end
 if g.kind=='max-act' then return act<=g.act end
 if g.kind=='owns-relic' then return contains(c.owned,g.id) end
 if g.kind=='campfire-limit' then
  local n=0;for _,id in ipairs(c.owned or {})do if contains({'Peace Pipe','Shovel','Girya'},id)then n=n+1 end end
  return (c.endless or floor<g.maxExclusiveFloor) and n<g.maxCampfireRelics
 end
 if g.kind=='card-type' or g.kind=='nonbasic-card-type' then
  for _,card in ipairs(c.deck or {})do
   if card.type==g.cardType and (g.kind=='card-type' or card.rarity~='BASIC')then return true end
  end
  return false
 end
 error('unknown source spawn gate')
end
function M.new(seed,sourceCatalog,options)
 local ids=catalogIndex(sourceCatalog);options=options or {}
 exact(options,{locked=true,removedAfterShuffle=true})
 local locked,removed=set(options.locked),set(options.removedAfterShuffle)
 for id in pairs(locked)do assert(ids[id],'unknown locked ID')end
 for id in pairs(removed)do assert(ids[id],'unknown removed ID')end
 local queues,rng={},R.fromSeed(seed)
 for _,tier in ipairs(tiers)do
  local q={};for _,id in ipairs(sourceCatalog.queues[tier])do if not locked[id]then q[#q+1]=id end end
  R.shuffle(rng,q) -- consumes one randomLong even for empty/singleton queues
  queues[tier]={};for _,id in ipairs(q)do if not removed[id]then queues[tier][#queues[tier]+1]=id end end
 end
 return {version=1,sourceCommit=sourceCatalog.sourceCommit,queues=queues,rng=rng,catalog=copy(sourceCatalog)}
end
function M.restore(snap,sourceCatalog)
 exact(snap,{version=true,sourceCommit=true,queues=true,rng=true})
 assert(snap.version==1 and snap.sourceCommit==sourceCatalog.sourceCommit,'relic source/version mismatch')
 local ids=catalogIndex(sourceCatalog);exact(snap.queues,tierSet);local seen={}
 for _,tier in ipairs(tiers)do
  for _,id in ipairs(list(snap.queues[tier]))do
   assert(ids[id]==tier and not seen[id],'unknown duplicate or wrong-tier relic');seen[id]=true
  end
 end
 return {version=1,sourceCommit=snap.sourceCommit,queues=copy(snap.queues),rng=R.restore(snap.rng),catalog=copy(sourceCatalog)}
end
function M.snapshot(state)
 local snap={version=state.version,sourceCommit=state.sourceCommit,queues=copy(state.queues),rng=R.snapshot(state.rng)}
 M.restore(snap,state.catalog) -- validate all queue membership and shape
 return snap
end
function M.rareness(channel,roll)
 local bound=limits[channel];assert(bound,'unknown relic rarity channel')
 assert(type(roll)=='number' and roll%1==0 and roll>=0 and roll<=99,'invalid rarity roll')
 return roll<bound[1] and 'common' or roll<bound[2] and 'uncommon' or 'rare'
end
M.rarity=M.rareness
function M.rollTier(state,channel)
 assert(limits[channel],'unknown relic rarity channel');M.snapshot(state)
 return M.rareness(channel,R.randomInt(state.rng,99))
end
local function selectRelic(state,tier,context,fromTail,reject)
 assert(tierSet[tier],'invalid relic tier');assert(fromTail==nil or type(fromTail)=='boolean','invalid queue direction')
 context=context or {};plain(context)
 assert(context.canSpawn==nil or type(context.canSpawn)=='function','invalid spawn callback')
 local staged=M.restore(M.snapshot(state),state.catalog);local trace={};local steps=0
 local function spawn(id)
  -- canSpawn receives resolved SOURCE IDs, never project IDs. It must reflect
  -- actual source eligibility, never whether this implementation supports it.
  local resolved=id=='Red Circlet' and 'Circlet' or id
  if context.canSpawn then
   local ok=context.canSpawn(resolved,context);assert(type(ok)=='boolean','spawn callback must return boolean');return ok
  end
  return allowed(staged.catalog.spawnGates and staged.catalog.spawnGates[resolved],context)
 end
 local function take(requested,tail)
  steps=steps+1;assert(steps<=1000,'nonterminating relic eligibility')
  local q=staged.queues[requested];local id
  if #q>0 then
   id=table.remove(q,tail and requested~='boss' and #q or 1)
   trace[#trace+1]={tier=requested,['end']=tail==true,id=id}
  elseif requested=='common' or requested=='shop' then id=take('uncommon',false)
  elseif requested=='uncommon' then id=take('rare',false)
  else
   id=requested=='boss' and 'Red Circlet' or 'Circlet'
   trace[#trace+1]={tier=requested,['end']=tail==true,id=id}
  end
  if not spawn(id)then return take(requested,true)end
  return id
 end
 local id
 repeat id=take(tier,fromTail)until not contains(reject,id)
 state.queues=staged.queues
 return id=='Red Circlet' and 'Circlet' or id,trace,id
end
function M.draw(state,tier,context,fromTail)
 return selectRelic(state,tier,context,fromTail,{})
end
function M.screenless(state,tier,context)
 return selectRelic(state,tier,context,false,{'Bottled Flame','Bottled Lightning','Bottled Tornado','Whetstone'})
end
return M
