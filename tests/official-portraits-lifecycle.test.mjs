import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
import {withPortraitVm} from './helpers/portrait-runtime-vm.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
function vm(code,options){assert(existsSync('src/lua/abyss_traveler_portraits.lua'),'bounded portrait runtime missing');withPortraitVm(code,options);}

test('final portrait refresh never restores the shipped yellow hero placeholder across battle transitions',()=>vm(`
assert(Theme.icon.player.status=='placeholder','regression must use the shipped player metadata')
-- UnitView hides placeholder portraits before GameUI syncs the portrait owner.
fallback:SetVisible(false)
a=Portraits.new(stage,nil,{battlePortrait=true});a:sync('battle',false,false,'ironclad')
assert(not fallback.visible,'building refresh restored the yellow placeholder')
for i=1,100 do a:tick();if a:status().battle.phase=='ready'then break end end
assert(a:status().battle.phase=='ready' and figure.visible and not fallback.visible)
a:sync('map',false,false,'ironclad');assert(not figure.visible and not fallback.visible,'paused refresh restored placeholder')
a:sync('battle',false,false,'ironclad')
for i=1,100 do a:tick();if a:status().battle.phase=='ready'then break end end
assert(a:status().battle.phase=='ready' and figure.visible and not fallback.visible,'next battle lost final image visibility')
a:release();assert(not fallback.visible,'release restored placeholder')
game.InstantiateClientUIControl=function()return nil end
a:sync('battle',false,false,'ironclad');a:tick()
assert(a:status().battle.phase=='failed' and not figure.visible and not fallback.visible,'failed refresh restored placeholder')
`,{themePlayer:nativeTheme.icon.player}));

test('ready setter release reentry cannot restore the shipped hero placeholder',()=>vm(`
a=Portraits.new(stage,nil,{battlePortrait=true});a:sync('battle',false,false,'ironclad')
local setter=fallback.SetVisible;local released=false
fallback.SetVisible=function(self,value)
 if not value and a:status().battle.phase=='ready' and not released then released=true;a:release()end
 return setter(self,value)
end
for i=1,100 do a:tick();if released then break end end
assert(released and a:status().battle.phase=='released','ready setter did not exercise reentrant release')
assert(not figure.visible and not fallback.visible,'stale ready publication restored yellow placeholder')
`,{themePlayer:nativeTheme.icon.player}));

test('a native library image remains a visible battle fallback through pause and failure',()=>vm(`
assert(type(Theme.icon.player)=='number' and Theme.icon.player>0)
a=Portraits.new(stage,nil,{battlePortrait=true});a:sync('battle',false,false,'ironclad')
assert(fallback.visible,'native library fallback hidden during building')
for i=1,100 do a:tick();if a:status().battle.phase=='ready'then break end end
assert(figure.visible and not fallback.visible)
a:sync('map',false,false,'ironclad');assert(fallback.visible and not figure.visible)
game.InstantiateClientUIControl=function()return nil end
a:sync('battle',false,false,'ironclad');a:tick()
assert(a:status().battle.phase=='failed' and fallback.visible and not figure.visible)
`,{themePlayer:nativeTheme.icon.cardArt.attack}));
for(const mode of ['nil','setter'])test(`production cached portrait recovers ${mode} failure at the next battle without frame retries`,()=>vm(`
assert(Asset.battle133.runtimeV2 and Asset.battle133.cache,'must exercise production generated cache')
local create=game.InstantiateClientUIControl;local calls=0
game.InstantiateClientUIControl=function(...)
 calls=calls+1
 if calls==4 then ${mode==='nil'?'return nil':"local c=create(...);c.SetSizeDelta=function()error('transient size setter rejection')end;return c"} end
 return create(...)
end
a=Portraits.new(stage,nil,{battlePortrait=true});a:sync('battle',false,false,'ironclad')
a:tick();assert(a:status().battle.phase=='failed' and LiveCount()==0 and not figure.visible)
local failedCalls=calls
for i=1,3 do a:sync('battle',false,false,'ironclad');a:tick()end
assert(calls==failedCalls,'failed portrait retried every refresh')
game.InstantiateClientUIControl=create
a:sync('map',false,false,'ironclad');a:sync('battle',false,false,'ironclad')
for i=1,500 do a:tick();if a:status().battle.phase=='ready'then break end end
assert(a:status().battle.phase=='ready' and figure.visible and not fallback.visible,'cached failure stranded formal portrait in the next battle')
local total=#controls
a:sync('map',false,false,'ironclad');a:sync('battle',false,false,'ironclad');a:tick()
assert(#controls==total and figure.visible,'successful cached portrait was rebuilt or stayed hidden')
`,{runtimeV2:true}));

test('a formal cached portrait that fails after ready can rebuild on the next battle',()=>vm(`
a=Portraits.new(stage,nil,{battlePortrait=true});a:sync('battle',false,false,'ironclad')
for i=1,500 do a:tick();if a:status().battle.phase=='ready'then break end end
assert(a:status().battle.phase=='ready' and figure.visible)
local original=figure.SetLocalScale;local total=#controls
figure.SetLocalScale=function()return false end
a:battlePose(0,0,1,1)
assert(a:status().battle.phase=='failed' and not figure.visible and LiveCount()==0,'ready failure must retire invalid geometry')
figure.SetLocalScale=original
a:sync('battle',false,false,'ironclad');a:tick();assert(#controls==total,'failed ready portrait retried without a scene boundary')
a:sync('map',false,false,'ironclad');a:sync('battle',false,false,'ironclad')
for i=1,500 do a:tick();if a:status().battle.phase=='ready'then break end end
assert(a:status().battle.phase=='ready' and figure.visible and #controls>total,'failed ready cache did not rebuild in next battle')
`,{runtimeV2:true}));

for(const display of [72,32])test(`avatar uses the actual ${display}px selection bust width through release and rebuild`,()=>vm(`
local bust=traveler:GetChild('hit'):GetChild('normal'):GetChild('bust')
rawset(bust,'sizeDeltaX',${display})
a=Portraits.new(stage,nil,{selectionAvatar=true});a:sync('menu',true,false,'ironclad')
assert(avatar.SetLocalScaleValue[1]==${display}/96 and avatar.SetLocalScaleValue[2]==${display}/96,'avatar runtime overwrote the displayed bust width')
a:release();assert(LiveCount()==0)
a:sync('menu',true,false,'ironclad');a:tick()
assert(avatar.SetLocalScaleValue[1]==${display}/96 and avatar.SetLocalScaleValue[2]==${display}/96,'avatar rebuild must retain the displayed width')
a:release();assert(LiveCount()==0)
`));

test('portrait creation is globally bounded at 64 including groups, hidden until complete, and scoped to traveler',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',true,false,'ironclad');assert(#controls==0)
local ticks=0
while a:status().avatar.phase=='building' or a:status().battle.phase=='building'do
 local before=#controls;a:tick();assert(#controls-before<=64);ticks=ticks+1;assert(ticks<150)
 if a:status().avatar.phase=='building'then assert(not avatar.visible)end
 if a:status().battle.phase=='building'then assert(not figure.visible and fallback.visible)end
end
assert(#controls==9294 and LiveCount()==9294 and avatar.visible and figure.visible and not fallback.visible)
local childCount={};for _,c in ipairs(controls)do childCount[c.parent]=(childCount[c.parent]or 0)+1 end
for _,n in pairs(childCount)do assert(n<=60,'too many direct children')end
assert(avatar.SetLocalScaleValue[1]==1/3 and avatar.SetLocalScaleValue[2]==1/3)
assert(math.abs(figure.SetLocalScaleValue[1]-(400/3)/133)<1e-12)
assert(a==Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true}));a:sync('battle',true,false,'ironclad');a:tick();assert(#controls==9294)
a:battlePose(4,-3,1.1,.9);assert(figure.SetAnchoredPositionValue[1]==4 and figure.SetAnchoredPositionValue[2]==-3)
assert(math.abs(figure.SetLocalScaleValue[1]-1.1*(400/3)/133)<1e-12)
a:sync('battle',false,false,'watcher');assert(LiveCount()==0 and fallback.visible and not figure.visible)
a:tick();assert(#controls==9294)
`));


test('release within instantiate cancels the returned control, prevents reentry and allows clean reactivation',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('menu',true,false,nil);local create=game.InstantiateClientUIControl
local calls=0;game.InstantiateClientUIControl=function(...)
 calls=calls+1;a:tick();a:sync('menu',true,false,nil);local c=create(...);a:release();return c
end
a:tick();assert(calls==1 and #controls==1 and LiveCount()==0 and not avatar.visible)
game.InstantiateClientUIControl=create;a:tick();assert(#controls==1)
a:sync('menu',true,false,nil);a:tick();assert(#controls==65 and LiveCount()==64)
a:release();assert(LiveCount()==0)
`));

for(const mode of ['nil','setter'])test(`portrait ${mode} failure restores fallback and does not auto-retry every frame`,()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad');local create=game.InstantiateClientUIControl;local calls=0
game.InstantiateClientUIControl=function(...)calls=calls+1;if calls==4 then ${mode==='nil'?'return nil':"local c=create(...);c.SetImage=function()error('setter rejected')end;return c"} end;return create(...)end
a:tick();assert(a:status().battle.phase=='failed' and LiveCount()==0 and fallback.visible and not figure.visible)
local total=#controls;for i=1,3 do a:sync('battle',false,false,'ironclad');a:tick()end;assert(#controls==total)
game.InstantiateClientUIControl=create;a:sync('map',false,false,'ironclad');a:sync('battle',false,false,'ironclad');a:tick();assert(LiveCount()==64)
a:release()
`));

test('failed child destruction retains its ancestors and reports truthful retained counts until explicit retry',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad');a:tick();local destroy=game.DestroyClientUIControl
local failed=controls[3];game.DestroyClientUIControl=function(c)if c==failed then return false end;return destroy(c)end
assert(not a:release());assert(LiveCount()==3 and a:status().battle.retained==3 and not figure.visible and fallback.visible)
a:sync('battle',false,false,'ironclad');a:tick();assert(LiveCount()==3)
game.DestroyClientUIControl=destroy;assert(a:release());assert(LiveCount()==0)
a:sync('battle',false,false,'ironclad');a:tick();assert(LiveCount()==64);a:release()
`));

test('engine destruction is a no-native-write tombstone and invalid asset metadata fails closed',()=>vm(`
local source=Asset.avatar96.sourceSha256;Asset.avatar96.sourceSha256='wrong';assert(not pcall(Portraits.new,stage,nil,{selectionAvatar=true,battlePortrait=true}));Asset.avatar96.sourceSha256=source
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('menu',true,false,nil);a:tick()
local create=game.InstantiateClientUIControl;local destroy=game.DestroyClientUIControl
for _,c in ipairs(controls)do destroy(c)end
game.DestroyClientUIControl=function()error('engine owns destruction')end
a:onEngineDestroy();a:onEngineDestroy();a:sync('menu',true,false,nil);a:tick();a:release()
assert(Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true})==a and a:status().avatar.phase=='destroyed' and LiveCount()==0)
`));

test('fallback release reentry cannot recursively paint or resurrect an in-flight host',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad');a:tick()
local set=fallback.SetVisible;local calls=0
fallback.SetVisible=function(self,v)calls=calls+1;assert(calls==1,'recursive fallback paint');a:release();a:tick();return set(self,v)end
assert(a:release());assert(calls==1 and LiveCount()==0 and not figure.visible)
`));

test('missing template binding, wrong ROOT and wrong native JSON identity cannot instantiate art',()=>vm(`
local root=Asset.avatar96.root;Asset.avatar96.root={0,0,95,96,.5,.5,.5,.5,.5,.5,1,1,0};assert(not pcall(Portraits.new,stage,nil,{selectionAvatar=true,battlePortrait=true}));Asset.avatar96.root=root
local json=Asset.battle133.jsonSha256;Asset.battle133.jsonSha256='wrong';assert(not pcall(Portraits.new,stage,nil,{selectionAvatar=true,battlePortrait=true}));Asset.battle133.jsonSha256=json
Asset.containerPrefabId=0;a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',true,false,'ironclad');a:tick()
assert(#controls==0 and a:status().avatar.phase=='failed' and a:status().battle.phase=='failed' and fallback.visible)
`));

test('setter cancellation and host death stop all remaining batch writes',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad');local create=game.InstantiateClientUIControl
local calls=0;game.InstantiateClientUIControl=function(...)
 local c=create(...);calls=calls+1;if calls==3 then c.SetImage=function()a:release()end end;return c
end
a:tick();assert(calls==3 and LiveCount()==0 and not figure.visible and fallback.visible)
game.InstantiateClientUIControl=create;a:sync('battle',false,false,'ironclad');rawset(figure,'alive',false);a:tick()
assert(a:status().battle.phase=='destroyed' and #controls==3)
`));

test('release during first host begin cancels the entire owner sync',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});local set=avatar.SetVisible;local once=false
avatar.SetVisible=function(self,v)if not once then once=true;a:release()end;return set(self,v)end
a:sync('battle',true,false,'ironclad');a:tick();assert(#controls==0,'cancelled sync restarted second host')
`));
test('dead-host pose retires without native setters and pose reentry is ignored',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad');a:tick()
local set=figure.SetAnchoredPosition;local calls=0
figure.SetAnchoredPosition=function(self,...)calls=calls+1;if calls<4 then a:battlePose(1,2,1,1)end;return set(self,...)end
a:battlePose(3,4,1,1);assert(calls==1,'recursive pose write')
rawset(figure,'alive',false);a:battlePose(3,4,1,1);assert(calls==1 and a:status().battle.phase=='destroyed')
`));
test('ready-transition release restores fallback after the stale native hide returns',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad')
local set=fallback.SetVisible;local once=false
fallback.SetVisible=function(self,v)if not v and not once then once=true;a:release()end;return set(self,v)end
while a:status().battle.phase=='building'do a:tick()end
assert(a:status().battle.phase=='released' and LiveCount()==0 and fallback.visible,'cancelled ready snapshot hid fallback')
`));
test('engine destruction inside fallback paint stops all subsequent native writes',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',true,false,'ironclad')
local first=traveler:GetChild('hit'):GetChild('normal'):GetChild('bust')
first.SetVisible=function()a:onEngineDestroy()end
fallback.SetVisible=function()error('post-destroy native write')end
local writes=0;local second=traveler:GetChild('hit'):GetChild('hover'):GetChild('bust')
second.SetVisible=function()writes=writes+1 end
a:tick();assert(writes==0,'paint continued after engine destroy')
`));
test('host death in position setter retires before the next native pose write',()=>vm(`
a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=true});a:sync('battle',false,false,'ironclad')
figure.SetAnchoredPosition=function()rawset(figure,'alive',false)end
local writes=0;figure.SetLocalScale=function()writes=writes+1 end
a:battlePose(3,4,1,1);assert(writes==0 and a:status().battle.phase=='destroyed','scale wrote a dead host')
`));
