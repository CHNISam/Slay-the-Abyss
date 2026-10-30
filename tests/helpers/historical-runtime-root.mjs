// Runtime replays use complete original source trees. Current implementations
// of the projection helpers and immutable oracle records are read-only links.
import assert from 'node:assert/strict';
import {writeFileSync,mkdirSync,mkdtempSync,rmSync,existsSync,lstatSync,statSync,readdirSync,symlinkSync,cpSync,realpathSync} from 'node:fs';
import {join,dirname,resolve,relative,isAbsolute,sep} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {loadHistoricalRuntimeBundle,historicalInputPath} from './historical-baseline-inputs.mjs';

const implementationRoot=fileURLToPath(new URL('../..',import.meta.url));
function readonlyResources(source,target){
 if(!existsSync(source))return;
 if(existsSync(target)){
  if(lstatSync(target).isSymbolicLink()||!statSync(source).isDirectory())return;
  for(const name of readdirSync(source))readonlyResources(join(source,name),join(target,name));
  return;
 }
 mkdirSync(dirname(target),{recursive:true});
 if(statSync(source).isDirectory())symlinkSync(source,target,process.platform==='win32'?'junction':'dir');
 else cpSync(source,target,{errorOnExist:true,force:false});
}
export function writeHistoricalRuntimeSnapshot(directory,inputs){
 mkdirSync(directory,{recursive:true});
 const root=realpathSync(directory),implementation=realpathSync(implementationRoot),inside=relative(implementation,root);
 assert.ok(inside&&((inside.startsWith('..'+sep))||isAbsolute(inside)),'historical source must be outside the working tree');
 // Write original inputs before any resource aliases. Repeated calls must not
 // write through an alias created by an earlier resource mount either.
 for(const [path,bytes]of Object.entries(inputs)){
  const target=historicalInputPath(root,path);
  for(let parent=dirname(target);parent!==root;parent=dirname(parent))
   if(existsSync(parent))assert.ok(!lstatSync(parent).isSymbolicLink(),'original input traverses readonly resource alias: '+path);
  if(existsSync(target))assert.ok(!lstatSync(target).isSymbolicLink(),'original input is a readonly alias: '+path);
  mkdirSync(dirname(target),{recursive:true});writeFileSync(target,bytes);
 }
 // art/performance contains archived JSON. Merge only missing resource entries
 // under that real directory; never replace art or overlay a linked directory.
 readonlyResources(join(implementationRoot,'art'),join(root,'art'));
 for(const path of ['tests/helpers','tests/fixtures','node_modules'])
  readonlyResources(join(implementationRoot,path),join(root,path));
 return root;
}
export function applyHistoricalRuntimeTarget(directory,target){
 const root=realpathSync(directory),inside=relative(realpathSync(implementationRoot),root);
 assert.ok(inside&&(inside.startsWith('..'+sep)||isAbsolute(inside)),'historical target must be outside the working tree');
 for(const [path,bytes]of Object.entries(target)){
  const output=historicalInputPath(root,path);
  for(let parent=dirname(output);parent!==root;parent=dirname(parent))
   if(existsSync(parent))assert.ok(!lstatSync(parent).isSymbolicLink(),'target traverses readonly resource alias: '+path);
  if(existsSync(output))assert.ok(!lstatSync(output).isSymbolicLink(),'runtime source target is a readonly alias: '+path);
  if(bytes===null)rmSync(output,{force:true});
  else{mkdirSync(dirname(output),{recursive:true});writeFileSync(output,bytes);}
 }
}
export function createHistoricalRuntimeRoots({target:name,source:includeSource=true}={}){
 assert.equal(typeof includeSource,'boolean','explicit historical source-root selection');
 const previous=process.cwd(),{inputs,target}=loadHistoricalRuntimeBundle(name);
 const sourceRoot=includeSource?mkdtempSync(join(tmpdir(),'abyss-historical-source-')):undefined;
 let directory;
 const close=()=>{
  process.chdir(previous);
  for(const root of [directory,sourceRoot].filter(Boolean)){
   const resolved=resolve(root),within=relative(resolve(tmpdir()),resolved);
   assert.ok(within&&!isAbsolute(within)&&!within.startsWith('..')&&within.startsWith('abyss-historical-'),'owned historical temporary root');
   rmSync(resolved,{recursive:true,force:true});
  }
 };
 try{
  directory=mkdtempSync(join(tmpdir(),'abyss-historical-runtime-'));
  if(sourceRoot)writeHistoricalRuntimeSnapshot(sourceRoot,inputs);
  writeHistoricalRuntimeSnapshot(directory,inputs);
  if(target)applyHistoricalRuntimeTarget(directory,target);
  return {sourceRoot,directory,inputs,close};
 }catch(error){close();throw error;}
}
