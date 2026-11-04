// Explicit local replay, outside the normal regression set. No Git dependency.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {beforeSnapshotKeyTypes,keyTypesProof as proof} from '../tests/helpers/snapshot-key-types-inverse.mjs';
import {runLua} from './test-lua.mjs';

const dir='build/snapshot-key-kind';mkdirSync(dir,{recursive:true});
const after=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n');
const before=beforeSnapshotKeyTypes(after),hash=s=>createHash('sha256').update(s).digest('hex');
assert.equal(hash(before),proof.beforeSourceSha256);
assert.equal(hash(after),proof.afterSourceSha256);
writeFileSync(`${dir}/before.lua`,before);writeFileSync(`${dir}/after.lua`,after);
writeFileSync(`${dir}/bench.lua`,String.raw`
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Before=dofile('build/snapshot-key-kind/before.lua')
local After=dofile('build/snapshot-key-kind/after.lua')
local Run,Data=require('abyss_run'),require('abyss_data')
local root=Run.new(Data,'177136',{character='silent',experimental=true})
assert(Run.startCombat(root,'cultist_solo'))
local nodes,stack,top,fields,keySet,keys,tk={},{root},1,0,{},0,0
while top>0 do local t=stack[top];stack[top]=nil;top=top-1
 if not nodes[t]then nodes[t]=true
  for k,v in next,t do fields=fields+1;if keySet[k]==nil then keySet[k]=true;keys=keys+1 end
   if type(k)=='table'then top=top+1;stack[top]=k;tk=tk+1 end
   if type(v)=='table'then top=top+1;stack[top]=v end
  end
 end
end
local n=0;for _ in next,nodes do n=n+1 end
print('GRAPH',n,fields,keys,tk,root.data==Data,root.combat.catalog~=nil)
local function measure(M,count)
 local start=os.clock();for i=1,count do local restore=M.capture(root);assert(type(restore)=='function')end
 return os.clock()-start
end
measure(Before,1);measure(After,1)
for i=1,8 do
 local order=i%2==1 and {'before','after'}or {'after','before'}
 for _,name in ipairs(order)do print('SAMPLE',i,name,measure(name=='before'and Before or After,12))end
end
package.loaded.abyss_snapshot=After
dofile('tests/lua/snapshot_graph_equivalence.lua')
`);
const result=runLua(`${dir}/bench.lua`); // original 30-second entry budget
writeFileSync(`${dir}/replay.log`,result.stdout+result.stderr);
process.stdout.write(result.stdout);process.stderr.write(result.stderr);
assert.equal(result.status,0,result.stdout+result.stderr);
