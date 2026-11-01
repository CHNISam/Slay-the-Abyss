import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {preHandFanSource,handFanSourceLayer} from './helpers/hand-fan-source-inverse.mjs';
const repositoryRoot=fileURLToPath(new URL('../',import.meta.url));
test('hand-fan inverse restores exact develop sources and passes drift through',()=>{
  for(const path of Object.keys(handFanSourceLayer.files)){
    const current=readFileSync(path,'utf8');
    let base;
    try{base=execFileSync('git',['show',handFanSourceLayer.baseCommit+':'+path],{cwd:repositoryRoot,encoding:'utf8'});}catch{continue;}
    assert.equal(preHandFanSource(path,current),base.replaceAll('\r\n','\n'));
    const drift=current+'\n-- drift';
    assert.equal(preHandFanSource(path,drift),drift,'unknown edits stay visible to inner guards');
  }
});
