local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,Theme=H.F.Combat,require('abyss_theme')
local sourceGeometry=dofile('tests/lua/support/source_intent_geometry.lua')
local host,ui,panel=H.setup({'defend'},{'cultist'})
-- Native text keeps its 40-high transparent compatibility box. Safety covers
-- the entire visible value at the declared native font, not transparent padding.
local function visible(part)
 if part.name~='intent' then return part end
 return {sizeDeltaX=utf8.len(part.text)*Theme.layout.intent.numberSize,
  sizeDeltaY=Theme.layout.intent.numberSize}
end
local function overlap(a,ax,ay,b,bx,by)
 return math.abs(ax-bx)<(a.sizeDeltaX+b.sizeDeltaX)/2-.001
  and math.abs(ay-by)<(a.sizeDeltaY+b.sizeDeltaY)/2-.001
end
local function check(members)
  local first,count=members[1],#members
  local battle=C.new(H.F.Data,{deck={'defend'},enemies=members,seed=42})
  host.run.combat=battle
  for meanings=1,3 do
   for _,enemy in ipairs(battle.enemies)do
    local effects={{op='damage',value=9,times=2}}
    if meanings>=2 then effects[#effects+1]={op='block',value=5}end
    if meanings>=3 then effects[#effects+1]={op='gainStatus',status='strength',value=2}end
    local Source=require('abyss_monster_source_intents')
    local selected
    for _,move in ipairs(enemy.intents)do
     local enum=Source.enum(enemy,move)
     if (enum and enum:sub(1,6)=='ATTACK')or not enum and move.kind=='attack'then selected=move.id;break end
    end
    assert(selected,'source actor needs an attack fixture')
    enemy.ai=nil;enemy.intentIndex=1;enemy.intents={{id=selected,kind='attack',effects=effects}}
   end
   -- Each synthetic plan is a new presentation instance, so the source
   -- selected/displayed lifecycle initializes from this exact tested move.
   host.run.combat=C.copy(battle);host:refresh()
   local notice=panel:GetChild('notice')
   for i=1,count do
    local box=monsterControl(panel,'enemy'..i)
    sourceGeometry(box,battle.enemies[i])
    local hit=box:GetChild('intentHit')
    local hitX,hitY=box.x+hit.x,box.y+hit.y
    assert(hit.visible and hit.raycastTarget~=false,'intent details remain touchable')
    assert(not overlap(notice,Theme.layout.battleNotice.position[1],Theme.layout.battleNotice.position[2],hit,hitX,hitY),'intent help covers notice')
    for slot=1,Theme.layout.battlePotions.count do
     local potion=panel:GetChild('potion'..slot) or panel:GetChild('potionHelp'):GetChild('potion'..slot)
     local layout=Theme.layout.battlePotions
     assert(not overlap(potion,layout.origin[1]+(slot-1)*layout.step[1],layout.origin[2]+(slot-1)*layout.step[2],hit,hitX,hitY),'intent help covers potion')
    end
    for index,name in ipairs({'intentIcon','intentBadge','intentExtra','intent'})do
     local part=box:GetChild(name)
     assert(part.visible==(name=='intentIcon' or name=='intent'),'world uses one source intent image and its attack number')
     if part.visible then
      local bound=visible(part)
      local x=box.x+part.x-(part.sizeDeltaX-bound.sizeDeltaX)/2
      local y=box.y+part.y
      assert(not overlap(notice,Theme.layout.battleNotice.position[1],Theme.layout.battleNotice.position[2],bound,x,y),'intent covers notice')
      for slot=1,Theme.layout.battlePotions.count do
       local potion=panel:GetChild('potion'..slot) or panel:GetChild('potionHelp'):GetChild('potion'..slot)
       local layout=Theme.layout.battlePotions
       assert(not overlap(potion,layout.origin[1]+(slot-1)*layout.step[1],layout.origin[2]+(slot-1)*layout.step[2],bound,x,y),'intent covers potion')
      end
      -- Source image is 128 units and its help hitbox is 64: containment is
      -- intentionally replaced by the independent constructor geometry above.
      if name=='intent' then
       local Source=require('abyss_monster_source_intents')
       local expected=Source.hasDefinition(battle.enemies[i]) and (Source.isMulti(battle.enemies[i],battle.enemies[i].intents[1]) and '9x2' or '9')or '9x2'
       assert(part.text==expected,'source multi-hit metadata lost')
      end
     end
    end
   end
  end
end
local naturalPlans=0
local function checkNatural(members)
 local battle=C.new(H.F.Data,{deck={'defend'},enemies=members,seed=42})
 host.run.combat=battle
 for index,enemy in ipairs(battle.enemies)do
  local initial=enemy.intentIndex
  for plan=1,#enemy.intents do
   enemy.intentIndex=plan;host.run.combat=C.copy(battle);host:refresh();naturalPlans=naturalPlans+1
   for source=1,#members do
    local box=monsterControl(panel,'enemy'..source)
    local hit=box:GetChild('intentHit')
    local x,y=box.x+hit.x,box.y+hit.y
    sourceGeometry(box,battle.enemies[source])
    for target=1,#members do
     local other=monsterControl(panel,'enemy'..target)
     assert(other.visible,'every natural source actor remains independently instantiated')
    end
   end
  end
  enemy.intentIndex=initial
 end
end
for _,first in ipairs({'cultist','gremlin_nob','guardian'})do
 -- Natural boss groups have at most three actors; five-actor groups are normal
 -- or elite encounters. Do not create an unsupported Guardian plus four adds.
 for count=1,first=='guardian' and 3 or 5 do
  local members={first};for i=2,count do members[i]='cultist'end;check(members)
 end
end
for _,members in ipairs({
 {'automaton','bronze_orb','bronze_orb'}, {'collector','torch_head','torch_head'},
 {'awakened_one','cultist','cultist'}, {'spike_slime_l','acid_slime_l'},
 {'spike_slime_m','spike_slime_m','acid_slime_m','acid_slime_m'},
 {'gremlin_leader','mad_gremlin','sneaky_gremlin'},
 {'reptomancer','snake_dagger','snake_dagger','snake_dagger','snake_dagger'},
})do check(members);checkNatural(members)end
print('INTENT_NATIVE_PLAN_CLEARANCE '..naturalPlans)
print('INTENT_FACE_CLEARANCE_PASS normal/elite/boss 1..5 1/2/3-icons/damage/notice/potions/portrait/help')
