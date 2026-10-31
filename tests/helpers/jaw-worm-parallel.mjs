// Only the frozen independent Jaw Worm seed loop is partitioned. Both Fengari
// isolates live inside one process, so the original spawnSync deadline kills
// every worker too; no child/grandchild process can survive that deadline.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {Worker,isMainThread,workerData} from 'node:worker_threads';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';

const require=createRequire(import.meta.url);
const frozen='a08bb7702e8f43c1b7e2eff75922d4c7c70ab0a884a5609ac77d971d4a8c7082';
const quote=source=>{let equals='';while(source.includes(']'+equals+']'))equals+='=';return '['+equals+'['+source+']'+equals+']';};
function replaceOnce(source,before,after){assert.equal(source.split(before).length,2,'one exact reviewed seed hunk');return source.replace(before,after);}
// Exact raw graph observations, not a state-reset or immutable-subtree shortcut.
export const sharedDataGuard=`
function __jawSharedDataGuard(data)
 local seen,pending,records={},{data},{}
 while #pending>0 do
  local object=table.remove(pending)
  if not seen[object]then
   seen[object]=true
   local values={};local meta=getmetatable(object)
   records[#records+1]={object=object,values=values,meta=meta}
   if type(meta)=='table'then pending[#pending+1]=meta end
   for k,v in next,object do
    values[k]=v
    if type(k)=='table'then pending[#pending+1]=k end
    if type(v)=='table'then pending[#pending+1]=v end
   end
  end
 end
 return function()
  for _,record in ipairs(records)do
   assert(rawequal(getmetatable(record.object),record.meta),'shared data metatable changed')
   for k,v in next,record.values do assert(rawequal(rawget(record.object,k),v),'shared data field changed')end
   for k in next,record.object do assert(rawget(record.values,k)~=nil,'shared data field added')end
  end
 end
end
`;
export function jawWormParts(input){
 const source=input.replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(source).digest('hex'),frozen,'unreviewed Jaw Worm source');
 return [[0,7,12],[8,15,13]].map(([first,last,lastGroup])=>{
  let body=replaceOnce(source,'for seed=0,15 do',`for seed=${first},${last} do`);
  body=replaceOnce(body,'local Combat, data = require("abyss_combat"), require("abyss_data")',
   'local Combat, data = require("abyss_combat"), require("abyss_data")\nlocal sharedDataUnchanged=__jawSharedDataGuard(data)');
  body=replaceOnce(body,'            end\n        end\n    end\n    local untouched=battle();',
   '            end\n        end\n        sharedDataUnchanged(); print("JAW_WORM_SHARED_DATA "..seed)\n    end\n    local untouched=battle();');
  body=replaceOnce(body,'                assert(next~=T or e.jawLast~=T or e.jawPrevious~=T)\n            end',
   '                assert(next~=T or e.jawLast~=T or e.jawPrevious~=T)\n            end\n            print("JAW_WORM_ROUND "..seed.." ".._)');
  const untouched='local untouched=battle(); eq(untouched.enemies[1].jawLast,nil); eq(Combat.intent(untouched,1).id,C)';
  body=replaceOnce(body,untouched,last===15?untouched+'; print("JAW_WORM_UNTOUCHED")':'-- Untouched actor assertion belongs to the last partition only.');
  return sharedDataGuard+`\nassert(load(${quote(body+"\nsharedDataUnchanged()\n")}))(12,${lastGroup})`;
 });
}

// Kept here rather than adding a new scheduler. Production raw scheduling still
// classifies this whole fixture as exclusive; this only uses its second core.
export async function runLuaThreadParts(parts,{deadline,maxBuffer}={}){
 assert.ok(Array.isArray(parts)&&parts.length===2&&parts.every(x=>typeof x==='string'),'two Lua partitions required');
 assert.ok(Number.isFinite(deadline)&&Number.isSafeInteger(maxBuffer)&&maxBuffer>0,'finite deadline and positive output budget required');
 const cli=require.resolve('fengari-node-cli/src/lua-cli.js');
 const workers=[],records=parts.map(()=>({stdout:[],stderr:[],code:null}));
 let bytes=0,failure='';
 const stop=message=>{if(failure)return;failure=message;for(const w of workers)void w.terminate();};
 const remaining=deadline-Date.now();
 if(remaining<=0)return {status:1,stdout:'',stderr:'Jaw Worm aggregate deadline expired before startup\n'};
 const timer=setTimeout(()=>stop('Jaw Worm aggregate deadline exceeded'),remaining);
 const env={...process.env,LUA_PATH:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_PATH_5_3:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_INIT:'',LUA_INIT_5_3:''};
 delete env.NODE_TEST_CONTEXT;
 try{
  await Promise.all(parts.map((lua,index)=>new Promise(done=>{
   if(failure){records[index].code=1;done();return;}
   let worker;
   try{worker=new Worker(new URL(import.meta.url),{workerData:{lua,cli},stdout:true,stderr:true,env});}
   catch(error){records[index].code=1;stop(error.message);done();return;}
   workers.push(worker);
   for(const stream of ['stdout','stderr'])worker[stream].on('data',chunk=>{
    if(bytes+chunk.length>maxBuffer){stop('Jaw Worm shared output budget exceeded');return;}
    bytes+=chunk.length;records[index][stream].push(chunk);
   });
   worker.on('error',error=>stop(error.stack||error.message));
   worker.on('exit',code=>{records[index].code=code;done();});
  })));
 }finally{clearTimeout(timer);await Promise.all(workers.map(worker=>worker.terminate()));}
 return {status:failure||records.some(r=>r.code!==0)?1:0,
  stdout:records.map(r=>Buffer.concat(r.stdout).toString('utf8')).join(''),
  stderr:records.map(r=>Buffer.concat(r.stderr).toString('utf8')).join('')+(failure?failure+'\n':'')};
}

async function main(){
 const deadline=Number(process.argv[2]),maxBuffer=Number(process.argv[3]);
 assert.equal(readFileSync('tests/lua/jaw_worm_ai_slice_3.lua','utf8').replaceAll('\r\n','\n'),'assert(loadfile("tests/lua/jaw_worm_ai.lua"))(12,13)\n','unreviewed Jaw Worm tail entry');
 const parts=jawWormParts(readFileSync('tests/lua/jaw_worm_ai.lua','utf8'));
 // Reserve a bounded cleanup interval inside, never in addition to, the outer
 // original deadline. The outer process guard remains authoritative.
 const result=await runLuaThreadParts(parts,{deadline:deadline-100,maxBuffer});
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);
 if(result.status!==0){process.exitCode=1;return;}
 const actual=[...result.stdout.matchAll(/^JAW_WORM_ROUND (\d+) (\d+)$/gm)].map(m=>[Number(m[1]),Number(m[2])]);
 const expected=[];for(let seed=0;seed<16;seed++)for(let round=1;round<=24;round++)expected.push([seed,round]);
 assert.deepEqual(actual,expected,'all original seeds/rounds execute exactly once');
 assert.deepEqual([...result.stdout.matchAll(/^JAW_WORM_SHARED_DATA (\d+)$/gm)].map(m=>Number(m[1])),Array.from({length:16},(_,i)=>i),'shared input remains unchanged after every seed');
 assert.equal((result.stdout.match(/^JAW_WORM_UNTOUCHED$/gm)||[]).length,1,'untouched actor assertion executes once');
 assert.equal((result.stdout.match(/^JAW_WORM_AI_CASE 13$/gm)||[]).length,1,'original rollback group executes once');
 console.log('JAW_WORM_PARALLEL_PASS 16 seeds 384 rounds');
}
if(!isMainThread){
 process.argv=[process.execPath,workerData.cli,'-e',workerData.lua];require(workerData.cli);
}else if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 try{await main();}catch(error){console.error(error.stack||error);process.exitCode=1;}
}
