local stage, selected, attack, death = nil, 1, 1, 9
local queue, clock, locked, bgm = {}, 0, 0, false
local dying, oldGain = nil, {attack=65,death=65}
local function status(s) stage:GetChild("status").text=s end
local function refresh()
 local r=rows[selected]
 stage:GetChild("detail").text=r.code.." · "..r.id.." · "..r.name.."\n联动组合：攻击 "..rows[attack].code.." / 死亡 "..rows[death].code
 stage:GetChild("gain").text="候选音量 "..r.volume.." / 100 · 旧版 "..oldGain[r.group].." · 同音量不等于已匹配"
 stage:GetChild("review").text=r.code.." · "..r.rating.." · "..r.tags
end
local function signal(name) game.ServerSignal(name):SendSignal() end
local function emit(id, volume, code, dies)
 local s=game.ServerSignal("SFX_LISTEN");s:AddInt(id);s:AddInt(volume);s:SendSignal()
 status("播放 "..code.." · "..id.." · 音量 "..volume)
 print("SFX_PLAY "..code.." id="..id.." volume="..volume.." t="..clock)
 local target=stage:GetChild("target");target:SetVisible(true)
 if dies then dying=clock;print("SFX_DEATH_ONCE "..code) end
end
local function add(at,index,old,dies)
 local r=rows[index];queue[#queue+1]={at=clock+at,id=old and (r.group=="attack" and 50936 or 50941) or r.id,volume=old and oldGain[r.group] or r.volume,code=old and (r.group=="attack" and "A0" or "D0") or r.code,dies=dies}
end
local function start(fn)
 if clock<locked then status("请等上一段尾音结束；仍可更改选择和评语") return end
 queue={};dying=nil;stage:GetChild("target"):SetVisible(true);fn()
end
local function review(rating,tag)
 local r=rows[selected];if rating then r.rating=rating end;if tag then r.tags=tag end
 print("SFX_REVIEW "..r.code.." id="..r.id.." volume="..r.volume.." rating="..r.rating.." comment="..r.tags);refresh()
end
function OnStart()
 local ok,err=pcall(function()
  stage=script.object:GetChild("stage");local w,h=game.GetUICanvasSize();local k=math.min(w/1280,h/720);stage:SetLocalScale(k,k,1)
  local function bind(name,fn)stage:GetChild(name):GetChild("hit"):AddCursorEventListener(Enum.CursorEventType.CursorClick,fn)end
  for i=1,#rows do local n=i;bind("pick"..i,function()selected=n;if n<=8 then attack=n else death=n end;refresh()end)end
  bind("play",function()start(function()add(0,selected,false,selected>8);locked=clock+6 end)end)
  bind("old",function()start(function()add(0,selected,true,selected>8);locked=clock+6 end)end)
  bind("ab",function()start(function()add(0,selected,true,selected>8);add(7,selected,false,selected>8);locked=clock+13 end)end)
  bind("burst",function()start(function()for i=0,5 do add(i*0.45,attack,false,false)end;locked=clock+8 end)end)
  bind("death",function()start(function()add(0,death,false,true);locked=clock+6 end)end)
  bind("mix",function()start(function()for i=0,2 do add(i*0.45,attack,false,false)end;add(1.35,death,false,true);locked=clock+8 end)end)
  bind("bgm",function()bgm=not bgm;signal(bgm and "ABYSS_BGM_BATTLE" or "ABYSS_BGM_STOP");status(bgm and "BGM 开 · 10044 / 45 · 用混听检查遮蔽" or "BGM 已暂停")end)
  bind("minus",function()rows[selected].volume=math.max(0,rows[selected].volume-5);refresh()end)
  bind("plus",function()rows[selected].volume=math.min(100,rows[selected].volume+5);refresh()end)
  bind("like",function()review("喜欢")end);bind("maybe",function()review("待定")end);bind("reject",function()review("淘汰")end)
  bind("tag1",function()review(nil,"刺耳")end);bind("tag2",function()review(nil,"尾音过长")end);bind("tag3",function()review(nil,"满足")end)
  bind("cancel",function()queue={};signal("ABYSS_BGM_STOP");bgm=false;status("已取消后续播放；当前原生一次性音效自然结束")end)
  bind("tour",function()start(function()
   signal("ABYSS_BGM_STOP");bgm=false
   add(0,1,true,false);add(7,9,true,true)
   for i=1,#rows do add(14+(i-1)*7,i,false,i>8)end
   locked=clock+100;status("轮播：A0、D0、A1–A8、D1–D4，各间隔7秒")
  end)end)
  script:EnableUpdate(true);refresh();status("ready · 先单听与 A/B，再连续攻击与 BGM 混听")
  print("SFX_READY")
 end)
 if not ok then print("SFX_FAILED "..tostring(err));pcall(function()stage:GetChild("status").text="试听启动失败："..tostring(err)end)end
end
function OnUpdate(dt)
 clock=clock+dt
 while queue[1] and queue[1].at<=clock do local e=table.remove(queue,1);emit(e.id,e.volume,e.code,e.dies)end
 if dying then local t=clock-dying;stage:GetChild("target"):SetLocalScale(math.max(0,1-t*2),math.max(0,1-t*2),1);if t>=0.5 then stage:GetChild("target"):SetVisible(false);stage:GetChild("target"):SetLocalScale(1,1,1);dying=nil end end
end
