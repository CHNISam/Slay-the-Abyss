package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local O=require('abyss_orbs')
local data=require('abyss_defect_cards').withFoundationCards(require('abyss_data'))
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,f) f();n=n+1;print('ok '..n..' '..name) end
local function setup(id,up,many)
 local deck={};for i=1,(many and 8 or 1) do deck[i]={cardId=id,upgraded=up} end
 local s=C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck=deck,enemies={'jaw_worm','jaw_worm'}})
 return s,s.hand[1].uid
end
for _,up in ipairs({false,true}) do
 local tag=up and '+' or ''
 test('Leap'..tag..' source block with card modifiers',function()
  local s,u=setup('leap',up);s.player.statuses.dexterity=2;s.player.statuses.frail=1
  assert(C.play(s,u));eq(s.energy,2);eq(s.player.block,up and 10 or 8)
 end)
 test('Sweeping Beam'..tag..' target-specific area damage then draw',function()
  local s,u=setup('sweeping_beam',up,true);s.player.statuses.strength=2;s.enemies[1].statuses.vulnerable=1
  local hp1,hp2,hand=s.enemies[1].hp,s.enemies[2].hp,#s.hand
  assert(C.play(s,u));eq(s.energy,2);eq(s.enemies[1].hp,hp1-(up and 16 or 12));eq(s.enemies[2].hp,hp2-(up and 11 or 8));eq(#s.hand,hand)
 end)
 test('Beam Cell'..tag..' zero cost and damage before vulnerability',function()
  local s,u=setup('beam_cell',up);local hp=s.enemies[1].hp;assert(C.play(s,u,1))
  eq(s.energy,3);eq(s.enemies[1].hp,hp-(up and 4 or 3));eq(s.enemies[1].statuses.vulnerable,up and 2 or 1)
 end)
 test('Fusion'..tag..' source cost and plasma energy at next real turn',function()
  local s,u=setup('fusion',up);assert(C.play(s,u));eq(s.energy,up and 2 or 1);eq(s.orbs.balls[1].kind,'plasma')
  assert(C.endTurn(s));eq(s.energy,4)
 end)
 test('Defragment'..tag..' power leaves piles and immediately affects existing orbs',function()
  local s,u=setup('defragment',up);O.channel(s,'frost',C);O.channel(s,'dark',C);O.channel(s,'plasma',C)
  assert(C.play(s,u));eq(s.energy,2);eq(s.orbs.focus,up and 2 or 1);eq(#s.discard,0);eq(#s.exhaust,0);eq(#s.hand,0)
  eq(s.orbs.balls[2].stored,6);O.endTurn(s,C);eq(s.player.block,up and 4 or 3);eq(s.orbs.balls[2].stored,up and 14 or 13)
 end)
end

test('normal attack damage can change without modifying lightning orb damage',function()
 local s,u=setup('beam_cell',false);O.channel(s,'lightning',C);s.player.statuses.strength=10
 local hp=s.enemies[1].hp;assert(C.play(s,u,1));eq(s.enemies[1].hp,hp-13)
 s.enemies[2].hp=0;O.evoke(s,C);eq(s.enemies[1].hp,hp-21)
end)
test('Beam Cell missing target does not spend or apply vulnerability',function()
 local s,u=setup('beam_cell',false);eq(C.play(s,u),false);eq(#s.hand,1);eq(s.energy,3);eq(s.enemies[1].statuses.vulnerable or 0,0)
end)
test('Beam Cell Artifact blocks only the following debuff',function()
 local s,u=setup('beam_cell',true);s.enemies[1].statuses.artifact=1;local hp=s.enemies[1].hp
 assert(C.play(s,u,1));eq(s.enemies[1].hp,hp-4);eq(s.enemies[1].statuses.artifact,0);eq(s.enemies[1].statuses.vulnerable or 0,0)
end)
test('Sweeping Beam killing all enemies cancels queued draw',function()
 local s,u=setup('sweeping_beam',false,true);s.enemies[1].hp=1;s.enemies[2].hp=1
 local hand=#s.hand;assert(C.play(s,u));eq(s.phase,'victory');eq(#s.hand,hand-1)
end)
test('positive Focus Power does not consume Artifact',function()
 local s,u=setup('defragment',false);s.player.statuses.artifact=2;assert(C.play(s,u));eq(s.orbs.focus,1);eq(s.player.statuses.artifact,2)
end)
test('positive Focus stack clamps to source 999 limit',function()
 local s,u=setup('defragment',true);O.setFocus(s,998);assert(C.play(s,u));eq(s.orbs.focus,999)
end)
test('negative focus effect applies a signed loss without becoming a gain',function()
 local s,u=setup('defragment',false);s.catalog.cards.defragment.effects[1].value=-1
 assert(C.play(s,u));eq(s.player.statuses.focus,-1);eq(s.orbs.focus,-1);eq(s.energy,2);eq(#s.hand,0)
end)
print('DEFECT_EXPANSION_PASS '..n)
