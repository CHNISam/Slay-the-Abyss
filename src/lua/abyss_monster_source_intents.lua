-- Exact setMove metadata from pinned source; evidence: docs/art/source-monster-intents.json.
local M={}
local moves={
 -- Event-only source moves: docs/art/source-event-monster-ui.json.
 bandit_pointy={pointy_special="ATTACK"},
 bandit_leader={mock="UNKNOWN",agonizing_slash="ATTACK_DEBUFF",cross_slash="ATTACK"},
 bandit_bear={bear_hug="STRONG_DEBUFF",lunge="ATTACK_DEFEND",maul="ATTACK"},
 lagavulin_awake={siphon="STRONG_DEBUFF",attack="ATTACK"},
 ["acid_slime_l"]={["acid_slime_l_1"]="ATTACK_DEBUFF",["acid_slime_l_2"]="DEBUFF",["acid_slime_l_3"]="ATTACK",["acid_slime_l_split"]="UNKNOWN"},
 ["acid_slime_m"]={["acid_slime_m_1"]="ATTACK_DEBUFF",["acid_slime_m_2"]="DEBUFF",["acid_slime_m_3"]="ATTACK"},
 ["acid_slime_s"]={["acid_slime_s_1"]="ATTACK",["acid_slime_s_2"]="DEBUFF"},
 ["automaton"]={["boost"]="DEFEND_BUFF",["flail"]="ATTACK",["hyper_beam"]="ATTACK",["spawn_orbs"]="UNKNOWN",["stunned"]="STUN"},
 ["blue_slaver"]={["blue_slaver_1"]="ATTACK",["blue_slaver_2"]="ATTACK_DEBUFF"},
 ["book_of_stabbing"]={["big_stab"]="ATTACK",["multi_stab"]="ATTACK"},
 ["bronze_orb"]={["beam"]="ATTACK",["stasis"]="STRONG_DEBUFF",["support"]="DEFEND"},
 ["byrd"]={["airborne"]="UNKNOWN",["caw"]="BUFF",["headbutt"]="ATTACK",["peck"]="ATTACK",["stunned"]="STUN",["swoop"]="ATTACK"},
 ["centurion"]={["fury"]="ATTACK",["protect"]="DEFEND",["slash"]="ATTACK"},
 ["champ"]={["anger"]="BUFF",["defensive_stance"]="DEFEND_BUFF",["execute"]="ATTACK",["face_slap"]="ATTACK_DEBUFF",["gloat"]="BUFF",["heavy_slash"]="ATTACK",["taunt"]="DEBUFF"},
 ["chosen"]={["debilitate"]="ATTACK_DEBUFF",["drain"]="DEBUFF",["hex"]="STRONG_DEBUFF",["poke"]="ATTACK",["zap"]="ATTACK"},
 ["collector"]={["buff"]="DEFEND_BUFF",["fireball"]="ATTACK",["mega_debuff"]="STRONG_DEBUFF",["revive"]="UNKNOWN",["spawn"]="UNKNOWN"},
 ["cultist"]={["cultist_1"]="ATTACK",["cultist_2"]="BUFF"},
 ["fat_gremlin"]={["fat_gremlin_1"]="ATTACK_DEBUFF"},
 ["fungi_beast"]={["fungi_beast_1"]="ATTACK",["fungi_beast_2"]="BUFF"},
 ["green_louse"]={["green_louse_1"]="ATTACK",["green_louse_2"]="DEBUFF"},
 ["gremlin_leader"]={["encourage"]="DEFEND_BUFF",["rally"]="UNKNOWN",["stab"]="ATTACK"},
 ["gremlin_nob"]={["gremlin_nob_1"]="BUFF",["gremlin_nob_2"]="ATTACK_DEBUFF",["gremlin_nob_3"]="ATTACK"},
 ["guardian"]={["guardian_1"]="DEFEND",["guardian_2"]="ATTACK",["guardian_3"]="ATTACK",["guardian_4"]="STRONG_DEBUFF",["guardian_5"]="BUFF",["guardian_6"]="ATTACK",["guardian_7"]="ATTACK_BUFF"},
 ["hexaghost"]={["activate"]="UNKNOWN",["divider"]="ATTACK",["inferno"]="ATTACK_DEBUFF",["inflame"]="DEFEND_BUFF",["sear"]="ATTACK_DEBUFF",["tackle"]="ATTACK"},
 ["jaw_worm"]={["jaw_worm_1"]="ATTACK",["jaw_worm_2"]="ATTACK_DEFEND",["jaw_worm_3"]="DEFEND_BUFF"},
 ["lagavulin"]={["lagavulin_1"]="SLEEP",["lagavulin_2"]="ATTACK",["lagavulin_3"]="ATTACK",["lagavulin_4"]="STRONG_DEBUFF",["lagavulin_stunned"]="STUN"},
 ["looter"]={["looter_1"]="ATTACK",["looter_2"]="DEFEND",["looter_escape"]="ESCAPE",["looter_lunge"]="ATTACK"},
 ["mad_gremlin"]={["mad_gremlin_1"]="ATTACK"},
 ["mugger"]={["escape"]="ESCAPE",["lunge"]="ATTACK",["mug"]="ATTACK",["smoke"]="DEFEND"},
 ["mystic"]={["attack"]="ATTACK_DEBUFF",["buff"]="BUFF",["heal"]="BUFF"},
 ["red_louse"]={["red_louse_1"]="ATTACK",["red_louse_2"]="BUFF"},
 ["red_slaver"]={["red_slaver_1"]="ATTACK",["red_slaver_2"]="STRONG_DEBUFF",["red_slaver_3"]="ATTACK_DEBUFF"},
 ["sentry"]={["sentry_1"]="ATTACK",["sentry_2"]="DEBUFF"},
 ["shelled_parasite"]={["double_strike"]="ATTACK",["fell"]="ATTACK_DEBUFF",["life_suck"]="ATTACK_BUFF",["stunned"]="STUN"},
 ["shield_gremlin"]={["shield_gremlin_1"]="DEFEND",["shield_gremlin_2"]="ATTACK"},
 ["slime_boss"]={["prepare"]="UNKNOWN",["slam"]="ATTACK",["split"]="UNKNOWN",["sticky"]="STRONG_DEBUFF"},
 ["snake_plant"]={["chomp"]="ATTACK",["spores"]="STRONG_DEBUFF"},
 ["sneaky_gremlin"]={["sneaky_gremlin_1"]="ATTACK"},
 ["snecko"]={["bite"]="ATTACK",["glare"]="STRONG_DEBUFF",["tail"]="ATTACK_DEBUFF"},
 ["spheric_guardian"]={["activate"]="DEFEND",["frail_attack"]="ATTACK_DEBUFF",["harden"]="ATTACK_DEFEND",["slam"]="ATTACK"},
 ["spike_slime_l"]={["spike_slime_l_1"]="ATTACK_DEBUFF",["spike_slime_l_2"]="DEBUFF",["spike_slime_l_split"]="UNKNOWN"},
 ["spike_slime_m"]={["spike_slime_m_1"]="ATTACK_DEBUFF",["spike_slime_m_2"]="DEBUFF"},
 ["spike_slime_s"]={["spike_slime_s_1"]="ATTACK"},
 ["taskmaster"]={["whip"]="ATTACK_DEBUFF"},
 ["torch_head"]={["tackle"]="ATTACK"},
 ["wizard_gremlin"]={["wizard_gremlin_1"]="UNKNOWN",["wizard_gremlin_3"]="ATTACK"},
}
function M.hasDefinition(actor)return moves[actor.definitionId]~=nil end
function M.enum(actor,intent)
 if not intent then return 'NONE'end
 local known=moves[actor.definitionId]
 if not known then return nil end
 local value=assert(known[intent.id],'unmapped source monster intent '..actor.definitionId..':'..tostring(intent.id))
 -- Normal Nob is constructed with canVuln=true. The false constructor variant is explicit.
 if actor.definitionId=='gremlin_nob' and intent.id=='gremlin_nob_2' and actor.canVuln==false then return 'ATTACK'end
 return value
end
local images={BUFF='BUFF',DEBUFF='DEBUFF',STRONG_DEBUFF='DEBUFF2',DEFEND='DEFEND',
 DEFEND_DEBUFF='DEFEND',DEFEND_BUFF='DEFEND_BUFF',ESCAPE='ESCAPE',MAGIC='MAGIC',SLEEP='SLEEP',UNKNOWN='UNKNOWN'}
function M.visual(enum,damage,times)
 if not enum or enum=='NONE'or enum=='STUN'then return nil end
 if enum:sub(1,6)=='ATTACK'then
  local total=assert(damage,'missing source attack preview')*(times or 1)
  local tier=7
  for i,threshold in ipairs({5,10,15,20,25,30})do if total<threshold then tier=i;break end end
  return 'INTENT_ATK_'..tier,'attack',true
 end
 local key=assert(images[enum],'unknown source intent enum')
 local native=({DEFEND_BUFF='defend',DEBUFF2='debuff',MAGIC='unknown',ESCAPE='unknown'})[key] or key:lower()
 return 'INTENT_'..key..'_L',native,enum~='UNKNOWN'
end
-- Explicit source setMove(..., true) flags, independently audited across all 130 moves.
local multi={bandit_pointy={pointy_special=true},guardian={guardian_3=true,guardian_7=true},hexaghost={divider=true,tackle=true,inferno=true},
 spheric_guardian={slam=true},centurion={fury=true},book_of_stabbing={multi_stab=true},snake_plant={chomp=true},
 chosen={poke=true},shelled_parasite={double_strike=true},byrd={peck=true},gremlin_leader={stab=true},automaton={flail=true},champ={execute=true}}
function M.isMulti(actor,intent)
 return not not (intent and multi[actor.definitionId] and multi[actor.definitionId][intent.id])
end
return M
