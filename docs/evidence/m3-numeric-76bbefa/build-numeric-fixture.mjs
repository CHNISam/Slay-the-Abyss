import {Client} from 'file:///D:/MiliastraTools/genshin-miliastra-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from 'file:///D:/MiliastraTools/genshin-miliastra-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import {mkdirSync,readFileSync,writeFileSync,copyFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const dir='F:/New folder/.artifacts/m3-integrated-76bbefa';
const normal=`${dir}/abyss-m3-normal-76bbefa.gil`, workspace=`${dir}/numeric-build`;
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const normalHash=hash(normal);let mapPath=normal;
mkdirSync(workspace,{recursive:true});
const client=new Client({name:'m3-numeric-visual-fixture',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:['D:/MiliastraTools/genshin-miliastra-mcp/src/server.mjs'],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
try{
 for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeFileSync(`${workspace}/${uri.split('//')[1]}.json`,JSON.stringify(await client.readResource({uri}),null,2));
 async function call(name,args,label){const r=await client.callTool({name,arguments:args},undefined,{timeout:120000});writeFileSync(`${workspace}/${label}.json`,JSON.stringify(r,null,2));const d=r.structuredContent??JSON.parse(r.content.find(x=>x.type==='text').text);if(r.isError||d.error)throw Error(JSON.stringify(d));if(d.mapPath)mapPath=d.mapPath;return d;}
 const before=await call('scene_list_client_scripts',{mapPath,includeSource:true},'before');
 for(const [name,file]of [['abyss_m3_numeric_probe','abyss_m3_numeric_probe.lua'],['abyss_ui','abyss_ui_numeric_probe.lua']])await call('scene_set_client_script',{mapPath,name,sourceFile:`${dir}/${file}`,outputName:'abyss-m3-numeric-fixture',...(name==='abyss_ui'?{variables:[{name:'nativeBgmEnabled',type:'boolean',value:false}]}:{})},name);
 const checked=await call('scene_check_client',{mapPath},'static');if(!checked.ok||checked.errors)throw Error('Static failure');
 const after=await call('scene_list_client_scripts',{mapPath,includeSource:true},'after');
 for(const script of before.scripts)if(script.name!=='abyss_ui'&&after.scripts.find(s=>s.name===script.name)?.source!==script.source)throw Error('Changed production module '+script.name);
 if(after.scripts.length!==before.scripts.length+1||hash(normal)!==normalHash)throw Error('Unexpected module or normal-candidate change');
 const output=`${dir}/abyss-m3-numeric-fixture-76bbefa.gil`;copyFileSync(mapPath,output);
 const report={sourceCommit:'76bbefade36b66c21c3c50964c8f28d8da9169a5',fixtureOnly:true,inputCertification:false,normal:{path:normal,sha256:normalHash},candidate:{path:output,sha256:hash(output)},unchangedProductionModules:before.scripts.length-1,checked,officialImport:'NOT_TESTED',liveWriteEnabled:false};
 writeFileSync(`${dir}/numeric-candidate.json`,JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{await client.close();}
