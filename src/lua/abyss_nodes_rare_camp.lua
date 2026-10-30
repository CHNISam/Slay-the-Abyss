-- Rare campfire actions use the existing Run transaction and source relic pool.
local Run=require('abyss_run')
local Common=require('abyss_nodes_common')
local Rare=require('abyss_rare_relics')
local Living=require('abyss_living_wall')
return function(M)
 local function pending(run,id)
  local flow,why=Common.pending(run,'camp');if not flow then return nil,why end
  if flow.campChoice then return nil,'camp_choice_made'end
  if not Rare.owns(run,id)then return nil,'missing_relic'end
  return flow
 end
 function M.lift(run)
  return Run.transaction(run,function(s)
   local flow,why=pending(s,'girya');if not flow then return false,why end
   local ok;ok,why=Rare.lift(s);if not ok then return false,why end
   flow.campChoice='lift';return Common.complete(s,'lift')
  end)
 end
 function M.toke(run,uid)
  return Run.transaction(run,function(s)
   local flow,why=pending(s,'peace_pipe');if not flow then return false,why end
   if not Common.find(Living.purgeCards(s),uid,'uid')then return false,'card_not_purgeable'end
   local ok;ok,why=Run.removeCard(s,uid);if not ok then return false,why end
   flow.campChoice='toke';return Common.complete(s,'toke')
  end)
 end
 function M.dig(run)
  return Run.transaction(run,function(s)
   local flow,why=pending(s,'shovel');if not flow then return false,why end
   local offer,pool=Run.prepareRelic(s,{channel='shovel',room='camp'})
   if not offer then return false,pool end
   s.relicPool=pool;flow.campChoice='dig';flow.digReward=offer
   return true,'choose_dig_relic'
  end)
 end
 function M.claimDigReward(run,claim)
  return Run.transaction(run,function(s)
   local flow,why=Common.pending(s,'camp');if not flow then return false,why end
   if type(claim)~='boolean'or flow.campChoice~='dig'or not flow.digReward then return false,'no_dig_reward'end
   if claim then
    local ok;ok,why=Run.obtainRelic(s,flow.digReward.sourceId);if not ok then return false,why end
   end
   flow.digReward.claimed=claim;return Common.complete(s,claim and 'dig_claimed'or 'dig_skipped')
  end)
 end
end
