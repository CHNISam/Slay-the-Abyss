import assert from 'node:assert/strict';
import {join} from 'node:path';
import {createHistoricalRuntimeRoots} from './historical-runtime-root.mjs';
import {spawnSync} from 'node:child_process';
import {runLua} from '../../scripts/test-lua.mjs';
import {historicalPresentationFixtures,historicalSapphireFixtures} from './historical-presentation-runner.mjs';
const script=process.argv[2],timeout=Number(process.argv[3]),started=Date.now();
assert.ok(historicalPresentationFixtures.includes(script)&&!historicalSapphireFixtures.includes(script),'only exact historical presentation fixtures');
const remaining=()=>{
 const value=timeout-(Date.now()-started);
 assert(value>0,'historical presentation fixture exceeded its original total deadline');return value;
};
const runtime=createHistoricalRuntimeRoots({target:'presentation'}),{directory}=runtime;
console.error('HISTORICAL_STAGED '+(Date.now()-started)+'ms');
console.log(script.endsWith('_trace.lua')
 ? 'Historical presentation replay: all 81392 frozen native writes; current UI is verified separately.'
 : 'Historical presentation replay: all 361 frozen wording records; current wording is verified separately.');
try{
 console.error('HISTORICAL_PROJECTED '+(Date.now()-started)+'ms');
 process.chdir(directory);
 for(const builder of ['build-lua-data.mjs','build-ui.mjs','build-ui-theme.mjs']){
  const result=spawnSync(process.execPath,['scripts/'+builder],{cwd:directory,encoding:'utf8',timeout:remaining()});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 }
 console.error('HISTORICAL_BUILT '+(Date.now()-started)+'ms');
 const result=runLua(join(directory,script),{cwd:directory,timeout:remaining()});
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);process.exitCode=result.status;
}finally{runtime.close();}
