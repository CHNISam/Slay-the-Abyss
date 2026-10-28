local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,Theme=H.F.Combat,require('abyss_theme')
local host,ui,panel=H.setup({'defend'},{'cultist'})
local function overlap(a,ax,ay,b,bx,by)
 return math.abs(ax-bx)<(a.sizeDeltaX+b.sizeDeltaX)/2-.001
  and math.abs(ay-by)<(a.sizeDeltaY+b.sizeDeltaY)/2-.001
end
local function check(members)
  local first,count=members[1],#members
  local battle=C.new(H.F.Data,{deck={'defend'},enemies=members,seed=42})
  for _,enemy in ipairs(battle.enemies)do
   enemy.ai=nil;enemy.intentIndex=1
   enemy.intents={{kind='attack',effects={{op='damage',value=9,times=2},{op='block',value=5},{op='gainStatus',status='strength',value=2}}}}
  end
  host.run.combat=battle;host:refresh()
  local notice=panel:GetChild('notice')
  for i=1,count do
   local box=panel:GetChild('enemy'..i)
   local previous
   local hit=box:GetChild('intentHit')
   for _,name in ipairs({'intentIcon','intentBadge','intentExtra','intent'})do
    local part=box:GetChild(name);assert(part.visible,'all three meanings and numeric damage must remain visible')
    local x,y=box.x+part.x,box.y+part.y
    assert(not overlap(notice,Theme.layout.battleNotice.position[1],Theme.layout.battleNotice.position[2],part,x,y),'intent covers notice')
    for slot=1,Theme.layout.battlePotions.count do
     local potion=panel:GetChild('potion'..slot) or panel:GetChild('potionHelp'):GetChild('potion'..slot)
     local layout=Theme.layout.battlePotions
     assert(not overlap(potion,layout.origin[1]+(slot-1)*layout.step[1],layout.origin[2]+(slot-1)*layout.step[2],part,x,y),'intent covers potion')
    end
    assert(part.y-part.sizeDeltaY/2>=box:GetChild('plate').sizeDeltaY/2-.001,'intent hides portrait '..first..'/'..count..'/'..i..'/'..name..' '..part.y..' '..part.sizeDeltaY..' '..box:GetChild('plate').sizeDeltaY)
    assert(math.abs(part.x-hit.x)+part.sizeDeltaX/2<=hit.sizeDeltaX/2+.001,'intent outside help hit')
    assert(math.abs(part.y-hit.y)+part.sizeDeltaY/2<=hit.sizeDeltaY/2+.001,'intent outside help hit')
    if name~='intent' then
     if previous then assert(part.x-previous.x>=(part.sizeDeltaX+previous.sizeDeltaX)/2,'compound icons overlap')end
     previous=part
    else assert(part.text=='9×2','multi-hit damage lost')end
   end
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
})do check(members)end
print('INTENT_FACE_CLEARANCE_PASS normal/elite/boss 1..5 three-icons/damage/notice/potions/portrait/help')
