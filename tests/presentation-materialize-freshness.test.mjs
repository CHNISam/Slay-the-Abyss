import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
// Each child changes only bytes returned by its own fs reader. No live source
// file is edited, and the drift begins after one successful current-source read.
for(const [path,sameLength]of [
 ['src/lua/abyss_game_ui.lua',true],
 ['src/lua/abyss_monster_intent_particle_view.lua',false],
])test('historical materialization rejects late fresh-read drift: '+path,()=>{
 const child=`import assert from 'node:assert/strict';import fs from 'node:fs';import{syncBuiltinESMExports}from'node:module';import{tmpdir}from'node:os';import{join}from'node:path';
 const {materializeHistoricalPresentation}=await import(${JSON.stringify(pathToFileURL(resolve('tests/helpers/p0-presentation-inverse.mjs')).href)});
 const directory=fs.mkdtempSync(join(tmpdir(),'p0-fresh-drift-'));
 const original=fs.readFileSync,target=${JSON.stringify(path)};let reads=0;
 fs.readFileSync=function(path,...args){const value=original.call(this,path,...args);
  if(String(path)===target&&++reads>=2){
   assert.equal(typeof value,'string');
   return ${sameLength ? "(value[0]==='!'?'?':'!')+value.slice(1)" : "value+'\\n-- unexpected linked drift\\n'"};
  }return value;};syncBuiltinESMExports();
 try{
  assert.throws(()=>materializeHistoricalPresentation(directory),/unreviewed|identity|missing|source|drift/);
  assert(reads>=2,'negative control reached the late owner read');
  console.log('P0_LATE_DRIFT_REJECTED '+target);
 }finally{fs.readFileSync=original;syncBuiltinESMExports();fs.rmSync(directory,{recursive:true,force:true});}`;
 const result=spawnSync(process.execPath,['--input-type=module','-e',child],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024,windowsHide:true});
 assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
 assert(result.stdout.includes('P0_LATE_DRIFT_REJECTED '+path));
});
