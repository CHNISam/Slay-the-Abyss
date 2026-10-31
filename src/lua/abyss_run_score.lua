-- A0, non-daily scoring from GameOverScreen/CardGroup in
-- aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0.
-- Victory maps to this project's two-act ending; no Heart bonus is awarded.
local Score = {}

function Score.newStats(startingMaxHp)
  return {version=1, startingMaxHp=startingMaxHp, normalWins=0,
    eliteWins={0,0,0}, bosses=0, champion=0, perfect=0, goldGained=0,
    mysteryRooms=0, overkill=false, combo=false}
end

function Score.newBattleStats()
  return {goldGained=0, nonHpLossDamage=0, turnCardCount=0, overkill=false, combo=false}
end

local function finite(value)
  return type(value)=='number' and value==value and value>-math.huge and value<math.huge
end

local function natural(value)
  return finite(value) and value>=0 and value==math.floor(value)
end

local function validStats(stats)
  if type(stats)~='table' or stats.version~=1 or type(stats.eliteWins)~='table' then return false end
  for _,key in ipairs({'startingMaxHp','normalWins','bosses','champion','perfect','goldGained','mysteryRooms'}) do
    if not natural(stats[key]) then return false end
  end
  for act=1,3 do if not natural(stats.eliteWins[act]) then return false end end
  return type(stats.overkill)=='boolean' and type(stats.combo)=='boolean'
end

local function validSnapshot(s)
  if type(s)~='table' or not validStats(s.stats) then return false end
  for _,key in ipairs({'floor','maxHp','relicCount'}) do
    if not natural(s[key]) then return false end
  end
  if not finite(s.elapsedSeconds) or s.elapsedSeconds<0 then return false end
  if not finite(s.adjustment) or s.adjustment~=math.floor(s.adjustment) then return false end
  return type(s.victory)=='boolean' and type(s.cards)=='table'
end

local function validCard(index, card, size)
  if not natural(index) or index<1 or index>size or type(card)~='table' then return false end
  for _,key in ipairs({'sourceId','rarity','type'}) do
    if type(card[key])~='string' or card[key]=='' then return false end
  end
  return true
end

local function deckFacts(cards)
  local counts, facts = {}, {size=0, curses=0, collectors=0, highlander=true, pauper=true}
  for index,card in pairs(cards) do
    if not validCard(index,card,#cards) then return nil end
    facts.size=facts.size+1
    if card.rarity=='rare' then facts.pauper=false end
    if card.type=='curse' then facts.curses=facts.curses+1 end
    if card.rarity~='basic' then counts[card.sourceId]=(counts[card.sourceId] or 0)+1 end
  end
  if facts.size~=#cards then return nil end
  for _,count in pairs(counts) do
    if count>1 then facts.highlander=false end
    if count>=4 then facts.collectors=facts.collectors+25 end
  end
  return facts
end

local function tier(value, lower, upper, lowerPoints, upperPoints)
  if value>=upper then return upperPoints end
  if value>=lower then return lowerPoints end
  return 0
end

local function baseBreakdown(s)
  local stats=s.stats
  return {
    floors=5*s.floor, normal=2*stats.normalWins,
    elites=10*stats.eliteWins[1]+20*stats.eliteWins[2]+30*stats.eliteWins[3],
    bosses=25*stats.bosses*(stats.bosses+1), champion=25*stats.champion,
    perfect=stats.perfect>=3 and 200 or 50*stats.perfect,
    overkill=stats.overkill and 25 or 0, combo=stats.combo and 25 or 0,
  }
end

local function victoryBonuses(s, deck)
  if not s.victory then return {speed=0,highlander=0,pauper=0} end
  local seconds=math.floor(s.elapsedSeconds)
  return {
    speed=seconds<=2700 and 50 or (seconds<=3600 and 25 or 0),
    highlander=deck.highlander and 100 or 0,
    pauper=deck.pauper and 50 or 0,
  }
end

local function bonusBreakdown(s, deck)
  local gold=s.stats.goldGained
  local bonuses={
    collector=deck.collectors, relics=s.relicCount>=25 and 50 or 0,
    deck=tier(deck.size,35,50,25,50),
    maxHp=tier(s.maxHp-s.stats.startingMaxHp,15,30,25,50),
    cursed=deck.curses>=5 and 100 or 0,
    gold=gold>=3000 and 75 or tier(gold,1000,2000,25,50),
    mystery=s.stats.mysteryRooms>=15 and 25 or 0,
  }
  for key,value in pairs(victoryBonuses(s,deck)) do bonuses[key]=value end
  return bonuses
end

local function sum(values)
  local total=0
  for _,value in pairs(values) do total=total+value end
  return total
end

function Score.compute(snapshot)
  -- Legacy/partial histories cannot be reconstructed from the current wallet.
  if not validSnapshot(snapshot) then return nil,'score_unavailable' end
  local deck=deckFacts(snapshot.cards)
  if not deck then return nil,'score_unavailable' end
  local baseItems=baseBreakdown(snapshot)
  local bonusItems=bonusBreakdown(snapshot,deck)
  local base=sum(baseItems)
  local bonuses=sum(bonusItems)+snapshot.adjustment
  bonusItems.adjustment=snapshot.adjustment
  return {total=base+bonuses, base=base, bonuses=bonuses,
    breakdown={base=baseItems, bonuses=bonusItems}}
end

return Score
