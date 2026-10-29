local Data=require('abyss_original_v4_data')
local Display=require('abyss_card_display')
local Original=require('abyss_original_v4_display')
local condition={eye='雷眼有效',musou='梦想一心有效',not_musou='梦想一心失效',
 resolve0='愿力为0',resolve2='愿力≥2',resolve3='愿力≥3',resolve4='愿力≥4'}
local function includes(text,part)assert(text:find(part,1,true),'missing sourced action '..part..' in '..text)end
local function semantic(e,text)
 local n=tostring(e.n)
 if e.op=='when'then
  includes(text,'若'..assert(condition[e.condition])..'：')
  for _,child in ipairs(e.effects)do semantic(child,text)end
 elseif e.op=='damage' or e.op=='damage_spent'then
  includes(text,(e.target=='all' and '全体受' or '目标受')..n)
  if e.op=='damage_spent' and e.coefficient~=0 then includes(text,'+'..e.coefficient..'×所耗愿力')end
  if (e.hits or 1)>1 then includes(text,'×'..e.hits..'伤害')end
 elseif e.op=='block'then includes(text,'获得'..n..'格挡')
 elseif e.op=='draw'then includes(text,'抽'..n..'张牌')
 elseif e.op=='spend'then includes(text,e.n=='all' and '耗尽' or '耗'..n..'愿力')
 elseif e.op=='eye' or e.op=='musou'then
  includes(text,e.op=='eye' and '雷眼' or '梦想一心');includes(text,n..'次');includes(text,'2结束阶段')
  if e.n~=3 then includes(text,'至少'..n..'次（≤3）')end
 elseif e.op=='eye_pulse'then includes(text,'使用雷眼1次，对目标造成2衍生伤害')
 elseif e.op=='resolve'then includes(text,'愿力+'..n)
 elseif e.op=='next_energy'then includes(text,'下回合能量+'..n)
 elseif e.op=='next_draw'then includes(text,'下回合多抽'..n..'张')
 elseif e.op=='next_block'then includes(text,'下回合格挡+'..n)
 elseif e.op=='cleanse'then includes(text,'清除自身虚弱与脆弱')
 elseif e.op=='bonus'then includes(text,'本回合下张普攻伤害牌首击+'..n)
 elseif e.op=='soften'then includes(text,'本回合削势+'..n..'（上限6），减下次敌方攻击总伤害')
 elseif e.op=='counter'then includes(text,'本回合反击取大至'..n..'（上限8），下次敌方攻击后存活则反击一次')
 else error('unaudited Raiden source operation '..e.op)end
end
local total=0
for _,raw in ipairs(Data.cards)do if raw.role=='RD' then
  for _,up in ipairs({false,true})do
    local definition={originalV4=raw}
    local instance={upgraded=up}
    local text=Display.permanentText({},definition,instance)
    local plain=text:gsub('<[^>]+>','')
    local version=raw[up and 'upgrade' or 'base']
    for _,effect in ipairs(version.effects)do semantic(effect,plain)end
    for _,id in ipairs(raw.requirements)do includes(plain,'需'..assert(condition[id]))end
    if version.exhaust then includes(plain,'消耗')end
    assert(not text:find('长按查看全文',1,true),raw.id..': card hides its actual effects')
    assert(not text:find('附条件效果',1,true),raw.id..': missing exact condition and result')
    local live=Display.combatText({},definition,instance,{})
    assert(live==text,raw.id..': unavailable preview must preserve the complete action text')
    local control={}
    assert(Display.writeBody(control,text),raw.id..(up and '+' or '')..': complete card text does not fit')
    assert(control.fontSize>=14,raw.id..': card text became unreadable')
    assert(control.text==text,raw.id..': renderer truncated the complete text')
    total=total+1
  end
end end
assert(total==150)
local function card(id)for _,raw in ipairs(Data.cards)do if raw.id==id then return {originalV4=raw}end end error(id)end
local function has(text,part)assert(text:find(part,1,true),'missing '..part..' in '..text)end
local conditional=Display.permanentText({},card('RD2-005'),{})
has(conditional,'8');has(conditional,'梦想一心');has(conditional,'有效');has(conditional,'若');has(conditional,'2');has(conditional,'格挡')
has(Original.keywordDefinitions(card('RD2-005')),'有效指有剩余次数且未到期')
local spend=Display.permanentText({},card('RD2-060'),{})
for _,part in ipairs({'愿力','≥3','耗尽','全体','10','2','梦想一心','结束阶段','消耗'})do has(spend,part)end
local defense=Display.permanentText({},card('RD2-061'),{})
for _,part in ipairs({'16','格挡','雷眼','3','结束阶段','削势','6','下次','消耗'})do has(defense,part)end
-- The explanatory projection is kept complete for development and keyword help.
has(Original.describe(card('RD2-061')),'每牌最多一次，不追击新建自身的命中，不递归')
local pulse=Display.permanentText({},card('RD2-040'),{})
has(pulse,'使用');has(pulse,'1次')
assert(not pulse:find('消耗',1,true),'spending an eye use must not advertise exhaust')
assert(not Original.keywordDefinitions(card('RD2-040')):find('移出本场战斗',1,true))
has(Original.keywordDefinitions(card('RD2-063')),'消耗：打出后移出本场战斗')
print('ORIGINAL_V4_FACE_TEXT_PASS '..total)
