import test from 'node:test';
import {readFileSync} from 'node:fs';
import {withPortraitVm as vm} from './helpers/portrait-runtime-vm.mjs';
for(const [kind,wanted] of [['avatar96',"a:sync('menu',true,false,nil)"],['battle133',"a:sync('battle',false,false,'ironclad')"]])test(`${kind}: every original native property and setter order survives grouping and uniform host fit`,()=>{
 const original=readFileSync(`art/characters/traveler-geo/portraits/${kind}/runtime-no-snapshot.lua`,'utf8').replace('local IMAGE_PREFAB_ID = 0','local IMAGE_PREFAB_ID = 1234');
 vm(`a=Portraits.new(stage);${wanted};for i=1,80 do a:tick()end
 local images=Images();assert(#images==#oracle)
 for i,c in ipairs(images)do Equal(c.trace,oracle[i])end
 a:release();assert(LiveCount()==0)`,{before:`${original}\nOnStart();oracle={};for i,c in ipairs(controls)do oracle[i]=c.trace end;OnDestroy();controls={};destroyed=0`});
});
