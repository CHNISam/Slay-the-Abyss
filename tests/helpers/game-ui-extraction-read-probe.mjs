import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,rmSync} from 'node:fs';
import {createTracing} from 'node:trace_events';
import {preGameUiExtractionSource as project,gameUiExtractionProof as proof,gameUiExtractionAddedPaths as added} from './game-ui-extraction-source-inverse.mjs';
const mode=process.argv[2],path='config/architecture.json',source=readFileSync(path,'utf8');
const trace=createTracing({categories:['node.fs.sync']});
if(mode==='foreign'){
 const policy=JSON.parse(source);policy.unreviewed=true;const input=JSON.stringify(policy);
 trace.enable();assert.equal(project(path,input),input);trace.disable();
}else if(mode==='old'){
 const input=proof.files[path].beforeSource;
 trace.enable();assert.equal(project(path,input),input);trace.disable();
}else if(mode==='equivalent'){
 const input=JSON.stringify(JSON.parse(source));
 trace.enable();for(let i=0;i<2;i++)assert.equal(project(path,input),proof.files[path].beforeSource);trace.disable();
}else if(mode==='warm-drift'||mode==='warm-missing'){
 project(path,source);const owner=added.at(-1);
 if(mode==='warm-drift')writeFileSync(owner,readFileSync(owner,'utf8')+'\n-- actual owner drift\n');else rmSync(owner);
 trace.enable();assert.throws(()=>project(path,source),mode==='warm-drift'?/linked owner/:/ENOENT/);trace.disable();
}else assert.fail('known extraction trace mode');
process.stdout.write(JSON.stringify({mode})+'\n');
