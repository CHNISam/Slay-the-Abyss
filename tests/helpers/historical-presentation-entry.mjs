import assert from 'node:assert/strict';
import {cpSync,mkdirSync,mkdtempSync,rmSync,writeFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {runLua} from '../../scripts/test-lua.mjs';
import {materializeHistoricalPresentation} from './p0-presentation-inverse.mjs';
import {preRetirementSource} from './presentation-announcement-retirement.mjs';
import {historicalPresentationFixtures} from './historical-presentation-runner.mjs';
const script=process.argv[2],timeout=Number(process.argv[3]),started=Date.now();
assert.ok(historicalPresentationFixtures.includes(script),'only exact historical presentation fixtures');
const remaining=()=>{
 const value=timeout-(Date.now()-started);
 assert(value>0,'historical presentation fixture exceeded its original total deadline');return value;
};
mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/historical-presentation-'));
console.log(script.endsWith('_trace.lua')
 ? 'Historical presentation replay: all 81392 frozen native writes; current UI is verified separately.'
 : 'Historical presentation replay: all 361 frozen wording records; current wording is verified separately.');
try{
 for(const input of ['src','data','scripts','tools','config','tests/lua','package.json','package-lock.json','.release-please-manifest.json','CHANGELOG.md'])
  cpSync(input,join(directory,input),{recursive:true});
 materializeHistoricalPresentation(directory);
 writeFileSync(join(directory,'data/relics.json'),preRetirementSource('data/relics.json'));
 for(const builder of ['build-lua-data.mjs','build-ui.mjs','build-ui-theme.mjs']){
  const result=spawnSync(process.execPath,['scripts/'+builder],{cwd:directory,encoding:'utf8',timeout:remaining()});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 }
 const result=runLua(join(directory,script),{cwd:directory,timeout:remaining()});
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);process.exitCode=result.status;
}finally{rmSync(directory,{recursive:true,force:true});}
