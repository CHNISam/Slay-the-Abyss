local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Asset=require('abyss_traveler_portrait_assets')
Asset.imagePrefabId,Asset.containerPrefabId=41,73
local lowpolyHero=assert(Asset.lowpolyHero)
assert(#lowpolyHero.rows==2011 and #Asset.avatar96.rows==457 and #Asset.selection133.rows==1940 and #Asset.battle133.rows==4315)
local function profile(useLowpoly,battleEnabled,expected)
Asset.lowpolyHero=useLowpoly and lowpolyHero or nil
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local panel=root:GetChild('characterPanel')
panel:SetVisible(false)
local selection=panel:GetChild('details'):GetChild('officialSelectionFigure')
local avatar=panel:GetChild('traveler'):GetChild('officialAvatar')
local battle=root:GetChild('battlePanel'):GetChild('hero'):GetChild('officialFigure')
local created,destroyed=0,0
local counts={selection=0,avatar=0,battle=0}
local foreground=false
local methods={}
function methods:SetVisible(value)self.visible=value end
function methods:SetActive(value)self.active=value end
function methods:SetImage(source,id)assert(source=='static' and type(id)=='number');self.imageId=id end
for _,name in ipairs({'SetAnchorMin','SetAnchorMax','SetPivot','SetSizeDelta','SetLocalScale','SetLocalRotation','SetAnchoredPosition','SetAsLastSibling'})do
 methods[name]=function()end
end
for _,host in ipairs({selection,avatar,battle})do for name,method in pairs(methods)do host[name]=method end end
Enum={ImageSource={StaticReference='static'},ImageType={Stretch=23}}
Color={FromRGBA=function(...)return {...}end}
game={InstantiateClientUIControl=function(index,parent)
 assert(index==41 or index==73,'portrait must use bound native templates')
 created=created+1
 if created==1 then assert(parent==selection,'thumbnail preloaded before the main figure')end
 local owner,name=parent,nil
 while owner do
  if owner==selection then name='selection';break elseif owner==avatar then name='avatar';break elseif owner==battle then name='battle';break end
  owner=owner.parent
 end
 assert(name,'native control escaped its dedicated portrait host')
 assert(name~='battle' or foreground,'battle art was preloaded')
 counts[name]=counts[name]+1
 return setmetatable({parent=parent,alive=true},{__index=methods})
end,DestroyClientUIControl=function()destroyed=destroyed+1 end}
local portraits=require('abyss_traveler_portraits').new(root,nil,{selectionAvatar=true,battlePortrait=battleEnabled})
local function tick()
 local before=created;portraits:tick()
 assert(created-before<=64 and portraits:status().batchSize==64,'shared portrait creation budget exceeded')
end
local function queue()
 local s=portraits:status();local rows={}
 for _,name in ipairs({'selection','avatar','battle'})do local v=s[name]
  assert(v.phase~='failed' and v.phase~='release_failed',name..': '..tostring(v.reason))
  rows[#rows+1]=name..':'..v.phase..':'..tostring(v.nextIndex)..':'..v.owned
 end
 return table.concat(rows,'|')
end
local function record(label)
 print('PRELOAD_PROFILE',useLowpoly and 'lowpoly' or 'legacy',battleEnabled,label,
  'selection',counts.selection,'avatar',counts.avatar,'battle',counts.battle,'destroyed',destroyed,queue())
end
portraits:sync('menu',false,false,'ironclad')
tick();assert(created==0,'legacy sync unexpectedly enabled preloading')
portraits:sync('menu',false,false,'ironclad',true)
assert(created==0,'preload sync created geometry synchronously')
tick();assert(created>0 and created<=64 and not panel.visible,'preload was unbounded or revealed selection')
assert(counts.battle==0 and destroyed==0,'background preload must not build battle art or enter failure cleanup')
record('partial-preload')
local partial=created
portraits:sync('map',false,false,'ironclad',true)
local paused=queue()
for _=1,10 do tick()end
assert(created==partial and destroyed==0,'leaving preload did not pause without destroying')
assert(queue()==paused and not selection.visible and not avatar.visible and not selection.active and not avatar.active,
 'leaving preload advanced a paused queue or kept its hosts active')
record('map-paused')
portraits:sync('menu',false,true,'ironclad',true)
for _=1,10 do tick()end
assert(created==partial and destroyed==0 and queue()==paused,'stopped background preload was not cancelled')
record('stopped-partial')
-- A real battle may build its own foreground portrait while both preload queues stay paused.
local background=counts.selection+counts.avatar
foreground=true;portraits:sync('battle',false,false,'ironclad',true);tick()
assert(counts.selection+counts.avatar==background,'foreground battle resumed hidden selection preload')
assert((battleEnabled and counts.battle>0)or(not battleEnabled and counts.battle==0),'battle flag did not own foreground construction')
record('foreground-battle')
portraits:sync('map',false,false,'ironclad',true);foreground=false
local battlePartial=counts.battle;local allPaused=queue();local pausedTotal=created
for _=1,10 do tick()end
assert(created==pausedTotal and counts.battle==battlePartial and destroyed==0 and queue()==allPaused,
 'leaving battle advanced a paused portrait queue')
record('all-paused')
portraits:sync('menu',false,false,'ironclad',true)
for _=1,500 do tick();if portraits:status().avatar.phase=='ready'then break end end
local status=portraits:status()
assert(status.selection.phase=='ready' and status.avatar.phase=='ready')
assert(counts.selection+counts.avatar==expected and counts.battle==battlePartial and destroyed==0 and not panel.visible,
 'unexpected preload count, foreground construction or visible selection')
record('preload-ready')
local readyTotal=created
panel:SetVisible(true)
portraits:sync('menu',true,false,'ironclad',true);tick()
assert(created==readyTotal and destroyed==0,'entering selection rebuilt preloaded art')
portraits:sync('menu',false,true,'ironclad',true);tick()
assert(created==readyTotal and destroyed==0 and not selection.visible and not avatar.visible,'stopped preload kept active hosts')
record('stopped-ready')
foreground=true;portraits:sync('battle',false,false,'ironclad',true)
for _=1,500 do tick();if not battleEnabled or portraits:status().battle.phase=='ready'then break end end
assert(counts.selection+counts.avatar==expected,'foreground battle rebuilt cached selection')
assert((battleEnabled and counts.battle==4389 and portraits:status().battle.phase=='ready')or
 (not battleEnabled and counts.battle==0 and portraits:status().battle.phase=='disabled'),'foreground portrait source inventory mismatch')
record('battle-ready')
local complete=created
portraits:sync('map',false,false,'ironclad',true);foreground=false;tick()
assert(created==complete and destroyed==0,'leaving completed battle rebuilt or destroyed cached art')
foreground=true;portraits:sync('battle',false,false,'ironclad',true);tick()
assert(created==complete and destroyed==0,'returning to battle rebuilt cached art')
portraits:onEngineDestroy();tick()
assert(destroyed==0 and created==complete,'engine teardown called native destruction')
end
profile(true,true,2512)
profile(true,false,2512)
profile(false,true,2440)
Asset.lowpolyHero=lowpolyHero
print('SELECTION_PORTRAIT_PRELOAD_PASS')
