import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
export async function connect(workspace=resolve('.artifacts/native-3d-tool')) {
  mkdirSync(workspace,{recursive:true});
  const sdk=join(toolRoot,'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
  const {Client}=await import(pathToFileURL(join(sdk,'index.js')));
  const {StdioClientTransport}=await import(pathToFileURL(join(sdk,'stdio.js')));
  const client=new Client({name:'abyss-native-3d-lab',version:'1.0'});
  await client.connect(new StdioClientTransport({command:process.execPath,args:[join(toolRoot,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
  return client;
}
export function data(result){if(result.isError)throw Error(JSON.stringify(result));return result.structuredContent??JSON.parse(result.content.find(c=>c.type==='text').text)}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
  const client=await connect();
  try{
    const action=process.argv[2];
    if(action==='resources')for(const uri of ['miliastra://workflow','miliastra://platform-rules']){
      const r=await client.readResource({uri});writeFileSync(resolve('.artifacts/native-3d-tool',uri.split('//')[1]+'.json'),JSON.stringify(r,null,2));console.log(uri+' read '+r.contents.reduce((n,c)=>n+c.text.length,0)+' chars');
    }
    else if(action==='list'){const r=await client.listTools();writeFileSync(resolve('.artifacts/native-3d-tool/tools.json'),JSON.stringify(r,null,2));console.log(r.tools.map(t=>t.name).join('\n'));}
    else console.log(JSON.stringify(data(await client.callTool({name:action,arguments:JSON.parse(process.argv[3]||'{}')},undefined,{timeout:120000})),null,2));
  }finally{await client.close()}
}
