import {verifiedDeliverySources} from './delivery-source-composition.mjs';
import {pathToFileURL} from 'node:url';
import {fileURLToPath} from 'node:url';
import {createHistoricalBaseline,historicalInputPath} from './historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import { after } from 'node:test';
import {readFileSync,rmSync,rmdirSync,readdirSync,realpathSync,lstatSync,symlinkSync,existsSync,writeFileSync} from 'node:fs';
import {dirname,join,resolve,relative} from 'node:path';
import { relicCompletionInverse, requireRelicCompletionSource, preRelicCompletionSource } from './relic-completion-inverse.mjs';

// Frozen launch-ledger tests replay their whole matching source/data layer.
// Current relic feature tests continue to use production without projection.
export function launchBaselineFixture() {
  const previousCwd=process.cwd(),{directory:root,inputs}=createHistoricalBaseline();
  let complete=false;
  try{
  after(() => rmSync(root, { recursive: true, force: true }));
  const implementationRoot=fileURLToPath(new URL('../..',import.meta.url));
  const realRoot=realpathSync(root);
  process.chdir(root);
  // Keep the complete original filesystem unchanged while today's helpers
  // freshly validate their linked owners. Only this invocation owns the plan.
  const outputs=new Map(verifiedDeliverySources('pre379'));
  const source=path=>outputs.has(path)?outputs.get(path):
    (existsSync(historicalInputPath(root,path))?readFileSync(historicalInputPath(root,path),'utf8'):null);
  const validator='scripts/verify-launch-content.mjs',validatorSource=source(validator);
  assert.equal(typeof validatorSource,'string','complete delivery-base launch validator');
  for (const path of Object.keys(relicCompletionInverse.files)
    .filter(path => /^(data|src|scripts|config)\//.test(path))) {
    const current=source(path);
    requireRelicCompletionSource(path, current);
    const previous = preRelicCompletionSource(path, current);
    outputs.set(path,previous);
  }
  // Preserve the exact outer-base validator and its current packaging contract.
  outputs.set(validator,validatorSource);
  const excluded=Object.keys(inputs).filter(path=>!/^(?:data|src|scripts|config|tools|tests\/lua)\//.test(path));
  // A changed source, removed input or filesystem alias cannot borrow the
  // earlier archive validation. Preflight every mutation before the first one.
  assert.equal(realpathSync(root),realRoot,'historical launch root changed during planning');
  for(const path of new Set([...outputs.keys(),...excluded])){
    const target=historicalInputPath(root,path),entry=lstatSync(target,{throwIfNoEntry:false});
    assert.equal(!!entry,Object.hasOwn(inputs,path),'original launch source existence: '+path);
    if(!entry)continue;
    assert(entry.isFile()&&!entry.isSymbolicLink(),'original launch source must be a private file: '+path);
    assert.equal(realpathSync(target),historicalInputPath(realRoot,path),'original launch source cannot alias another owner: '+path);
    assert.deepEqual(readFileSync(target),inputs[path],'original launch source changed during planning: '+path);
  }
  for(const [path,value]of outputs){
    const target=historicalInputPath(root,path);
    if(value===null){if(existsSync(target))rmSync(target);}
    else writeFileSync(target,value);
  }
  for(const path of excluded){
    const target=historicalInputPath(root,path);rmSync(target);
    let directory=dirname(target);
    while(directory!==root&&readdirSync(directory).length===0){
      assert.equal(realpathSync(directory),join(realRoot,relative(root,directory)),'private launch directory cannot alias another owner');
      rmdirSync(directory);directory=dirname(directory);
    }
  }
  for(const directory of ['tests/fixtures','node_modules']){
    const target=join(root,directory);
    assert(lstatSync(target).isSymbolicLink(),'declared historical oracle link: '+directory);
    assert.equal(realpathSync(target),realpathSync(resolve(implementationRoot,directory)),'historical oracle link owner: '+directory);
  }
  for(const directory of ['tests/helpers','docs']){
    const target=join(root,directory);
    assert.equal(lstatSync(target,{throwIfNoEntry:false}),undefined,'historical metadata directory must be pruned: '+directory);
    symlinkSync(resolve(implementationRoot,directory),target,'junction');
  }
  complete=true;
  return root;
  }finally{
    process.chdir(previousCwd);
    if(!complete)rmSync(root,{recursive:true,force:true});
  }
}

// The validator constants and Lua probe must come from the same historical root.
export async function loadLaunchBaselineValidator(root){return import(pathToFileURL(join(root,'scripts/verify-launch-content.mjs')).href);}
