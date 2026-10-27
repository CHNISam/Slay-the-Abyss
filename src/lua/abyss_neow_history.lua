-- Session-local mirror of the source per-character _SPIRITS preference.
-- No disk/profile default is fabricated when the platform cannot read history.
local M={}
local function role(run)return run.character or 'ironclad'end
local function valid(value)
 return type(value)=='table' and value.known~=false and (value.bossCount==0 or value.bossCount==1)
end
function M.new(provider)
 return {entries={},finished=setmetatable({},{__mode='k'}),provider=provider}
end
function M.read(owner,character)
 character=character or 'ironclad'
 local entry=owner.entries[character]
 if entry then return {bossCount=entry.bossCount,source=entry.source}end
 if type(owner.provider)~='function'then return nil,'neow_history_unavailable'end
 local called,value=pcall(owner.provider,character)
 if not called or not valid(value)then return nil,'neow_history_unavailable'end
 entry={bossCount=value.bossCount,source='platform-history'}
 owner.entries[character]=entry
 return {bossCount=entry.bossCount,source=entry.source}
end
function M.finish(owner,run,outcome)
 if not run or owner.finished[run]then return false end
 if outcome=='victory' or outcome=='defeat'then
  if run.phase~=outcome then return false end
 elseif outcome~='abandon'then return false end
 if type(run.floor)~='number' or run.floor%1~=0 or run.floor<0 or run.floor>55 then return false end
 owner.entries[role(run)]={bossCount=(outcome=='victory' or run.floor>=16)and 1 or 0,
  source='session-completed-run'}
 owner.finished[run]=true
 return true
end
return M
