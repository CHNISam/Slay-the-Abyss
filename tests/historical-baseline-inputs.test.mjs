import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {withHistoricalBaseline,readHistoricalBaselineSource,historicalInputPath,historicalTest} from './helpers/historical-baseline-inputs.mjs';
import {preAcceptedPr323Source,requirePr323Source,pr323AcceptedSourceInverse} from './helpers/pr323-accepted-source-inverse.mjs';

test('historical source roots are fresh real files and public guards observe actual drift',()=>{
 const previous=process.cwd(),path='src/lua/abyss_battle_ui.lua',live=readFileSync(path,'utf8');
 let first;
 withHistoricalBaseline(()=>{
  first=process.cwd();assert.notEqual(first,previous);
  const source=readFileSync(path,'utf8');
  assert.equal(source,readHistoricalBaselineSource(path));
  assert.equal(preAcceptedPr323Source(path,source),pr323AcceptedSourceInverse.files[path].acceptedSource);
  const changed=source+'\n-- unknown actual source drift\n';
  writeFileSync(path,changed);
  assert.throws(()=>requirePr323Source(path,readFileSync(path,'utf8')),/unreviewed integrated/);
  assert.equal(preAcceptedPr323Source(path,readFileSync(path,'utf8')),changed);
 });
 assert.equal(process.cwd(),previous);assert.equal(existsSync(first),false);
 assert.equal(readFileSync(path,'utf8'),live,'the working production file was never aliased or overwritten');
 withHistoricalBaseline(()=>{
  assert.notEqual(process.cwd(),first);
  assert.equal(readFileSync(path,'utf8'),readHistoricalBaselineSource(path),'a dirty prior root cannot leak into another historical case');
 });
});

test('historical callbacks restore cwd and remove their root when a guard throws',()=>{
 const previous=process.cwd();let directory;
 assert.throws(()=>withHistoricalBaseline(()=>{directory=process.cwd();throw Error('deliberate callback failure');}),/deliberate callback failure/);
 assert.equal(process.cwd(),previous);assert.equal(existsSync(directory),false);
 assert.throws(()=>readHistoricalBaselineSource('../unregistered.lua'),/registered original input/);
 assert.equal(resolve(process.cwd()),resolve(previous));
});

test('historical snapshot paths reject absolute and cross-drive original inputs before writing',()=>{
 for(const path of ['/outside.lua','C:/outside.lua','C:outside.lua','\\\\server\\outside.lua','../outside.lua'])
  assert.throws(()=>historicalInputPath(process.cwd(),path),/relative original input|isolated historical input/);
});

test('historical registration rejects the original async callback before its body executes',()=>{
 let entered=false;
 const callback=async()=>{entered=true;await Promise.resolve();};
 assert.throws(()=>historicalTest('must never register',callback),/callbacks must be synchronous/);
 assert.equal(entered,false);
 assert.throws(()=>withHistoricalBaseline(callback),/callbacks must be synchronous/);
 assert.equal(entered,false);
});
