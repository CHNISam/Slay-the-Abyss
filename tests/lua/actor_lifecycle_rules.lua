package.path='src/lua/?.lua;'..package.path
local R=require('abyss_actor_power_rules')
local function eq(a,b,label)assert(a==b,'[ACTOR_POWER_RULES] '..label..': '..tostring(a)..' ~= '..tostring(b))end
for _,id in ipairs({'abyss_actor','abyss_combat','abyss_relic_hooks','abyss_power_order'})do
 eq(package.loaded[id],nil,'independent leaf loading '..id)
end
eq(R.integer(0),true,'zero integer');eq(R.integer(1.5),false,'fraction rejected')
eq(R.integer(2147483648.0),false,'range rejected')
eq(R.artifactEligible('strength',0),true,'zero signed debuff')
eq(R.artifactEligible('dexterity',1),false,'positive signed buff')
eq(R.artifactEligible('weak',0),true,'zero ordinary debuff')
eq(R.artifactEligible('ritual',0),false,'ordinary buff')
R.validateAmount('wraith_form',-2);R.validateAmount('painful_stabs',-1)
eq(pcall(R.validateAmount,'weak',-1),false,'negative ordinary amount rejected')
local definition={id='strength',stack='intensity',decay='none'}
local definitions={strength=definition};R.validateDefinitions(definitions)
eq(definitions.strength,definition,'definition identity retained')
eq(R.stackValue('strength',definition,990,20),999,'signed clamp after sum')
eq(R.stackValue('painful_stabs',{stack='none'},-1,2),-1,'permanent sentinel')
eq(R.stackValue('weak',{stack='duration'},1,2),3,'ordinary addition')
eq(R.stackValue('entangled',{stack='none'},0,3),1,'nonstacking normalization')
eq(pcall(R.stackValue,'weak',{stack='duration'},2147483647.0,1),false,'overflow before commit')
for _,value in pairs(R)do eq(type(value),'function','no mutable rule tables exported')end
print('ACTOR_POWER_RULES_PASS independent leaf and pure rules')
