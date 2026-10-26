-- One imported scene, all pressure stages. Counts are expected content controls, not FPS.
local HOST_PREFAB_ID = 0
local EXTENDED = false
local scenery
local failed=false
local nativeReady,nativeWait,lastNativeRequest,clearing=true,0,nil,false
local root, selected, moving, sweeping, reuse = nil, 1, true, true, false
local cache, current, elapsed, samples, reported, phase, sweepTime = {}, nil, 0, {}, false, 0, 0
local stages = {
 {'基线',0,0,0,0,0,0},
 {'10图标×16',0,0,0,0,10,16}, {'10图标×32',0,0,0,0,10,32}, {'10图标×64',0,0,0,0,10,64},
 {'1角色×257',1,0,0,0,0,0}, {'3角色×257',3,0,0,0,0,0}, {'5角色×257',5,0,0,0,0,0},
 {'1高精角色×939',0,1,0,0,0,0}, {'3高精角色×939',0,3,0,0,0,0}, {'5高精角色×939',0,5,0,0,0,0},
 {'1轻卡×15',0,0,1,0,0,0}, {'5轻卡×15',0,0,5,0,0,0}, {'10轻卡×15',0,0,10,0,0,0},
 {'1高精卡×343',0,0,0,1,0,0}, {'5高精卡×343',0,0,0,5,0,0}, {'10高精卡×343',0,0,0,10,0,0},
 {'5角色+10轻卡',5,0,10,0,0,0}, {'5角色+10高精卡',5,0,0,10,0,0},
 {'5高精角色+10高精卡',0,5,0,10,0,0}, {'极限组合+10技能图标',0,5,0,10,10,64},
}
local modules={'AP_A','AP_B2','AP_Card','AP_HighCard','AP_Icon'}
local costs={257,939,15,343,0}
local function say(name,text) root:GetChild(name).text=text end
local function fail(message,tag)
 failed=true;sweeping=false
 for _,name in ipairs({'Toolbar','Status','Metrics'}) do root:GetChild(name):SetActive(true) end
 say('Status',message);say('Metrics','本档未通过，不采样；可切档重试')
 print(tag..' stage='..selected..' '..message)
end
local function dispose(group)
 if not group then return end
 for i=#group,1,-1 do
  local item=group[i]
  if item.asset then pcall(item.asset.destroy) end
  if item.outer.alive then game.DestroyClientUIControl(item.outer) end
 end
end
local function clearAll(keepScenery)
 for _,group in pairs(cache) do dispose(group) end
 cache={};current=nil
 if scenery and not keepScenery then scenery:clear() end
end
local function show(index)
 if not reuse then clearAll(true)
 elseif current then for _,item in ipairs(current) do item.outer:SetActive(false) end end
 selected=((index-1)%#stages)+1
 failed=false;clearing=false
 local s=stages[selected]
 if scenery then
  local ok,reason=pcall(function() scenery:show(s[8] or 0,s[9] or 0,s[10] or 0) end)
  if not ok then pcall(clearAll);fail('场景创建失败：'..tostring(reason),'ARTPRESS_FAIL');return end
  nativeReady=lastNativeRequest==scenery.requestId;nativeWait=0
 end
 local drawn=0
 for kind=1,5 do drawn=drawn+s[kind+1]*(kind==5 and s[7] or costs[kind]) end
 drawn=drawn+((s[9] or 0)<0 and 207 or (s[9] or 0)*(s[10] or 0))
 elapsed,samples,reported,sweepTime=0,{},false,0
 if cache[selected] then
  current=cache[selected];for _,item in ipairs(current) do item.outer:SetActive(true) end
 else
  current={};cache[selected]=current
  local ok,reason=pcall(function()
   for kind=1,5 do
    for slot=1,s[kind+1] do
     local outer=assert(game.InstantiateClientUIControl(HOST_PREFAB_ID,root),'host template unavailable')
     local item={outer=outer};current[#current+1]=item
     outer:SetActive(true);outer:SetVisible(true)
     local inner=assert(game.InstantiateClientUIControl(HOST_PREFAB_ID,outer),'inner host unavailable')
     inner:SetActive(true);inner:SetVisible(true)
     item.x=(kind<=2) and (-440+(slot-1)*220) or (kind<=4 and (-540+(slot-1)*120) or (-450+(slot-1)*100))
     item.y=(kind<=2) and 50 or (kind<=4 and -170 or -280)
     outer:SetAnchoredPosition(item.x,item.y)
     item.asset=require(modules[kind])(inner,s[7]);item.asset.start()
    end
   end
  end)
  if not ok then
   pcall(clearAll);fail('图元创建失败：'..tostring(reason),'ARTPRESS_FAIL');return
  end
 end
 say('Status',selected..'/'..#stages..' '..s[1]..' | UI '..drawn..' | '..(reuse and '缓存复用' or '销毁重建'))
 say('Metrics',sweeping and '自动巡测：每档15秒，2秒预热+8秒回调采样（非GPU FPS）' or '10秒预热+30秒回调采样（非GPU FPS）；可直接切档/清空/移动')
 root:GetChild('Toolbar'):SetAsLastSibling();root:GetChild('Status'):SetAsLastSibling();root:GetChild('Metrics'):SetAsLastSibling()
 local cleanView=EXTENDED and (selected==33 or selected==34 or selected==39)
 for _,name in ipairs({'Toolbar','Status','Metrics'}) do root:GetChild(name):SetActive(not cleanView) end
 print('ARTPRESS_STAGE '..selected..' drawn='..drawn..' instances='..#current..' reuse='..tostring(reuse)..' motion='..tostring(moving))
end
local function click(name,fn)
 root:GetChild('Toolbar'):GetChild(name):AddCursorEventListener(Enum.CursorEventType.CursorClick,function()
  print('ARTPRESS_CLICK '..name);fn()
 end)
end
function OnStart()
 root=script.object;clearAll()
 if EXTENDED then
  scenery=require('AP_Scenes').new(root,HOST_PREFAB_ID)
  script:RegisterServerSignalHandler('AP_SCENE_READY',function(_,params)
   print('ARTSCENE_ACK groups='..tostring(params[1])..' nativeOwned='..tostring(params[2])..' requestId='..tostring(params[3]))
   if params[1]~=scenery.groups or params[3]~=scenery.requestId then print('ARTSCENE_ACK_STALE');return end
   local expected=params[1]==100 and 32 or params[1]*7
   if params[2]~=expected then
    nativeReady=false;fail('原生模型数量不符：'..tostring(params[2])..'/'..expected,'ARTSCENE_FAIL_COUNT')
   else
    lastNativeRequest=params[3];nativeReady=true;nativeWait=0
    if clearing then clearing=false;say('Status','UI与原生实体均已清理');print('ARTPRESS_CLEARED') end
   end
  end)
  for _,stage in ipairs(require('AP_Scenes').stages) do stages[#stages+1]=stage end
  selected=33
 end
 click('Prev',function() show(selected-1) end);click('Next',function() show(selected+1) end)
 click('Mid',function() show(17) end);click('Masked',function() show(9) end)
 click('High',function() show(18) end);click('Extreme',function() show(19) end);click('Icons',function() show(4) end)
 click('Clear',function()
  clearAll();sweeping=false;failed=false
  for _,name in ipairs({'Toolbar','Status','Metrics'}) do root:GetChild(name):SetActive(true) end
  nativeReady=not scenery or lastNativeRequest==scenery.requestId;nativeWait=0;clearing=not nativeReady
  say('Status',clearing and 'UI已清理，等待服务端确认零实体' or 'UI与原生实体均已清理')
  print(clearing and 'ARTPRESS_CLEAR_PENDING' or 'ARTPRESS_CLEARED')
 end)
 click('Rebuild',function() dispose(cache[selected]);cache[selected]=nil;current=nil;show(selected) end)
 click('Motion',function() moving=not moving;say('Metrics','整组移动 '..tostring(moving));print('ARTPRESS_MOTION '..tostring(moving)) end)
 click('Reuse',function() reuse=not reuse;say('Metrics','缓存复用 '..tostring(reuse));print('ARTPRESS_REUSE '..tostring(reuse)) end)
 click('Auto',function() sweeping=not sweeping;sweepTime=0;if sweeping then show(1) end;say('Metrics','自动逐档 '..tostring(sweeping)..'，每档15秒，失败停止') end)
 local w,h=game.GetUICanvasSize();print('ARTPRESS_READY canvas='..w..'x'..h)
 show(selected);script:EnableUpdate(true)
end
function OnUpdate(dt)
 if dt<=0 or failed then return end
 phase=phase+dt
 if scenery and moving then scenery:update(dt) end
 if moving and current then
  for i,item in ipairs(current) do item.outer:SetAnchoredPosition(item.x+math.sin(phase*2+i)*12,item.y+math.sin(phase*3+i)*4) end
 end
 if scenery and not nativeReady then
  nativeWait=nativeWait+dt
  if nativeWait>15 then fail('原生场景未确认，停止采样','ARTSCENE_ACK_TIMEOUT') end
  return
 end
 elapsed=elapsed+dt;sweepTime=sweepTime+dt
 if elapsed>=(sweeping and 2 or 10) and not reported and current then
  samples[#samples+1]=dt
  if elapsed>=(sweeping and 10 or 40) then
   table.sort(samples);local total=0;for _,v in ipairs(samples) do total=total+v end
   local message=string.format('回调 mean=%.2f p95=%.2f p99=%.2f n=%d（非GPU FPS）',total/#samples*1000,samples[math.ceil(#samples*.95)]*1000,samples[math.ceil(#samples*.99)]*1000,#samples)
   say('Metrics',message);print('ARTPRESS_DT stage='..selected..' '..message);reported=true
  end
 end
 if sweeping and sweepTime>=15 then
  if selected==#stages then sweeping=false;print('ARTPRESS_SWEEP_DONE') else show(selected+1) end
 end
end
-- The engine already owns subtree destruction here; explicit Destroy is forbidden in this callback.
function OnDestroy() cache={};current=nil;scenery=nil;script:EnableUpdate(false);print('ARTPRESS_DESTROY') end
