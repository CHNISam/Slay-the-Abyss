import test from 'node:test';
import {withPortraitVm as vm} from './helpers/portrait-runtime-vm.mjs';

test('default-off portrait controller does not require assets or touch either omitted host',()=>vm(`
Asset=nil;stage.GetChild=function()error('disabled host lookup')end
assert(PortraitAssetLoads==0,'module import eagerly loaded portrait payload')
assert(Portraits.new(stage)==nil)
assert(Portraits.new(stage,nil,{selectionAvatar=false,battlePortrait=false})==nil)
assert(Portraits.new(stage,nil,{selectionAvatar='true',battlePortrait=1})==nil)
assert(PortraitAssetLoads==0 and #controls==0)
`));

test('avatar-only candidate ignores missing battle data/host and preserves all battle fallback ownership',()=>vm(`
Asset.battle133=nil;stage.children.battlePanel=nil
fallback.SetVisible=function()error('disabled battle fallback touched')end
local a=Portraits.new(stage,nil,{selectionAvatar=true,battlePortrait=false})
assert(PortraitAssetLoads==1 and a:status().battle.phase=='disabled')
a:sync('battle',true,false,'ironclad');a:battlePose(1,2,1,1)
while a:status().avatar.phase=='building'do a:tick()end
assert(a:status().avatar.phase=='ready' and #controls==4905 and avatar.visible)
a:sync('battle',false,false,'ironclad');assert(LiveCount()==0)
a:sync('menu',true,false,nil);a:tick();assert(LiveCount()==64)
a:release();assert(LiveCount()==0);a:onEngineDestroy();a:tick();a:battlePose(1,2,1,1)
assert(a:status().avatar.phase=='destroyed' and a:status().battle.phase=='disabled')
`));

test('battle-only candidate ignores missing selection data/host and preserves feedback and stop cleanup',()=>vm(`
Asset.avatar96=nil;stage.children.characterPanel=nil
avatar.SetVisible=function()error('disabled selection host touched')end
local a=Portraits.new(stage,nil,{selectionAvatar=false,battlePortrait=true})
assert(PortraitAssetLoads==1 and a:status().avatar.phase=='disabled')
a:sync('battle',true,false,'ironclad')
while a:status().battle.phase=='building'do a:tick()end
assert(a:status().battle.phase=='ready' and #controls==4389 and figure.visible and not fallback.visible)
a:battlePose(4,-3,1.1,.9);assert(figure.SetAnchoredPositionValue[1]==4)
a:sync('battle',true,true,'ironclad');assert(LiveCount()==0 and fallback.visible)
a:sync('battle',false,false,'ironclad');a:tick();assert(LiveCount()==64)
a:release();assert(LiveCount()==0);a:onEngineDestroy();a:tick()
assert(a:status().battle.phase=='destroyed' and a:status().avatar.phase=='disabled')
`));
