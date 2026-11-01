-- Fixed arithmetic oracle: aeubanks/sts@319009d5, GameOverScreen/CardGroup.
-- Static source comparison, not an original-client execution.
local loaded, Score = pcall(require, 'abyss_run_score')
assert(loaded, 'pure run-score module must exist')
local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function snapshot()
  return { stats=Score.newStats(80), floor=0, maxHp=80, elapsedSeconds=4000,
    victory=false, cards={}, relicCount=0, adjustment=0 }
end
local function total(s, expected, label)
  local result = assert(Score.compute(s))
  eq(result.total, expected, label)
  eq(result.base + result.bonuses, result.total, label .. ' sum')
  return result
end
local function cards(s, count, id, rarity, kind)
  for _=1,count do
    s.cards[#s.cards+1] = {sourceId=id or ('unique-' .. tostring(#s.cards+1)),
      rarity=rarity or 'common', type=kind or 'skill'}
  end
end
local s = snapshot()
total(s,0,'neutral'); s.adjustment=-1; total(s,-1,'poop no clamp'); total(s,-1,'repeat pure')
eq(s.stats.normalWins,0,'input not modified')
local other=Score.newStats(70); other.eliteWins[1]=1
eq(s.stats.eliteWins[1],0,'fresh nested stats')
local battle=Score.newBattleStats()
eq(battle.goldGained,0,'battle gold'); eq(battle.nonHpLossDamage,0,'battle damage')
eq(battle.turnCardCount,0,'battle plays'); eq(battle.overkill,false,'battle overkill')
eq(battle.combo,false,'battle combo')
for _,case in ipairs({{0,0},{1,2},{2,4}}) do
  s=snapshot(); s.stats.normalWins=case[1]; total(s,case[2],'normal room count')
end
s=snapshot(); s.stats.eliteWins={1,1,0}; total(s,30,'act elite weights')
s.stats.champion=2; total(s,80,'champions')
s.stats.eliteWins[3]=1; total(s,110,'reference act3 counter')
for _,case in ipairs({{1,0,50},{2,0,150},{2,2,250},{3,3,500},{3,4,500}}) do
  s=snapshot(); s.stats.bosses=case[1]; s.stats.perfect=case[2]
  total(s,case[3],'boss and perfect tiers')
end
s=snapshot(); s.stats.overkill=true; total(s,25,'overkill')
s.stats.combo=true; total(s,50,'combo')
for _,case in ipairs({{3,0},{4,25},{8,25}}) do
  s=snapshot(); cards(s,case[1],'A'); total(s,case[2],'collector')
end
s=snapshot(); cards(s,4,'A','basic'); total(s,0,'basic excluded')
s=snapshot(); cards(s,4,'A'); s.cards[4].upgraded=true
cards(s,4,'B'); total(s,50,'source id upgrades and two sets')
for _,case in ipairs({{24,0},{25,50},{26,50}}) do
  s=snapshot(); s.relicCount=case[1]; total(s,case[2],'relic threshold')
end
for _,case in ipairs({{34,0},{35,25},{36,25},{49,25},{50,50},{51,50}}) do
  s=snapshot(); cards(s,case[1]); total(s,case[2],'deck threshold')
end
for _,case in ipairs({{14,0},{15,25},{16,25},{29,25},{30,50},{31,50}}) do
  s=snapshot(); s.maxHp=80+case[1]; total(s,case[2],'hp threshold')
end
for _,case in ipairs({{4,0},{5,100},{6,100}}) do
  s=snapshot(); cards(s,case[1],nil,'curse','curse'); total(s,case[2],'curse threshold')
end
s=snapshot(); cards(s,4,'curse-id','curse','curse'); total(s,25,'curse set distinct from cursed bonus')
for _,case in ipairs({{999,0},{1000,25},{1001,25},{1999,25},{2000,50},{2001,50},{2999,50},{3000,75},{3001,75}}) do
  s=snapshot(); s.stats.goldGained=case[1]; total(s,case[2],'gold tier')
end
for _,case in ipairs({{14,0},{15,25},{16,25}}) do
  s=snapshot(); s.stats.mysteryRooms=case[1]; total(s,case[2],'mystery threshold')
end
for _,case in ipairs({{2699,50},{2700,50},{2700.9,50},{2701,25},{3599,25},{3600,25},{3600.9,25},{3601,0}}) do
  s=snapshot(); s.victory=true; s.elapsedSeconds=case[1]; cards(s,2,'A','rare')
  total(s,case[2],'truncated speed tier')
  s.victory=false; total(s,0,'defeat excludes victory bonuses')
end
s=snapshot(); s.victory=true; cards(s,5,'strike','basic'); cards(s,1,'A')
total(s,150,'basic repeats allow highlander and pauper')
cards(s,1,'A'); total(s,50,'duplicate nonbasic disallows highlander')
s=snapshot(); s.victory=true; cards(s,1,'A','rare'); total(s,100,'rare disallows pauper')
s=snapshot(); cards(s,4,'A'); cards(s,8,'B'); cards(s,5,nil,'curse','curse'); cards(s,33)
s.relicCount=25; s.maxHp=110; s.stats.goldGained=3000; s.stats.mysteryRooms=15; s.adjustment=-1
total(s,399,'stacked defeat fixed oracle')
s.victory=true; s.elapsedSeconds=2700; total(s,499,'stacked victory fixed oracle')
s=snapshot(); s.floor=34; s.stats.normalWins=20; s.stats.eliteWins={3,2,0}
s.stats.bosses=2; s.stats.champion=3; s.stats.perfect=2; s.stats.overkill=true; s.stats.combo=true
eq(total(s,655,'integrated base').base,655,'base subtotal')
cards(s,5,'strike','basic'); cards(s,1,'A'); s.victory=true; s.elapsedSeconds=2700
total(s,855,'two act no heart'); s.adjustment=-1; total(s,854,'two act poop')
s.victory=false; total(s,654,'two act defeat')
for _,bad in ipairs({'missing','version','field','nan','elite'}) do
  s=snapshot()
  if bad=='missing' then s.stats=nil
  elseif bad=='version' then s.stats.version=2
  elseif bad=='field' then s.stats.goldGained=nil
  elseif bad=='nan' then s.stats.goldGained=0/0
  else s.stats.eliteWins[2]=nil end
  local result, reason=Score.compute(s)
  eq(result,nil,'unavailable '..bad); eq(reason,'score_unavailable','unavailable reason')
end
for _,key in ipairs({'startingMaxHp','normalWins','bosses','champion','perfect','goldGained','mysteryRooms','overkill','combo','eliteWins'}) do
  s=snapshot(); s.stats[key]=nil
  eq(Score.compute(s),nil,'missing history '..key)
end
for _,key in ipairs({'floor','maxHp','elapsedSeconds','relicCount','adjustment','cards','victory'}) do
  s=snapshot(); s[key]=nil; eq(Score.compute(s),nil,'missing snapshot '..key)
end
eq(Score.compute(nil),nil,'missing snapshot')
for _,value in ipairs({-1,math.huge,-math.huge,0/0}) do
  s=snapshot(); s.elapsedSeconds=value; eq(Score.compute(s),nil,'invalid elapsed')
end
for _,key in ipairs({'sourceId','rarity','type'}) do
  s=snapshot(); cards(s,1,'A'); s.cards[1][key]=''
  eq(Score.compute(s),nil,'empty card '..key)
end
s=snapshot(); cards(s,1,'A'); s.cards.extra=s.cards[1]
eq(Score.compute(s),nil,'nonarray deck rejected')
print('run_score_calculator: ' .. checks .. ' assertions passed')
