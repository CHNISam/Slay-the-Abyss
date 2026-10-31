import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {join,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

export function runNativeClientCheck(args,toolRoot) {
 return JSON.parse(execFileSync(process.execPath,[fileURLToPath(import.meta.url),toolRoot,JSON.stringify(args)],
  {encoding:'utf8',timeout:120000,maxBuffer:16*1024*1024,windowsHide:true}));
}

// checkClient uses only these script fields. Mount ownership comes from the
// interface trees, so enumerating every UI record once per module is redundant.
export function checkScripts({mapPath},{container,fields,one}) {
 const text=(data,id)=>fields(data).find(f=>f.id===id&&f.wire===2)?.data.toString('utf8')??'';
 return {scripts:fields(one(container(readFileSync(mapPath)),50)).filter(f=>f.id===1&&f.wire===2).map(f=>({
  name:text(f.data,2),file:text(f.data,3),source:text(f.data,5),
  variables:fields(f.data).filter(v=>v.id===7&&v.wire===2).map(v=>({name:text(v.data,2)})),
 }))};
}
export function checkNativeClient(args,{checkClient,listInterface,getClientUi,listComponents,listSignals,signalWords,wire}) {
 const tree=node=>({name:node.name,...(node.scripts?{scripts:node.scripts.map(s=>typeof s==='string'?s:s.name)}:{}),
  ...(node.children?{children:node.children.map(tree)}:{})});
 const digest=()=>createHash('sha256').update(readFileSync(args.mapPath)).digest('hex');
 const before=digest();
 const result=checkClient(args,{
  listClientScripts:a=>checkScripts(a,wire),listComponents,listSignals,signalWords,
  listInterface:a=>{
   const face=listInterface(a);
   return {...face,clientTemplateTrees:(face.clientTemplates??[]).map(t=>tree(getClientUi({...a,template:t.name}).template))};
  },
 });
 assert.equal(digest(),before,'client check input changed during validation');
 return result;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 const toolRoot=process.argv[2],args=JSON.parse(process.argv[3]);
 const native=await import(pathToFileURL(join(toolRoot,'src/scene-save.mjs')));
 const {checkClient}=await import(pathToFileURL(join(toolRoot,'src/client-check.mjs')));
 const wire=await import(pathToFileURL(join(toolRoot,'src/scene/wire.mjs')));
 process.stdout.write(JSON.stringify(checkNativeClient(args,{...native,wire,checkClient})));
}
