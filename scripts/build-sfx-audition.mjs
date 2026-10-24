// Isolated native listening room. Production data and scripts are never edited.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {theme} from './ui-layout.mjs';
import {nativeBgmGraphSource,nativeBgmSignals} from './native-bgm-graph.mjs';
import {sfxAuditionCandidates,sfxAuditionController} from './sfx-audition-source.mjs';
const [base,output]=process.argv.slice(2); if(!base||!output)throw Error('Usage: node scripts/build-sfx-audition.mjs <base.gil> <new output directory>');
const workspace=resolve(output);mkdirSync(workspace);
const root=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const sourceSha=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const sourceDirty=Boolean(execFileSync('git',['status','--porcelain','--untracked-files=normal'],{encoding:'utf8'}).trim());
const {Client}=await import(pathToFileURL(join(root,'node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js')));
const {StdioClientTransport}=await import(pathToFileURL(join(root,'node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js')));
const client=new Client({name:'abyss-sfx-audition',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[join(root,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0',MILIASTRA_PYTHON:'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe'}}));
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const basePath=resolve(base),before=hash(basePath);let mapPath=basePath,seq=0;
async function call(name,args){const r=await client.callTool({name,arguments:args},undefined,{timeout:120000});writeFileSync(join(workspace,`${++seq}-${name}.json`),JSON.stringify(r,null,2));if(r.isError)throw Error(JSON.stringify(r));const d=r.structuredContent??JSON.parse(r.content.find(x=>x.type==='text').text);if(d.mapPath)mapPath=d.mapPath;return d;}
try{
 for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeFileSync(join(workspace,uri.split('//')[1]+'.json'),JSON.stringify(await client.readResource({uri}),null,2));
 const catalog=JSON.parse(readFileSync(join(root,'src/scene/media/sounds.json'),'utf8'));
 const candidates=sfxAuditionCandidates(catalog);
 writeFileSync(join(workspace,'candidates.json'),JSON.stringify({catalogSource:catalog.source,catalogSha256:hash(join(root,'src/scene/media/sounds.json')),candidates},null,2));
 // List actual entities before attaching a graph. No guessed native IDs.
 await call('scene_list_entities',{mapPath,limit:500});
 await call('scene_set_player_count',{mapPath,min:1,max:1,outputName:'abyss-sfx-audition'});
 await call('scene_add_signal',{mapPath,name:'SFX_LISTEN',parameters:[{name:'soundId',type:'integer'},{name:'volume',type:'integer'}],outputName:'abyss-sfx-audition'});
 for(const name of Object.values(nativeBgmSignals))await call('scene_add_signal',{mapPath,name,outputName:'abyss-sfx-audition'});
 const graph=await call('scene_add_graph',{mapPath,name:'SFX_LISTEN',kind:'server',outputName:'abyss-sfx-audition'});
 const code=`/// <reference types="genshin-ts" />\nimport {g,defineSignal} from 'genshin-ts/runtime/core'\nconst LISTEN=defineSignal('SFX_LISTEN',[['soundId','int'],['volume','int']] as const)\ng.server({id:${graph.graphId},name:${JSON.stringify(graph.name)}}).onSignal(LISTEN,(evt,f)=>{for(const player of f.getListOfPlayerEntitiesOnTheField()){f.playerPlaysOneShot2dSoundEffect(player,evt.params.soundId,evt.params.volume,1);}f.printString('SFX_APPLIED');})\n`;
 const bgm=await call('scene_add_graph',{mapPath,name:'SFX_BGM',kind:'server',outputName:'abyss-sfx-audition'});
 const compiled=await call('write_graphs',{mapPath,graphs:[{graphId:graph.graphId,code},{graphId:bgm.graphId,code:nativeBgmGraphSource({id:bgm.graphId,name:bgm.name})}]});
 if(compiled.failed||compiled.error||compiled.errors?.length||compiled.written?.length!==2)throw Error('Graphs did not compile completely');
 const lua=sfxAuditionController(candidates);
 writeFileSync(join(workspace,'controller.lua'),lua);
 // Use the game controller slot only in this copy; production Lua is untouched.
 await call('scene_set_client_script',{mapPath,name:'abyss_ui',source:lua,outputName:'abyss-sfx-audition'});
 const {color:c,font:f,image:im}=theme;
 const text=(name,x,y,w,h,content,size=f.body)=>({name,kind:'text',position:[x,y],size:[w,h],text:{content,fontSize:size,colour:c.text,align:'centre',valign:'middle',autoSize:true,minFontSize:f.minimum}});
 const button=(name,x,y,w,label)=>({name,kind:'container',position:[x,y],size:[w,42],children:[{name:'bg',kind:'image',size:[w,42],image:im.rect,colour:c.panelRaised},text('label',0,0,w-8,40,label,f.label),{name:'hit',kind:'cursorArea',size:[w,42]}]});
 const children=[text('title',0,302,1160,44,'杀戮原塔2 · 音效试听副本',f.title),text('status',0,253,1160,42,'加载中；没有 ready 请勿开始'),text('detail',230,145,680,70,'选择候选，然后播放；旧版按同组对照'),text('gain',230,85,680,35,'音量 65 / 100 · 尚未匹配'),text('review',230,-275,680,30,'待定 · 评语标签写入本轮日志'),text('hint',0,-320,1160,30,'原生音频；死亡演出仅触发一次。退出试玩后保留本轮日志。',f.small),{name:'target',kind:'image',position:[230,215],size:[54,54],image:theme.icon.enemy?.jaw_worm??theme.icon.player,colour:c.geo}];
 candidates.forEach((r,i)=>children.push(button(`pick${i+1}`,-420,i<8?205-i*49:205-(i-8)*49,180,`${r.code} · ${r.id}`)));
 // Death choices are a second column.
 for(const child of children)if(/^pick(9|10|11|12)$/.test(child.name))child.position[0]=-220;
 const actions=[['play','播放候选'],['old','播放旧版'],['ab','旧 → 新 A/B'],['burst','连续攻击 ×6'],['death','死亡演出一次'],['mix','攻击 → 死亡'],['bgm','BGM 开 / 关'],['minus','音量 −5'],['plus','音量 +5'],['like','喜欢'],['maybe','待定'],['reject','淘汰'],['tag1','评语：刺耳'],['tag2','评语：尾音过长'],['tag3','评语：满足'],['tour','全候选轮播'],['cancel','取消队列']];
 actions.forEach(([name,label],i)=>children.push(button(name,75+(i%3)*210,15-Math.floor(i/3)*49,195,label)));
 await call('scene_add_client_ui',{mapPath,name:'SlayTheAbyss',script:'abyss_ui',replace:true,showCursor:true,blockKeys:true,blockCursor:true,controls:[{name:'backdrop',kind:'image',size:[1600,900],image:im.rect,colour:c.backdrop},{name:'stage',kind:'container',size:[1280,720],children}],outputName:'abyss-sfx-audition'});
 const checked=await call('scene_check_client',{mapPath});if(!checked.ok||checked.errors)throw Error('Client check failed');
 if(hash(basePath)!==before)throw Error('Input changed');
 const deliverable=join(workspace,'abyss-sfx-audition.gil');copyFileSync(mapPath,deliverable);
 writeFileSync(join(workspace,'candidate.json'),JSON.stringify({mapPath:deliverable,sha256:hash(deliverable),basePath,baseBefore:before,baseAfter:hash(basePath),source:sourceSha,sourceDirty,controllerSha256:hash(join(workspace,'controller.lua')),compiled,checked,officialImport:'NOT_TESTED',listening:'NOT_TESTED',liveWriteEnabled:false},null,2));
 console.log(deliverable);
}finally{await client.close();}
