import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';

// A deliberately synthetic wire format at the installed-SDK boundary. The
// production embeddedScripts and writeScriptBatch still do every read/write.
const wireSource=String.raw`
export function field(id,wire,value){return Buffer.from(JSON.stringify({id,wire,...(wire===2?{data:Buffer.from(value).toString('base64')}:{value:String(value)})})+'\n');}
export function fields(bytes){return Buffer.from(bytes).toString().trim().split('\n').filter(Boolean).map(line=>{const v=JSON.parse(line);return {...v,...(v.wire===2?{data:Buffer.from(v.data,'base64')}:{value:BigInt(v.value)}),raw:Buffer.from(line+'\n')};});}
export function one(bytes,id){const matches=fields(bytes).filter(f=>f.id===id);if(matches.length!==1)throw Error('Fixture field '+id+' is not unique');return matches[0].wire===2?matches[0].data:matches[0].value;}
export function container(bytes){return Buffer.from(bytes);}
export function replace(bytes,id,wire,value){return Buffer.concat(fields(bytes).map(f=>f.id===id?field(id,wire,value):f.raw));}
export function wrap(_original,root){return Buffer.from(root);}
`;
const storeSource=String.raw`
import {readFileSync,writeFileSync,appendFileSync} from 'node:fs';
import {field,fields,one,replace} from './scene/wire.mjs';
export function scenario(){return process.env.REBUILD_SCENARIO?JSON.parse(readFileSync(process.env.REBUILD_SCENARIO)):{};}
export function record(name,args){const file=process.env.REBUILD_CALLS||process.env.ART_CALLS;if(file)appendFileSync(file,JSON.stringify({name,args,transport:'local-sdk'})+'\n');}
const text=(data,id)=>fields(data).find(f=>f.id===id&&f.wire===2)?.data.toString();
export function readScripts(mapPath){return fields(one(readFileSync(mapPath),50)).map(f=>({name:text(f.data,2),file:text(f.data,3),source:text(f.data,5),on:[]}));}
export function scriptRecord({id=1073741826,name,file,source='',variables=[]},log=true){if(log)record('native_batch_script',{id,name,file,source,variables});return Buffer.concat([field(1,0,id),...(name===undefined?[]:[field(2,2,Buffer.from(name))]),field(3,2,Buffer.from(file)),field(5,2,Buffer.from(source)),...variables.map(v=>field(7,2,field(2,2,Buffer.from(v.name))))]);}
export function writeScripts(mapPath,scripts){const root=readFileSync(mapPath),rows=scripts.map((s,i)=>field(1,2,scriptRecord({...s,id:1073741826+i},false)));writeFileSync(mapPath,replace(root,50,2,Buffer.concat(rows)));}
`;

function encodeField(id,wire,value){return Buffer.from(JSON.stringify({id,wire,...(wire===2?{data:Buffer.from(value).toString('base64')}:{value:String(value)})})+'\n');}
export function fixtureMapBytes(scripts=[]) {
 return encodeField(50,2,Buffer.concat(scripts.map((s,i)=>encodeField(1,2,Buffer.concat([
  encodeField(1,0,1073741826+i),...(s.name===undefined?[]:[encodeField(2,2,Buffer.from(s.name))]),
  encodeField(3,2,Buffer.from(s.file??s.name+'.lua')),encodeField(5,2,Buffer.from(s.source??'')),
 ])))));
}

export function installNativeToolchainFixture(tool,sdk) {
 const put=(file,source)=>{const path=join(tool,file);mkdirSync(dirname(path),{recursive:true});writeFileSync(path,source);};
 put('src/scene/wire.mjs',wireSource);
 put('src/fixture-store.mjs',storeSource);
 put('src/scene-save.mjs',String.raw`
import {record,scenario,scriptRecord} from './fixture-store.mjs';
export function clientScriptRecord(spec){return scriptRecord(spec);}
export function listInterface(){return {clientTemplates:[],clientInterfaces:[]};}
export function getClientUi(){throw Error('fixture has no template');}
export function listComponents(){return {found:[]};}
export function listSignals(){return {parameters:{}};}
export function signalWords(){return null;}
export function addClientUi(args){
 record('scene_add_client_ui',args);const state=scenario();
 if(state.failTool==='scene_add_client_ui')throw Error('FIXTURE_FAILURE scene_add_client_ui');
 if(state.payloadErrorTool==='scene_add_client_ui')return {error:{code:'PAYLOAD_FAILURE'}};
 if(state.hasUi&&!args.replace)return {error:{code:'DUPLICATE_UI'}};
 return {mapPath:args.mapPath};
}
`);
 const parser=pathToFileURL(createRequire(import.meta.url).resolve('luaparse')).href;
 put('src/client-check.mjs',`import parser from ${JSON.stringify(parser)};
import {record,scenario,readScripts,writeScripts} from './fixture-store.mjs';
export function checkClient(args,read){record('scene_check_client',args);const scripts=read.listClientScripts({...args,includeSource:true}).scripts;
 if(scenario().corruptFinalModule)writeScripts(args.mapPath,readScripts(args.mapPath).map(s=>s.name===scenario().corruptFinalModule?{...s,source:s.source+' -- stale'}:s));
 return {mapPath:args.mapPath,ok:true,errors:0,warnings:0,checked:scripts.map(s=>s.name)};}
export function luaSyntaxError(source){try{parser.parse(source,{luaVersion:'5.3'});return null;}catch(error){return error;}}`);
 put('node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js',sdk.replaceAll('__NATIVE_FIXTURE_STORE__',JSON.stringify(pathToFileURL(join(tool,'src/fixture-store.mjs')).href)));
}

export function readFixtureScripts(mapPath) {
 const decode=bytes=>Buffer.from(bytes).toString().trim().split('\n').filter(Boolean).map(JSON.parse);
 const root=decode(readFileSync(mapPath)),section=Buffer.from(root.find(f=>f.id===50).data,'base64');
 return decode(section).map(row=>{
  const fields=decode(Buffer.from(row.data,'base64')),text=id=>{const f=fields.find(f=>f.id===id);return f?Buffer.from(f.data,'base64').toString():undefined;};
  return {name:text(2),file:text(3),source:text(5)};
 });
}
