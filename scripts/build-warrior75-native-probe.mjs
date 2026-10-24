// A separate diagnostic copy; never included by candidateScriptFiles().
import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const [base,output]=process.argv.slice(2);
if(!base||!output||existsSync(output))throw Error('Usage: node scripts/build-warrior75-native-probe.mjs <normal.gil> <new-directory>');
const directory=resolve(output);mkdirSync(directory,{recursive:true});
const suites=['warrior75','warrior75_edges','warrior75_shuffle','warrior75_acquisition','warrior75_card_text','warrior75_courier'];
const hash=text=>createHash('sha256').update(text).digest('hex');
const report={kind:'explicit native test fixtures; not normal acquisition or full UI acceptance',sourceSha:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),base:resolve(base),baseHash:hash(readFileSync(base)),suites:[]};
let checks='local M={}\nfunction M.core()\n';
for(const name of suites){
 const file=`tests/lua/${name}.lua`,source=readFileSync(file,'utf8');
 if(/\bdofile\s*\(/.test(source))throw Error(`Filesystem fixture cannot run in client: ${file}`);
 report.suites.push({file,sha256:hash(source)});
 checks+=`do\n${source.replace(/^package\.path[^\r\n]*(?:\r?\n)?/mg,'')}\nprint('ABYSS_W75_NATIVE_CORE pass ${name}')\nend\n`;
}
checks+="print('ABYSS_W75_NATIVE_CORE all six fixture suites passed; UI and natural acquisition separate')\nend\n";
// Bundle only our explicit, allowlisted test helpers. The client has no dofile
// filesystem API. Preserve original fixture hashes and all 75 transactions.
let channels=readFileSync('tests/lua/warrior75_channels.lua','utf8');
for(const path of ['tests/fixtures/warrior75-shop-seeds.lua','tests/lua/support/map_routes.lua']){
 const source=readFileSync(path,'utf8');
 report.suites.push({file:path,sha256:hash(source),kind:'inlined own test helper'});
 channels=channels.replace(`dofile('${path}')`,`(function()\n${source}\nend)()`);
}
if(/\bdofile\s*\(/.test(channels))throw Error('Unresolved native channel fixture dependency');
report.suites.push({file:'tests/lua/warrior75_channels.lua',sha256:hash(readFileSync('tests/lua/warrior75_channels.lua')),groups:['common','uncommon','rare']});
checks+=`function M.channel(id,rarity)\nlocal WARRIOR75_CHANNEL_CARD,WARRIOR75_CHANNEL_RARITY=id,rarity\n${channels.replace(/^package\.path[^\r\n]*(?:\r?\n)?/mg,'')}\nend\nreturn M\n`;
const files={abyss_warrior75_checks:checks,abyss_warrior75_probe:readFileSync('scripts/warrior75-native-probe.lua','utf8')};
let ui=readFileSync('src/lua/abyss_ui.lua','utf8');
if(!ui.includes('local view, Viewport')||!ui.includes('print("ABYSS_UI ready")')||!ui.includes('view:update(dt)'))throw Error('UI hook changed; review probe injection');
files.abyss_ui=ui.replace('local view, Viewport','local view, Viewport, warriorProbe').replace('print("ABYSS_UI ready")','print("ABYSS_UI ready")\n        warriorProbe=require("abyss_warrior75_probe");warriorProbe.start(view)').replace('view:update(dt)','view:update(dt)\n        if warriorProbe then warriorProbe.tick(view) end');
const root=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const {Client}=await import(pathToFileURL(join(root,'node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js')));
const {StdioClientTransport}=await import(pathToFileURL(join(root,'node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js')));
const client=new Client({name:'warrior75-explicit-native-fixtures',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[join(root,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:directory,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
let mapPath=resolve(base);
async function call(name,args){const result=await client.callTool({name,arguments:args},undefined,{timeout:120000});writeFileSync(join(directory,`${name}-${args.name||'result'}.json`),JSON.stringify(result,null,2));if(result.isError)throw Error(JSON.stringify(result));const d=result.structuredContent??JSON.parse(result.content.find(c=>c.type==='text').text);if(d.error)throw Error(JSON.stringify(d));if(d.mapPath)mapPath=d.mapPath;return d;}
try{
 for(const [name,source]of Object.entries(files)){const path=join(directory,`${name}.lua`);writeFileSync(path,source);await call('scene_set_client_script',{mapPath,name,sourceFile:path,outputName:'abyss-warrior75-EXPLICIT-FIXTURES',...(name==='abyss_ui'?{variables:[{name:'nativeBgmEnabled',type:'boolean',value:false}]}:{})});}
 const checked=await call('scene_check_client',{mapPath});if(!checked.ok||checked.errors)throw Error('Native fixture candidate static check failed');
 report.candidate=mapPath;report.candidateHash=hash(readFileSync(mapPath));report.moduleOverrides=Object.fromEntries(Object.entries(files).map(([k,v])=>[k,hash(v)]));report.staticCheck={errors:checked.errors,warnings:checked.warnings};
 writeFileSync(join(directory,'probe-candidate.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{await client.close();}
