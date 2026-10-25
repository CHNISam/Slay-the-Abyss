import {existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
export async function connectMcp(name,out){
 const configured=process.env.MILIASTRA_MCP_ROOT;
 if(!configured)throw Error('Set MILIASTRA_MCP_ROOT to the installed genshin-miliastra-mcp directory; see docs/TOOLCHAIN.md');
 const toolRoot=resolve(configured),server=join(toolRoot,'src/server.mjs');
 const sdk=part=>join(toolRoot,'node_modules/@modelcontextprotocol/sdk/dist/esm/client',part);
 for(const file of [server,sdk('index.js'),sdk('stdio.js')])if(!existsSync(file))throw Error('Missing Miliastra MCP file: '+file);
 const {Client}=await import(pathToFileURL(sdk('index.js'))),{StdioClientTransport}=await import(pathToFileURL(sdk('stdio.js')));
 const client=new Client({name,version:'1'});
 await client.connect(new StdioClientTransport({command:process.execPath,args:[server],env:{...process.env,MILIASTRA_ALLOW_LIVE_WRITE:'0',MILIASTRA_WORKSPACE:join(out,'mcp')}}));
 return client;
}
