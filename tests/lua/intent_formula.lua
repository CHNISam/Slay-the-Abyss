local F=dofile('tests/lua/support/game_ui_fixture.lua')
local C,V,A=F.Combat,require('abyss_battle_intent_view'),require('abyss_actor')
local passed=0
local function unchanged(root)
 local saved={}
 local function visit(t)
  if type(t)~='table' or saved[t]then return end
  local fields={};saved[t]=fields
  for k,v in pairs(t)do fields[k]=v;visit(k);visit(v)end
 end
 visit(root)
 return function()
  for t,fields in pairs(saved)do
   for k,v in pairs(fields)do assert(t[k]==v,'preview mutated field or alias '..tostring(k))end
   for k in pairs(t)do assert(fields[k]~=nil,'preview inserted field '..tostring(k))end
  end
 end
end
local function state()
 local s=C.new(F.Data,{deck={'defend'},enemies={'cultist'}})
 local e=s.enemies[1]
 -- Keep a real mapped ATTACK identity while supplying arithmetic edge vectors.
 -- The vectors intentionally vary damage/effects; the production source registry stays strict.
 e.intents={{id='cultist_1',kind='attack',effects={{op='damage',value=9,times=2}}}};e.intentIndex=1
 return s,e
end
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local function projection(s,e,base,expected)
 local check=unchanged(s)
 local p=C.intentAttackPreview(s,e,s.player,base)
 assert(p.amount==expected and p.amount==C.intentAttackAmount(s,e,s.player,base))
 assert(p.steps[#p.steps].kind=='round' and p.steps[#p.steps].value==expected)
 check();return p
end
local function has(p,kind,value)
 for _,step in ipairs(p.steps)do if step.kind==kind then assert(value==nil or step.value==value);return step end end
 error('missing '..kind)
end
local function notes(face)
 local result={};for _,r in ipairs(face.rows)do result[#result+1]=(r.note or '')..(r.text or '')end
 return table.concat(result,'\n')
end

test('unchanged multi-hit intent always gives real base strength and rounding formula',function()
 local s,e=state();local check=unchanged(s);local face=V.intentView(s,1)
 local text=notes(face)
 assert(face.value=='9×2' and text:find('基础 9',1,true) and text:find('力量 +0 = 9',1,true) and text:find('取整',1,true))
 projection(s,e,9,9);check()
end)
test('negative strength clamps only at actual final rounding',function()
 local s,e=state();e.statuses.strength=-12
 local p=projection(s,e,9,0);has(p,'strength',-3)
 assert(notes(V.intentView(s,1)):find('力量 -12 = -3',1,true))
end)
test('Weak and Vulnerable show exact multipliers before final floor',function()
 local s,e=state();e.statuses.strength=3;e.statuses.weak=1;s.player.statuses.vulnerable=1
 local p=projection(s,e,9,13);has(p,'strength',12);assert(has(p,'weak',9).operand==.75);assert(has(p,'vulnerable',13.5).operand==1.5)
end)
test('Intangible is capped before flooring with no state or RNG mutation',function()
 local s,e=state();s.player.statuses.intangible=1
 has(projection(s,e,9,1),'intangible',1)
end)
test('actual odd mushroom and Wrath multipliers use the same core route',function()
 local s,e=state();s.player.statuses.vulnerable=1;s.relics={'odd_mushroom'};s.player.stance='Wrath'
 local p=projection(s,e,9,22);assert(has(p,'vulnerable',11.25).operand==1.25);assert(has(p,'stance',22.5).operand==2)
end)
test('ordered Slow and Vulnerable retain binary32 source vectors and table identities',function()
 local s,e=state();local vectors=dofile('tests/fixtures/giant-head-vectors.lua')
 for _,v in ipairs(vectors.damage)do
  e.statuses={strength=v.strength,double_damage=v.doubleDamage,weak=v.weak and 1 or nil}
  s.player.statuses={slow=v.slow,vulnerable=v.vulnerable and 1 or nil}
  s.player.powerOrder=v.vulnerable and (v.vulnerableFirst and {'vulnerable','slow'}or {'slow','vulnerable'})or {'slow'}
  -- Run the independent outgoing-source vectors through the same arithmetic
  -- API as intent previews, including Divinity and power-acquisition order.
  local target=e
  target.statuses={slow=v.slow,vulnerable=v.vulnerable and 1 or nil};target.powerOrder=s.player.powerOrder
  s.player.statuses={strength=v.strength,double_damage=v.doubleDamage,weak=v.weak and 1 or nil};s.player.stance=v.stance==3 and 'Divinity'or nil
  local check=unchanged(s)
  local p=C.intentAttackPreview(s,s.player,target,v.base)
  assert(p.amount==v.expected and p.amount==C.intentAttackAmount(s,s.player,target,v.base));has(p,'slow');check()
 end
end)
test('Spire back attack, truncation and Intangible trace the actual component',function()
 local s,e=state();e.ai={kind='spire_pair',policy='spear'};e.spireSide='right';s.spirePair={facingLeft=true};s.player.statuses.surrounded=1
 local p=projection(s,e,9,13);has(p,'back_attack',13.5);has(p,'truncate',13)
 s.player.statuses.intangible=1;has(projection(s,e,9,1),'intangible',1)
end)
test('Vigor double damage Pen Nib and Flight are actual ordered steps',function()
 local s,e=state();e.statuses.vigor=2;e.statuses.double_damage=1;e.statuses.pen_nib=1;s.player.statuses.flight=1
 local p=projection(s,e,9,22);has(p,'vigor',11);has(p,'double_damage',22);has(p,'pen_nib',44);has(p,'flight',22)
end)
test('fixed preview bypasses attack modifiers and retains actual Intangible cap',function()
 local s,e=state();e.statuses.strength=99;e.statuses.weak=1;s.player.statuses.vulnerable=1;s.player.statuses.intangible=1
 local check=unchanged(s);local p=C.intentAttackPreview(s,e,s.player,9,true)
 assert(p.amount==1 and p.amount==C.intentAttackAmount(s,e,s.player,9,true));has(p,'intangible',1)
 for _,step in ipairs(p.steps)do assert(step.kind~='strength' and step.kind~='weak' and step.kind~='vulnerable')end
 check()
end)
test('ordered strength effects feed later attack formulas only on the private preview',function()
 local s,e=state();e.intents[1].effects={{op='gainStatus',status='strength',value=2},{op='damage',value=9}}
 local check=unchanged(s);local face=V.intentView(s,1)
 assert(face.value=='11' and notes(face):find('力量 +2 = 11',1,true));check()
end)
test('original-role per-hit reduction explains unequal multi-hit final values',function()
 local s,e=state();s.originalV4={soften=2}
 local check=unchanged(s);local face=V.intentView(s,1)
 assert(face.value=='7+9' and notes(face):find('第1段削减：9 − 2 = 7',1,true));check()
end)
test('long special-modifier formulas paginate within the existing native font and safe viewport',function()
 local s,e=state();e.statuses={strength=999,vigor=2,double_damage=1,pen_nib=1,weak=1}
 s.player.statuses={slow=4,vulnerable=1,flight=1,intangible=1};s.player.powerOrder={'slow','vulnerable'};s.player.stance='Wrath'
 local check=unchanged(s);local face=V.intentView(s,1)
 assert(face.value=='1×2' and #face.rows>1)
 local Info=require('abyss_battle_info_view');local Content=require('abyss_battle_info_content');local Theme=require('abyss_theme')
 local pages=Info.paginator(Content.lines)({sections={{label='意图',rows=face.rows}}})
 local I,L=Theme.layout.statusInfo,Theme.layout
 local budget=Theme.canvas.base[2]-L.topBar.height-Theme.space.s-Theme.canvas.safe.y-I.pad*2-I.header-I.summary-I.divider-I.footer
 for _,page in ipairs(pages)do
  local used=0;for _,item in ipairs(page.items)do
   used=used+(item.label and I.section or I.name+(item.row.textLines+item.row.noteLines)*I.line+I.entryGap)
  end
  assert(used<=budget,'formula must fit the existing native page budget')
 end
 assert(Theme.font.small>=14);check()
end)
test('Slow trace records addition and stance multiplication before their binary32 rounding',function()
 local s,e=state();e.statuses={strength=3,vigor=2}
 s.player.statuses={slow=0};s.player.powerOrder={'slow'};s.player.stance='Wrath'
 local p=projection(s,e,9,28)
 local expected={{'base',9},{'binary32',9},{'strength',12},{'binary32',12},
  {'vigor',14},{'binary32',14},{'binary32',14},{'stance',28},{'binary32',28},{'slow',28},{'round',28}}
 assert(#p.steps==#expected)
 for i,row in ipairs(expected)do
  assert(p.steps[i].kind==row[1] and p.steps[i].value==row[2],'trace arithmetic order mismatch at '..i)
 end
end)
print('INTENT_FORMULA_PASS '..passed)
