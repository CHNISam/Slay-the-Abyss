import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {syncBuiltinESMExports} from 'node:module';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {materializeHistoricalPresentation} from './helpers/p0-presentation-inverse.mjs';

test('historical accepted inventory freshly validates each captured input without a second validation',()=>{
 const directory=mkdtempSync(join(tmpdir(),'p0-validated-projection-'));
 const original=crypto.createHash;let duplicateProjections=0;
 crypto.createHash=function(...args){
  const stack=new Error().stack;
  if(stack.includes('at project (')&&stack.includes('at Array.map ('))duplicateProjections++;
  return original.apply(this,args);
 };
 syncBuiltinESMExports();
 try{
  materializeHistoricalPresentation(directory);
  assert.equal(duplicateProjections,0,'already validated captured input must not repeat validation and linked reads');
 }finally{crypto.createHash=original;syncBuiltinESMExports();rmSync(directory,{recursive:true,force:true});}
});
