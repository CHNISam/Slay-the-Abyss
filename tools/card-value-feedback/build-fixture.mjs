// Creates a separate renderer QA copy. Never use this as the normal game or RC.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const [input,output]=process.argv.slice(2);
if(!input||!output)throw Error('Usage: node tools/card-value-feedback/build-fixture.mjs <normal.gil> <new-directory>');
const workspace=resolve(output);mkdirSync(workspace,{recursive:true});
const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const sdk=join(toolRoot,'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(join(sdk,'index.js')));
const {StdioClientTransport}=await import(pathToFileURL(join(sdk,'stdio.js')));
const client=new Client({name:'card-value-fixture',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[join(toolRoot,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
let mapPath=resolve(input);
const original=readFileSync('src/lua/abyss_ui.lua','utf8');
let entry=original.replace('local view, Viewport','local view, Viewport\nlocal valueFixture');
entry=entry.replace('print("ABYSS_UI ready")','valueFixture = require("abyss_value_fixture").start(view)\n        print("ABYSS_UI ready")');
entry=entry.replace('view:update(dt)','view:update(dt)\n        valueFixture(dt)');
if(entry===original||!entry.includes('valueFixture(dt)'))throw Error('Fixture entry splice failed');
writeFileSync(join(workspace,'abyss_ui.lua'),entry);
try{
 for(const uri of ['miliastra://workflow','miliastra://platform-rules'])await client.readResource({uri});
 for(const [name,sourceFile]of [['abyss_value_fixture',resolve('tools/card-value-feedback/fixture.lua')],['abyss_ui',join(workspace,'abyss_ui.lua')]]){
   const result=await client.callTool({name:'scene_set_client_script',arguments:{mapPath,name,sourceFile,outputName:'abyss-card-value-fixture'}});
   if(result.isError)throw Error(JSON.stringify(result));
   const value=result.structuredContent??JSON.parse(result.content.find(c=>c.type==='text').text);
   mapPath=value.mapPath;
 }
 const checked=await client.callTool({name:'scene_check_client',arguments:{mapPath}});
 writeFileSync(join(workspace,'static-check.json'),JSON.stringify(checked,null,2));
 const data=checked.structuredContent??JSON.parse(checked.content.find(c=>c.type==='text').text);
 if(checked.isError||!data.ok||data.errors)throw Error('Fixture static check failed');
 const sha256=createHash('sha256').update(readFileSync(mapPath)).digest('hex');
 writeFileSync(join(workspace,'fixture.json'),JSON.stringify({mapPath,sha256,normalCandidate:resolve(input),diagnosticOnly:true,controlledStates:true,entryModified:true,mobileLive:'NOT_RUN'},null,2));
 console.log(JSON.stringify({mapPath,sha256}));
}finally{await client.close();}
