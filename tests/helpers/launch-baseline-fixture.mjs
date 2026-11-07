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
  const realRoot=realpathSync.native(root);
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
  assert.equal(realpathSync.native(root),realRoot,'historical launch root changed during planning');
  const mounts=new Map(['tests/fixtures','node_modules'].map(path=>[path,realpathSync.native(resolve(implementationRoot,path))]));
  const directories=new Set(),files=[],links=[];
  for(const path of Object.keys(inputs)){
    let parent=path;
    while(parent.includes('/')){parent=parent.slice(0,parent.lastIndexOf('/'));directories.add(parent);}
  }
  function inspect(directory,prefix=''){
    for(const name of readdirSync(directory)){
      const path=prefix+name,target=historicalInputPath(root,path),entry=lstatSync(target);
      const actual=realpathSync.native(target);
      if(mounts.has(path)){
        // Some Windows junctions resolve correctly through the native API but
        // lstat classifies their reparse point as a directory. Require a real
        // alias to the freshly resolved owner, never an ordinary private copy.
        assert.notEqual(actual,historicalInputPath(realRoot,path),'declared historical oracle link: '+path);
        assert.equal(actual,mounts.get(path),'historical oracle link owner: '+path);
        links.push(path);continue;
      }
      assert(!entry.isSymbolicLink(),'original launch source must be a private file: '+path);
      assert.equal(actual,historicalInputPath(realRoot,path),'original launch source cannot alias another owner: '+path);
      if(entry.isDirectory()){
        assert(directories.has(path),'unregistered original launch input: '+path);
        inspect(target,path+'/');
      }else{
        assert(entry.isFile()&&Object.hasOwn(inputs,path),'unregistered original launch input: '+path);
        assert.deepEqual(readFileSync(target),inputs[path],'original launch source changed during planning: '+path);
        files.push(path);
      }
    }
  }
  inspect(root);
  assert.deepEqual(files.sort(),Object.keys(inputs).sort(),'complete original launch source inventory');
  assert.deepEqual(links.sort(),[...mounts.keys()].sort(),'complete historical oracle links');
  for(const path of outputs.keys()){
    assert(![...mounts.keys()].some(owner=>path===owner||path.startsWith(owner+'/')),'launch projection cannot target an oracle link: '+path);
    const target=historicalInputPath(root,path);
    assert.equal(!!lstatSync(target,{throwIfNoEntry:false}),Object.hasOwn(inputs,path),'original launch source existence: '+path);
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
      assert.equal(realpathSync.native(directory),join(realRoot,relative(root,directory)),'private launch directory cannot alias another owner');
      rmdirSync(directory);directory=dirname(directory);
    }
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
