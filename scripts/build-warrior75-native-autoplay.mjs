// Test-only native driver over unchanged normal-rule runtime/data. No fixtures.
import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const [base,output]=process.argv.slice(2);
if(!base||!output||existsSync(output))throw Error('Usage: node scripts/build-warrior75-native-autoplay.mjs <normal.gil> <new-directory>');
const directory=resolve(output);mkdirSync(directory,{recursive:true});
const hash=x=>createHash('sha256').update(x).digest('hex');
const files={abyss_w75_driver:readFileSync('scripts/warrior75-native-autoplay.lua','utf8'),abyss_w75_policy:readFileSync('scripts/warrior75-autoplay-policy.lua','utf8')};
let ui=readFileSync('src/lua/abyss_ui.lua','utf8');
for(const marker of ['local view, Viewport','print("ABYSS_UI ready")','view:update(dt)'])if(!ui.includes(marker))throw Error('UI hook changed; review driver injection');
files.abyss_ui=ui.replace('local view, Viewport','local view, Viewport, autoplay')
 .replace('print("ABYSS_UI ready")','print("ABYSS_UI ready")\n        autoplay=require("abyss_w75_driver")')
 .replace('view:update(dt)','view:update(dt)\n        if autoplay then autoplay.update(view,dt) end');
const report={kind:'normal-rule public-command autoplay; explicit initial seed42 only; not physical-touch certification',sourceSha:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),base:resolve(base),baseHash:hash(readFileSync(base)),moduleOverrides:Object.fromEntries(Object.entries(files).map(([k,v])=>[k,hash(v)]))};
const root=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const {Client}=await import(pathToFileURL(join(root,'node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js')));
const {StdioClientTransport}=await import(pathToFileURL(join(root,'node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js')));
const client=new Client({name:'warrior75-normal-rule-autoplay',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[join(root,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:directory,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
let mapPath=resolve(base);
async function call(name,args){
 const result=await client.callTool({name,arguments:args},undefined,{timeout:120000});
 writeFileSync(join(directory,`${name}-${args.name||'result'}.json`),JSON.stringify(result,null,2));
 if(result.isError)throw Error(JSON.stringify(result));
 const d=result.structuredContent??JSON.parse(result.content.find(c=>c.type==='text').text);
 if(d.error)throw Error(JSON.stringify(d));if(d.mapPath)mapPath=d.mapPath;return d;
}
try{
 for(const [name,source]of Object.entries(files)){
  const path=join(directory,`${name}.lua`);writeFileSync(path,source);
  await call('scene_set_client_script',{mapPath,name,sourceFile:path,outputName:'abyss-warrior75-NORMAL-RULE-AUTOPLAY',...(name==='abyss_ui'?{variables:[{name:'nativeBgmEnabled',type:'boolean',value:false}]}:{})});
 }
 const checked=await call('scene_check_client',{mapPath});
 if(!checked.ok||checked.errors)throw Error('Native autoplay static check failed');
 report.candidate=mapPath;report.candidateHash=hash(readFileSync(mapPath));report.staticCheck={errors:checked.errors,warnings:checked.warnings};
 writeFileSync(join(directory,'autoplay-candidate.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{await client.close();}
