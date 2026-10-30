// Exact frozen Sapphire core only. Current Sapphire UI and relic acquisition
// retain direct production coverage and never enter this replay.
import assert from 'node:assert/strict';
import {cpSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {runLua} from '../../scripts/test-lua.mjs';
import {historicalSapphireFixtures} from './historical-presentation-runner.mjs';
import {materializeBeforeRelicCompletionSources,prepareRelicCompletionModuleRetirement} from './relic-completion-inverse.mjs';
const script=process.argv[2],timeout=Number(process.argv[3]),started=Date.now();
assert.ok(historicalSapphireFixtures.includes(script),'only the four exact frozen Sapphire core fixtures');
assert.ok(Number.isSafeInteger(timeout)&&timeout>0&&timeout<=30000,'original Sapphire total deadline');
const remaining=()=>{const value=timeout-(Date.now()-started);assert.ok(value>0,'historical Sapphire exceeded its original total deadline');return value;};
mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/historical-sapphire-'));
console.log('Historical Sapphire core replay: exact pre-relic source tree; current UI and Matryoshka/Cursed Key verified separately.');
try{
 for(const input of ['src','data','scripts','config','tests/lua'])cpSync(input,join(directory,input),{recursive:true});
 const retire=prepareRelicCompletionModuleRetirement(directory);
 materializeBeforeRelicCompletionSources(directory);retire();
 const built=spawnSync(process.execPath,['scripts/build-lua-data.mjs'],{cwd:directory,encoding:'utf8',timeout:remaining(),windowsHide:true});
 assert.ifError(built.error);assert.equal(built.status,0,built.stdout+built.stderr);
 const result=runLua(join(directory,script),{cwd:directory,timeout:remaining()});
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);process.exitCode=result.status;
}finally{rmSync(directory,{recursive:true,force:true});}
