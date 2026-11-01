import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {checkScripts,checkNativeClient} from '../scripts/native-client-check.mjs';
const encode=x=>Buffer.from(JSON.stringify(x));
const row=(id,value)=>({id,wire:2,data:value});
const wire={container:b=>b,fields:b=>JSON.parse(b).map(f=>({...f,data:typeof f.data==='string'?Buffer.from(f.data):encode(f.data)})),
 one:(b,id)=>encode(JSON.parse(b).find(f=>f.id===id).data)};
function fixture(t){const dir=mkdtempSync(join(tmpdir(),'abyss-client-check-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));const mapPath=join(dir,'map.gil');
 const scripts=[row(1,[row(2,'main'),row(3,'main.lua'),row(5,'return 1'),row(7,[row(2,'health')])])];
 writeFileSync(mapPath,encode([row(50,scripts)]));return {mapPath};}
test('checker script projection preserves source and declared parameter names with fresh reads',t=>{
 const args=fixture(t);assert.deepEqual(checkScripts(args,wire),{scripts:[{name:'main',file:'main.lua',source:'return 1',variables:[{name:'health'}]}]});
 writeFileSync(args.mapPath,encode([row(50,[])]));assert.deepEqual(checkScripts(args,wire),{scripts:[]});
});
test('original checker receives complete template names, mounts, dependencies and script filter; diagnostics propagate',t=>{
 const args={...fixture(t),scripts:['main']},diagnostic={ok:false,errors:1,problems:[{kind:'SCRIPT_VARIABLE_NOT_FOUND'}]};
 const listComponents=()=>({found:[]}),listSignals=()=>({parameters:{}}),signalWords=()=>null;
 const result=checkNativeClient(args,{wire,listComponents,listSignals,signalWords,
  listInterface:()=>({clientInterfaces:[{root:{name:'root'}}],clientTemplates:[{name:'card',templateIndex:42}]}),
  getClientUi:a=>{assert.equal(a.template,'card');return {template:{name:'card',scripts:[{name:'main',values:{health:1}}],children:[{name:'amount'}]}};},
  checkClient:(actual,read)=>{assert.equal(actual,args);assert.equal(read.listComponents,listComponents);assert.equal(read.listSignals,listSignals);assert.equal(read.signalWords,signalWords);
   assert.deepEqual(read.listClientScripts(actual).scripts[0].variables,[{name:'health'}]);
   assert.deepEqual(read.listInterface(actual).clientTemplateTrees,[{name:'card',scripts:['main'],children:[{name:'amount'}]}]);return diagnostic;},
 });assert.equal(result,diagnostic);
});
test('map mutation and original checker exceptions are rejected',t=>{
 const args=fixture(t),dependencies={wire,listInterface:()=>({}),getClientUi:()=>({}),checkClient:()=>{throw Error('native failed');}};
 assert.throws(()=>checkNativeClient(args,dependencies),/native failed/);
 dependencies.checkClient=()=>{writeFileSync(args.mapPath,'changed');return {ok:true};};
 assert.throws(()=>checkNativeClient(args,dependencies),/client check input changed/);
});
