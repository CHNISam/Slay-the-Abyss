local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,Theme=H.F.Combat,require('abyss_theme')
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
    enemy.ai=nil;enemy.intentIndex=1;enemy.intents={{kind='attack',effects=effects}}
   end
   host:refresh()
   local notice=panel:GetChild('notice')
   for i=1,count do
    local box=panel:GetChild('enemy'..i)
    local previous
    local hit=box:GetChild('intentHit')
    local hitX,hitY=box.x+hit.x,box.y+hit.y
    assert(hit.visible and hit.raycastTarget~=false,'intent details remain touchable')
    assert(hit.y-hit.sizeDeltaY/2>=box:GetChild('plate').sizeDeltaY/2+Theme.space.xs-.001,'intent help covers portrait target '..first..'/'..count..'/'..meanings)
    assert(not overlap(notice,Theme.layout.battleNotice.position[1],Theme.layout.battleNotice.position[2],hit,hitX,hitY),'intent help covers notice')
    for slot=1,Theme.layout.battlePotions.count do
     local potion=panel:GetChild('potion'..slot) or panel:GetChild('potionHelp'):GetChild('potion'..slot)
     local layout=Theme.layout.battlePotions
     assert(not overlap(potion,layout.origin[1]+(slot-1)*layout.step[1],layout.origin[2]+(slot-1)*layout.step[2],hit,hitX,hitY),'intent help covers potion')
    end
    for index,name in ipairs({'intentIcon','intentBadge','intentExtra','intent'})do
     local part=box:GetChild(name)
     assert(part.visible==(index<=meanings or name=='intent'),'all intended meanings and numeric damage must remain visible')
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
      assert(part.y-bound.sizeDeltaY/2>=box:GetChild('plate').sizeDeltaY/2-.001,'intent hides portrait '..first..'/'..count..'/'..i..'/'..name)
      assert(math.abs(x-box.x-hit.x)+bound.sizeDeltaX/2<=hit.sizeDeltaX/2+.001,'intent outside help hit')
      assert(math.abs(part.y-hit.y)+bound.sizeDeltaY/2<=hit.sizeDeltaY/2+.001,'intent outside help hit')
      if name~='intent' then
       if previous then assert(part.x-previous.x>=(part.sizeDeltaX+previous.sizeDeltaX)/2,'compound icons overlap')end
       previous=part
      else assert(part.text=='9×2','multi-hit damage lost')end
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
    local box=panel:GetChild('enemy'..source)
    local hit=box:GetChild('intentHit')
    local x,y=box.x+hit.x,box.y+hit.y
    assert(hit.y-hit.sizeDeltaY/2>=box:GetChild('plate').sizeDeltaY/2+Theme.space.xs-.001,'natural help covers own portrait')
    for target=1,#members do
     local other=panel:GetChild('enemy'..target)
     assert(not overlap(other:GetChild('plate'),other.x,other.y,hit,x,y),'natural help covers portrait '..members[index]..'/'..enemy.intents[plan].id..' source='..source..' target='..target)
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
