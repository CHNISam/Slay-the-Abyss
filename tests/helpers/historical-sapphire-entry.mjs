// Exact frozen Sapphire core only. Current Sapphire UI and relic acquisition
// retain direct production coverage and never enter this replay.
import assert from 'node:assert/strict';
import {join} from 'node:path';
import {createHistoricalRuntimeRoots,applyHistoricalRuntimeTarget} from './historical-runtime-root.mjs';
import {existsSync,readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {runLua} from '../../scripts/test-lua.mjs';
import {historicalSapphireFixtures} from './historical-presentation-runner.mjs';
import {relicCompletionInverse,relicCompletionAddedPaths,requireRelicCompletionSource,preRelicCompletionSource} from './relic-completion-inverse.mjs';
const script=process.argv[2],timeout=Number(process.argv[3]),started=Date.now();
assert.ok(historicalSapphireFixtures.includes(script),'only the four exact frozen Sapphire core fixtures');
assert.ok(Number.isSafeInteger(timeout)&&timeout>0&&timeout<=30000,'original Sapphire total deadline');
const remaining=()=>{const value=timeout-(Date.now()-started);assert.ok(value>0,'historical Sapphire exceeded its original total deadline');return value;};
const runtime=createHistoricalRuntimeRoots({source:false}),{directory}=runtime;
console.error('HISTORICAL_STAGED '+(Date.now()-started)+'ms');
console.log('Historical Sapphire core replay: exact pre-relic source tree; current UI and Matryoshka/Cursed Key verified separately.');
try{
 process.chdir(directory);
 // Preserve the existing retirement-first validation and full original hunk
 // checks. Apply only after every source/owner has been checked unchanged.
 const projected={};
 for(const path of relicCompletionAddedPaths){
  if(!existsSync(path))continue;
  requireRelicCompletionSource(path,readFileSync(path,'utf8'));projected[path]=null;
 }
 for(const [path,binding]of Object.entries(relicCompletionInverse.files)){
  if(binding.beforeSha256===null||!existsSync(path))continue;
  const source=readFileSync(path,'utf8');requireRelicCompletionSource(path,source);
  projected[path]=preRelicCompletionSource(path,source);
 }
 applyHistoricalRuntimeTarget(directory,projected);
 console.error('HISTORICAL_PROJECTED '+(Date.now()-started)+'ms');
 process.chdir(directory);
 const built=spawnSync(process.execPath,['scripts/build-lua-data.mjs'],{cwd:directory,encoding:'utf8',timeout:remaining(),windowsHide:true});
 assert.ifError(built.error);assert.equal(built.status,0,built.stdout+built.stderr);
 console.error('HISTORICAL_BUILT '+(Date.now()-started)+'ms');
 const result=runLua(join(directory,script),{cwd:directory,timeout:remaining()});
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);process.exitCode=result.status;
}finally{runtime.close();}
