-- Independent source _WIN ownership. Never consume Neow's _SPIRITS history.
local M={}
local roles={ironclad=true,silent=true,defect=true}
local function plain(value)return type(value)=='table'and getmetatable(value)==nil end
local function copyWins(wins)
 local result={};for role,value in pairs(wins)do result[role]=value end;return result
end
local function validSnapshot(value)
 if not plain(value)or value.version~=1 or not plain(value.wins)then return false end
 for key in pairs(value)do if key~='version'and key~='wins'then return false end end
 for role in pairs(value.wins)do if not roles[role]then return false end end
 for role in pairs(roles)do if type(value.wins[role])~='boolean'then return false end end
 return true
end
local function readProvider(owner)
 if owner.loaded then return end;owner.loaded=true
 if type(owner.reader)~='function'then return end
 local called,value=pcall(owner.reader)
 if not called then owner.readStatus='read_failed';return end
 if not validSnapshot(value)then owner.readStatus='invalid_data';return end
 owner.wins,owner.readStatus=copyWins(value.wins),'loaded'
 owner.persistence=type(owner.writer)=='function'and 'not_written'or 'read_only'
end
function M.new(provider)
 provider=plain(provider)and provider or {}
 return {wins={},runs=setmetatable({},{__mode='k'}),reader=provider.read,writer=provider.write,
  loaded=false,readStatus='unavailable',persistence='unavailable',sessionWon=false}
end
function M.read(owner)
 readProvider(owner)
 local known,unlocked=true,true
 for role in pairs(roles)do
  if owner.wins[role]==nil then known=false end
  if owner.wins[role]~=true then unlocked=false end
 end
 local source=owner.readStatus=='loaded'and 'platform-history'or 'unknown'
 if owner.sessionWon then source=source=='unknown'and 'session-completed-run'or 'platform-and-session'end
 return {known=known,unlocked=unlocked,wins=copyWins(owner.wins),source=source,
  readStatus=owner.readStatus,persistence=owner.persistence}
end
local function identity(run)
 local role=run.character;if role==nil then role='ironclad'end
 if not roles[role]then return nil end
 local data=run.data
 if type(data)=='table'and(data.originalV4Role~=nil or data.originalV4Rules~=nil)then return nil end
 local profile=run.characterProfile
 if profile~=nil then
  if not plain(profile)or profile.originalV4~=nil and profile.originalV4~=false then return nil end
  if profile.id~=nil and profile.id~=role then return nil end
 end
 return role
end
local function flags(context)
 return plain(context)and type(context.seedSet)=='boolean'and type(context.isDailyRun)=='boolean'
  and type(context.isTrial)=='boolean'
end
function M.begin(owner,run,context)
 if not plain(run)then return nil,'invalid_ending_run'end
 if owner.runs[run]then return nil,'ending_run_already_registered'end
 local state=M.read(owner)
 local valid=flags(context)
 owner.runs[run]={role=identity(run),character=run.character,seed=run.runSeed,
  standard=valid and not context.seedSet and not context.isDailyRun and not context.isTrial
   and run.campaign==true and run.act==1 and run.phase=='map'and run.floor==1}
 -- Existing _WIN permits seeded final-act access; only recording that win is
 -- forbidden. Daily/trial (or unknown mode flags) cannot enable the ending.
 if not valid or context.isDailyRun or context.isTrial then state.unlocked=false end
 return state
end
local function terminal(run,map,entry)
 local flow,result=run.nodeFlow,run.lastResult
 if run.campaign~=true or run.act~=3 or run.floor~=51 or run.runSeed~=entry.seed
  or run.character~=entry.character or identity(run)~=entry.role or not entry.role then return false end
 if not plain(flow)or flow.type~='event'or flow.roomKind~='ending'or flow.complete~=true
  or flow.result~='normal_victory'or flow.floor~=51 or type(flow.id)~='string'then return false end
 if run.encounterTier~='boss'or type(run.encounterId)~='string'or not plain(result)
  or result.outcome~='victory'or result.encounterId~=run.encounterId or result.allEnemiesEscaped then return false end
 if not plain(map)or map.act~=3 or map.floor~=51 or map.runSeed~=entry.seed
  or type(map.sourceSignature)~='string'or map.sourceSignature==''or flow.mapSignature~=map.sourceSignature
  or flow.mapSeed~=entry.seed or map.currentNodeId~=flow.id or not plain(map.path)
  or map.path[#map.path]~=flow.id or not plain(map.nodes)then return false end
 local matches=0
 for _,node in ipairs(map.nodes)do
  if not plain(node)then return false end
  if node.id==flow.id then
   if node.floor~=51 or node.type~='event'or node.roomKind~='ending'then return false end
   matches=matches+1
  end
 end
 return matches==1
end
local function persist(owner,role)
 if type(owner.writer)~='function'then return end
 local called,accepted=pcall(owner.writer,{version=1,wins={[role]=true}})
 owner.persistence=called and accepted==true and 'acknowledged'or 'write_failed'
end
function M.finish(owner,run,map)
 local entry=type(run)=='table'and owner.runs[run]
 if not entry or entry.finished then return false,'unregistered_or_finished_run'end
 if run.phase~='victory'then
  if run.phase=='defeat'then entry.finished=true end
  return false,'not_victory'
 end
 if not entry.standard or not terminal(run,map,entry)then return false,'ineligible_ending_win'end
 entry.finished=true
 if owner.wins[entry.role]==true then return true,'already_won'end
 owner.wins[entry.role],owner.sessionWon=true,true
 persist(owner,entry.role)
 return true,owner.persistence
end
return M
