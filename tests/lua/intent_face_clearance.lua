local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,Theme=H.F.Combat,require('abyss_theme')
local Enemy=require('abyss_battle_enemy_view')
local Intent=require('abyss_battle_intent_view')
local Source=require('abyss_monster_source_intents')
local function near(a,b,message)assert(math.abs(a-b)<.001,message)end
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local host,ui,panel,emit,tap=H.setup({'defend'},{'cultist'})
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
    local attack
    for _,move in ipairs(enemy.intents)do for _,effect in ipairs(move.effects or {})do
      if effect.op=='damage' then attack=attack or move.id end
    end end
    assert(attack,'real attack source fixture required')
    enemy.ai=nil;enemy.intentIndex=1;enemy.intents={{id=attack,kind='attack',effects=effects}}
   end
   host.run.combat=C.copy(battle);battle=host.run.combat
   host:refresh()
   local notice=panel:GetChild('notice')
   for i=1,count do
    local box=H.F.actorControl(panel, "enemy" .. i)
    local previous
    local hit=box:GetChild('intentHit')
    local hitX,hitY=box.x+hit.x,box.y+hit.y
    assert(hit.visible and hit.raycastTarget~=false,'intent details remain touchable')
    local g=Enemy.geometry(battle.enemies[i])
    near(box.x,g.x,'source actor x');near(box.y,g.y,'source actor y')
    near(hit.x,g.intentX,'source intent hit x');near(hit.y,g.intentY,'source intent hit y')
    near(hit.sizeDeltaX,g.intentHitWidth,'source intent hit width');near(hit.sizeDeltaY,g.intentHitHeight,'source intent hit height')
    near(hitY-hit.sizeDeltaY/2,g.hitY+g.hitHeight/2,'source intent help begins at body hitbox top')
    local detail=Intent.intentView(battle,i)
    tap('enemy'..i,11)
    local shown=inspectDetails(host.battleUI,panel)
    for _,row in ipairs(detail.rows or {})do assert(shown:find(row.text,1,true),'actual tooltip lost complete ordered effect: '..row.text)end
    assert(detail.text:find('9',1,true),'damage detail retained')
    if meanings>=2 then assert(detail.text:find('5',1,true),'block detail retained')end
    if meanings>=3 then assert(detail.text:find('2',1,true),'buff detail retained')end
    assert(not overlap(notice,Theme.layout.battleNotice.position[1],Theme.layout.battleNotice.position[2],hit,hitX,hitY),'intent help covers notice')
    for slot=1,Theme.layout.battlePotions.count do
     local potion=panel:GetChild('potion'..slot) or panel:GetChild('potionHelp'):GetChild('potion'..slot)
     local layout=Theme.layout.battlePotions
     assert(not overlap(potion,layout.origin[1]+(slot-1)*layout.step[1],layout.origin[2]+(slot-1)*layout.step[2],hit,hitX,hitY),'intent help covers potion')
    end
    for index,name in ipairs({'intentIcon','intentBadge','intentExtra','intent'})do
     local part=box:GetChild(name)
     assert(part.visible==(name=='intentIcon' or name=='intent'),'one source world icon and numeric damage; compound meanings remain in tooltip')
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
      if name=='intentIcon' then near(part.x,g.intentX,'source world icon x');near(part.y,g.intentY,'source world icon y');near(part.sizeDeltaX,g.intentWidth,'source world icon size')end
      -- Original icon is 128 wide but its hitbox is 64; do not shrink either
      -- merely to force the oversized icon/number into the source hit target.
      if name~='intent' then
       if previous then assert(part.x-previous.x>=(part.sizeDeltaX+previous.sizeDeltaX)/2,'compound icons overlap')end
       previous=part
      else
       local expected=Source.hasDefinition(battle.enemies[i]) and (Source.isMulti(battle.enemies[i],battle.enemies[i].intents[1]) and '9x2' or '9') or '9x2'
       assert(part.text==expected,'source explicit multi flag lost: '..part.text..' ~= '..expected)
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
   enemy.intentIndex=plan;host:refresh();naturalPlans=naturalPlans+1
   for source=1,#members do
    local box=H.F.actorControl(panel, "enemy" .. source)
    local hit=box:GetChild('intentHit')
    local x,y=box.x+hit.x,box.y+hit.y
    local g=Enemy.geometry(battle.enemies[source])
    near(y-hit.sizeDeltaY/2,g.hitY+g.hitHeight/2,'natural source help starts at body top')
    for target=1,#members do
     local other=H.F.actorControl(panel, "enemy" .. target)
     local otherGeometry=Enemy.geometry(battle.enemies[target])
     -- Compare the actual source hitbox, not the invisible old portrait plate.
     near(other.x,otherGeometry.x,'other actor source x must not reflow');near(other.y,otherGeometry.y,'other actor source y must not reflow')
     if source==target then assert(not overlap({sizeDeltaX=otherGeometry.hitWidth,sizeDeltaY=otherGeometry.hitHeight},otherGeometry.hitX,otherGeometry.hitY,hit,x,y),'source help covers own body')end
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
print('INTENT_FACE_CLEARANCE_PASS normal/elite/boss 1..5 1/2/3-detail-meanings/source-icon/damage/notice/potions/body/help')
