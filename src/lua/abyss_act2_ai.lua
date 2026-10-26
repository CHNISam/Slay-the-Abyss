-- Source-compatible decision history: getMove sees all previously selected moves.
local A=require('abyss_actor')
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
local function choose(state,e,n)
 local policy=e.ai.policy
 if policy=='snake'then
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
 setMove(e,choose(state,e,random(state,100)-1))
end
function M.advance(state,e,random)
 e.act2Previous,e.act2Last=e.act2Last,e.intents[e.intentIndex].id
 setMove(e,choose(state,e,random(state,100)-1))
end
function M.preBattle(state,e)
 if e.ai.policy=='snake'then A.applyPower(state,e,'malleable',3,e) end
 if e.ai.policy=='book'then A.applyPower(state,e,'painful_stabs',1,e) end
 if e.ai.policy=='sphere'then
  A.applyPower(state,e,'barricade',1,e)
  A.applyPower(state,e,'artifact',3,e)
  A.block(state,e,40,true)
 end
end
return M
