package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=require('abyss_encounter_formation')
local count=0
local function test(name,fn) fn();count=count+1;print('PASS formation '..count..' - '..name) end
local function equal(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function names(group)
 local out={};for _,actor in ipairs(group)do out[#out+1]=actor.kind end;return table.concat(out,',')
end
local function adapter(booleans,integers,offsets)
 local b,i,v=0,0,0;local log,created={},{}
 local boundary={misc={}}
 boundary.misc.boolean=function()
  b=b+1;assert(type(booleans[b])=='boolean','unexpected misc Boolean');log[#log+1]='bool';return booleans[b]
 end
 boundary.misc.integer=function(lo,hi)
  i=i+1;local expected=assert(integers[i],'unexpected misc index');equal(lo,expected[1]);equal(hi,expected[2])
  log[#log+1]='index:'..lo..':'..hi;return expected[3]
 end
 boundary.visualFloat=function(lo,hi)
  equal(lo,-20);equal(hi,20);v=v+1;log[#log+1]='offset';return assert(offsets[v],'unexpected MathUtils offset')
 end
 boundary.construct=function(id,x,y)
  log[#log+1]='new:'..id
  local actor={kind=id,x=x,y=y,constructor=#created+1};created[#created+1]=actor;return actor
 end
 return boundary,log,created,function()equal(b,#booleans);equal(i,#integers);equal(v,#offsets)end
end

test('every two and three Louse slot chooses its own color immediately before construction',function()
 local positions={['2 Louse']={{-200,10},{80,30}},['3 Louse']={{-350,25},{-125,10},{80,30}}}
 for source,slots in pairs(positions)do for mask=0,2^#slots-1 do
  local bools,expected={},{}
  for i=1,#slots do bools[i]=math.floor(mask/2^(i-1))%2==1;expected[i]=bools[i] and 'red_louse' or 'green_louse' end
  local boundary,log,_,done=adapter(bools,{},{});local group=F.assemble(source,boundary);done()
  equal(names(group),table.concat(expected,','))
  for i,actor in ipairs(group)do equal(actor.x,slots[i][1]);equal(actor.y,slots[i][2]);equal(log[2*i-1],'bool');equal(log[2*i],'new:'..expected[i])end
 end end
end)
test('Large Slime is one source group with one Boolean and one actual constructor',function()
 for _,value in ipairs({false,true})do
  local boundary,log,created,done=adapter({value},{},{});local group=F.assemble('Large Slime',boundary);done()
  equal(#group,1);equal(#created,1);equal(names(group),value and 'acid_slime_l' or 'spike_slime_l');equal(group[1].x,0);equal(group[1].y,0)
  equal(log[1],'bool');equal(log[2],'new:'..group[1].kind)
 end
end)
test('Lots retains all 120 ordered index paths and interleaves every constructor, including the last index0',function()
 local sourcePool={'spike_slime_s','spike_slime_s','spike_slime_s','acid_slime_s','acid_slime_s'}
 local positions={{-480,30},{-320,2},{-160,32},{10,-12},{200,9}}
 local paths,firstSpike,firstAcid=0,0,0
 for a=0,4 do for b=0,3 do for c=0,2 do for d=0,1 do
  local ranks={a,b,c,d,0};local used,expected={},{}
  -- Independent oracle uses original positions and remaining ranks, never table.remove.
  for _,rank in ipairs(ranks)do
   local left=rank
   for original=1,5 do if not used[original]then
    if left==0 then used[original]=true;expected[#expected+1]=sourcePool[original];break end
    left=left-1
   end end
  end
  local calls={};for i,rank in ipairs(ranks)do calls[i]={0,5-i,rank}end
  local boundary,log,_,done=adapter({},calls,{});local group=F.assemble('Lots of Slimes',boundary);done()
  equal(names(group),table.concat(expected,','));paths=paths+1
  if group[1].kind=='spike_slime_s'then firstSpike=firstSpike+1 else firstAcid=firstAcid+1 end
  for i,actor in ipairs(group)do
   equal(actor.x,positions[i][1]);equal(actor.y,positions[i][2]);equal(log[2*i-1],'index:0:'..(5-i));equal(log[2*i],'new:'..expected[i])
  end
 end end end end
 equal(paths,120);equal(firstSpike,72);equal(firstAcid,48)
end)
test('Thugs constructs every weak then humanoid candidate before selection and keeps selected objects',function()
 for weak=0,2 do for strong=0,2 do for _,redLouse in ipairs({false,true})do for _,redSlaver in ipairs({false,true})do
  local boundary,log,created,done=adapter({redLouse,redSlaver},{{0,2,weak},{0,2,strong}},{-20,20,5,-5})
  local group=F.assemble('Exordium Thugs',boundary);done();equal(#created,6)
  equal(group[1],created[weak+1]);equal(group[2],created[strong+4])
  equal(group[1].x,-180);equal(group[1].y,40);equal(group[2].x,135);equal(group[2].y,15)
  equal(table.concat(log,','),table.concat({'offset','offset','bool','new:'..(redLouse and 'red_louse' or 'green_louse'),
   'new:spike_slime_m','new:acid_slime_m','index:0:2','offset','offset','new:cultist','bool',
   'new:'..(redSlaver and 'red_slaver' or 'blue_slaver'),'new:looter','index:0:2'},','))
 end end end end
end)
test('Wildlife is fixed two slots, strong then weak, with all five eager candidates',function()
 for strong=0,1 do for weak=0,2 do for _,red in ipairs({false,true})do
  local boundary,log,created,done=adapter({red},{{0,1,strong},{0,2,weak}},{0,0,0,0})
  local group=F.assemble('Exordium Wildlife',boundary);done();equal(#created,5);equal(#group,2)
  equal(group[1],created[strong+1]);equal(group[2],created[weak+3]);equal(group[1].x,-150);equal(group[2].x,150)
  equal(table.concat(log,','),table.concat({'offset','offset','new:fungi_beast','new:jaw_worm','index:0:1',
   'offset','offset','bool','new:'..(red and 'red_louse' or 'green_louse'),'new:spike_slime_m','new:acid_slime_m','index:0:2'},','))
 end end end
end)
test('eager discarded candidates retain HP and Louse Bite draws on the independent constructor stream',function()
 local ranges={green_louse={11,17},spike_slime_m={28,32},acid_slime_m={28,32},cultist={48,54},blue_slaver={46,50},looter={44,48}}
 local boundary,log,_,done=adapter({false,false},{{0,2,2},{0,2,2}},{0,0,0,0})
 local hpCalls={};boundary.construct=function(id,x,y)
  log[#log+1]='new:'..id;local range=assert(ranges[id]);hpCalls[#hpCalls+1]={id,range[1],range[2]}
  if id=='green_louse'then hpCalls[#hpCalls+1]={'bite',5,7}end
  return {kind=id,x=x,y=y,hp=range[1],hpDraw=#hpCalls}
 end
 local group=F.assemble('Exordium Thugs',boundary);done()
 equal(#hpCalls,7);equal(group[1].kind,'acid_slime_m');equal(group[1].hpDraw,4);equal(group[2].kind,'looter');equal(group[2].hpDraw,7)
 equal(hpCalls[1][1],'green_louse');equal(hpCalls[2][1],'bite');equal(hpCalls[3][1],'spike_slime_m')
end)
test('unknown groups and invalid adapter outputs fail without a substituted group',function()
 local boundary,_,created=adapter({}, {}, {})
 assert(not pcall(F.assemble,'medium_slimes',boundary));equal(#created,0)
 boundary.misc.boolean=function()return 1 end;assert(not pcall(F.assemble,'2 Louse',boundary));equal(#created,0)
 boundary.misc.integer=function()return 5 end;assert(not pcall(F.assemble,'Lots of Slimes',boundary));equal(#created,0)
end)
print('LUA_ENCOUNTER_FORMATIONS_PASS '..count)
