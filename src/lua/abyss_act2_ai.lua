-- Source-compatible decision history: getMove sees all previously selected moves.
local A=require('abyss_actor')
local ER=require('abyss_enemy_random')
local M={}
local function select(e,id)
 for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end
 error('unknown Act2 intent '..tostring(id))
end
local function twice(e,id)return e.act2Last==id and e.act2Previous==id end
local function alive(state)
 local count=0;for _,e in ipairs(state.enemies)do if A.isActive(e)then count=count+1 end end
 return count
end
local function choose(state,e,n,random)
 local policy=e.ai.policy
 if policy=='automaton'then
  if not e.act2Last then return 'spawn_orbs' end
  if e.act2AutoTurns==4 then e.act2AutoTurns=0;return 'hyper_beam' end
  if e.act2Last=='hyper_beam'then return 'stunned' end
  e.act2AutoTurns=e.act2AutoTurns+1
  return (e.act2Last=='stunned' or e.act2Last=='boost' or e.act2Last=='spawn_orbs') and 'flail' or 'boost'
 elseif policy=='orb'then
  if not e.act2StasisUsed and n>=25 then e.act2StasisUsed=true;return 'stasis' end
  if n>=70 and not twice(e,'support')then return 'support' end
  return not twice(e,'beam') and 'beam' or 'support'
 elseif policy=='collector'then
  if not e.act2Last then return 'spawn' end
  if e.act2TurnsTaken>=3 and not e.act2UltUsed then return 'mega_debuff' end
  local dead=false
  for _,id in pairs(e.act2TorchSlots or {})do
   for _,ally in ipairs(state.enemies)do if ally.id==id and ally.hp<=0 then dead=true end end
  end
  if n<=25 and dead and e.act2Last~='revive'then return 'revive' end
  if n<=70 and not twice(e,'fireball')then return 'fireball' end
  return e.act2Last~='buff' and 'buff' or 'fireball'
 elseif policy=='leader'then
  local allies=alive(state)-(A.isActive(e) and 1 or 0)
  while true do
   if allies==0 then
    if n<75 then return e.act2Last~='rally' and 'rally' or 'stab' end
    return e.act2Last~='stab' and 'stab' or 'rally'
   elseif allies==1 then
    if n<50 then
     if e.act2Last~='rally'then return 'rally' end
     n=random(state,50)+49
    elseif n<80 then return e.act2Last~='encourage' and 'encourage' or 'stab'
    elseif e.act2Last~='stab'then return 'stab'
    else n=random(state,81)-1 end
   else
    if n<66 then return e.act2Last~='encourage' and 'encourage' or 'stab' end
    return e.act2Last~='stab' and 'stab' or 'encourage'
   end
  end
 elseif policy=='snecko'then
  if not e.act2Last then return 'glare' end
  if n<40 or twice(e,'bite')then return 'tail' end
  return 'bite'
 elseif policy=='byrd'then
  if not e.act2Last then return ER.float(state,random)<0.375 and 'caw' or 'peck' end
  if (e.statuses.flight or 0)<=0 then return 'headbutt' end
  if n<50 then
   if twice(e,'peck')then return ER.float(state,random)<0.4000000059604645 and 'swoop' or 'caw' end
   return 'peck'
  elseif n<70 then
   if e.act2Last=='swoop'then return ER.float(state,random)<0.375 and 'caw' or 'peck' end
   return 'swoop'
  elseif e.act2Last=='caw'then return ER.float(state,random)<0.2856999933719635 and 'swoop' or 'peck' end
  return 'caw'
 elseif policy=='parasite'then
  if not e.act2Last then return ER.boolean(state,random) and 'double_strike' or 'life_suck' end
  if n<20 then
   if e.act2Last~='fell'then return 'fell' end
   n=random(state,80)+19
  end
  if n<60 then return twice(e,'double_strike') and 'life_suck' or 'double_strike' end
  return twice(e,'life_suck') and 'double_strike' or 'life_suck'
 elseif policy=='chosen'then
  if not e.act2Last then return 'poke' end
  if not e.act2HexUsed then e.act2HexUsed=true;return 'hex' end
  if e.act2Last~='drain' and e.act2Last~='debilitate'then return n<50 and 'debilitate' or 'drain' end
  return n<40 and 'zap' or 'poke'
 elseif policy=='snake'then
  if n<65 then return twice(e,'chomp') and 'spores' or 'chomp' end
  return e.act2Last=='spores' and 'chomp' or 'spores'
 elseif policy=='champ'then
  e.act2Turns=e.act2Turns+1
  if e.hp<e.maxHp/2 and not e.act2Enraged then e.act2Enraged=true;return 'anger' end
  if e.act2Enraged and e.act2Last~='execute' and e.act2Previous~='execute'then return 'execute' end
  if e.act2Turns==4 and not e.act2Enraged then e.act2Turns=0;return 'taunt' end
  if e.act2Last~='defensive_stance' and e.act2Forges<2 and n<=15 then
   e.act2Forges=e.act2Forges+1;return 'defensive_stance'
  end
  if e.act2Last~='gloat' and e.act2Last~='defensive_stance' and n<=30 then return 'gloat' end
  if e.act2Last~='face_slap' and n<=55 then return 'face_slap' end
  return e.act2Last~='heavy_slash' and 'heavy_slash' or 'face_slap'
 elseif policy=='taskmaster'then return 'whip'
 elseif policy=='book'then
  if n<15 then return e.act2Last=='big_stab' and 'multi_stab' or 'big_stab' end
  return twice(e,'multi_stab') and 'big_stab' or 'multi_stab'
 elseif policy=='sphere' then
  if not e.act2Last then return 'activate' end
  if e.act2Last=='activate' then return 'frail_attack' end
  return e.act2Last=='slam' and 'harden' or 'slam'
 elseif policy=='centurion' then
  if (n>=65 and not twice(e,'protect') and not twice(e,'fury')) or twice(e,'slash') then
   return alive(state)>1 and 'protect' or 'fury'
  end
  return 'slash'
 elseif policy=='mystic' then
  local missing=0
  for _,ally in ipairs(state.enemies)do if A.isActive(ally)then missing=missing+ally.maxHp-ally.hp end end
  if missing>15 and not twice(e,'heal') then return 'heal' end
  if n>=40 and not twice(e,'attack')then return 'attack' end
  return not twice(e,'buff') and 'buff' or 'attack'
 end
 error('unsupported Act2 policy '..tostring(policy))
end
local function setMove(e,id)
 if e.ai.policy=='book' and id=='multi_stab'then
  e.act2Stabs=e.act2Stabs+1
  for _,v in ipairs(e.intents)do if v.id==id then v.effects[1].times=e.act2Stabs end end
 end
 select(e,id)
end
function M.initialize(state,e,random)
 e.act2Last,e.act2Previous=nil,nil
 e.act2Stabs=1
 e.act2Turns,e.act2Forges,e.act2Enraged=0,0,false
 e.act2HexUsed=false
 e.act2TurnsTaken,e.act2UltUsed=0,false
 e.act2AutoTurns,e.act2StasisUsed=0,false
 setMove(e,choose(state,e,random(state,100)-1,random))
end
function M.advance(state,e,random)
 e.act2Previous,e.act2Last=e.act2Last,e.intents[e.intentIndex].id
 setMove(e,choose(state,e,random(state,100)-1,random))
end
function M.preBattle(state,e)
 if e.ai.policy=='automaton'then A.applyPower(state,e,'artifact',3,e) end
 if e.ai.policy=='leader'then
  e.act2GremlinSlots={}
  for i=1,2 do local ally=state.enemies[i];ally.minion=true;e.act2GremlinSlots[i]=ally.id;A.applyPower(state,ally,'minion',1,e) end
 end
 if e.ai.policy=='byrd'then A.applyPower(state,e,'flight',3,e) end
 if e.ai.policy=='parasite'then A.applyPower(state,e,'plated_armor',14,e);A.block(state,e,14,true) end
 if e.ai.policy=='snake'then A.applyPower(state,e,'malleable',3,e) end
 if e.ai.policy=='book'then A.applyPower(state,e,'painful_stabs',1,e) end
 if e.ai.policy=='sphere'then
  A.applyPower(state,e,'barricade',1,e)
  A.applyPower(state,e,'artifact',3,e)
  A.block(state,e,40,true)
 end
end
function M.beforeAction(state,e,random,intent)
 if e.ai.policy=='leader' and intent.id=='encourage'then random(state,3) end
 if e.ai.policy=='parasite' and intent.id=='stunned'then select(e,'fell') end
end
function M.afterAction(state,e,random,intent)
 if e.ai.policy=='collector'then
  e.act2TurnsTaken=e.act2TurnsTaken+1
  if intent.id=='mega_debuff'then e.act2UltUsed=true end
 end
 if e.ai.policy=='byrd' and intent.id=='headbutt'then select(e,'airborne');return end
 M.advance(state,e,random)
end
return M
