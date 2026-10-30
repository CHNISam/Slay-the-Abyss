import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {syncBuiltinESMExports} from 'node:module';
import {join,resolve} from 'node:path';
import {materializeHistoricalPresentation} from './helpers/p0-presentation-inverse.mjs';

test('each materialization reads its direct current input once, with a fresh inventory on the next call',()=>{
 fs.mkdirSync('build',{recursive:true});
 const directory=fs.mkdtempSync(resolve('build/presentation-once-'));
 const read=fs.readFileSync,counts=new Map();
 let drift=false,missing=false;
 try {
  for(const path of ['src','data','scripts','tools','config','tests/lua'])fs.cpSync(path,join(directory,path),{recursive:true});
  fs.readFileSync=function(path,...args){
   const caller=new Error().stack.split('\n')[2];
   if(caller.includes('p0-presentation-inverse.mjs'))counts.set(String(path),(counts.get(String(path))??0)+1);
   if(caller.includes('p0-presentation-inverse.mjs')&&path==='src/lua/abyss_node_ui.lua'){
    if(missing)throw new Error('missing current root');
    if(drift)return read.call(this,path,...args)+'\n-- unreviewed drift\n';
   }
   return read.call(this,path,...args);
  };syncBuiltinESMExports();
  materializeHistoricalPresentation(directory);
  assert.ok(counts.size>20,'the real full materializer read its current inventory');
  assert.deepEqual([...counts].filter(([,n])=>n!==1),[],'duplicate top-level source projection reads waste the shared replay budget');
  const first=new Map(counts);counts.clear();
  // Re-copy current bytes: this is a separate invocation, not a warm source snapshot.
  fs.rmSync(directory,{recursive:true,force:true});fs.mkdirSync(directory);
  for(const path of ['src','data','scripts','tools','config','tests/lua'])fs.cpSync(path,join(directory,path),{recursive:true});
  materializeHistoricalPresentation(directory);
  assert.deepEqual(counts,first,'a second invocation freshly reads the complete same inventory');
  const root=join(directory,'src/lua/abyss_node_ui.lua'),before=read(root,'utf8');
  drift=true;assert.throws(()=>materializeHistoricalPresentation(directory),/current-only Node materialization/);drift=false;
  missing=true;assert.throws(()=>materializeHistoricalPresentation(directory),/missing current root/);
  assert.equal(read(root,'utf8'),before,'warm missing/drifting input is rejected before destination writes');
 }finally{fs.readFileSync=read;syncBuiltinESMExports();fs.rmSync(directory,{recursive:true,force:true});}
});
