import{createHash}from'node:crypto';import{spawnSync}from'node:child_process';
import{readFileSync,writeFileSync,existsSync}from'node:fs';import{resolve}from'node:path';import{pathToFileURL}from'node:url';
import{ROOT,tree,theme,geometry}from'./layout.mjs';
const digest=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const manifestArg=process.argv.slice(2).find(a=>a.startsWith('--source-manifest='));
if(process.argv.slice(2).some(a=>!a.startsWith('--source-manifest=')))throw Error('Usage: node build-scene.mjs [--source-manifest=path]');
const manifestPath=manifestArg?resolve(manifestArg.slice('--source-manifest='.length)):resolve(ROOT,'source-manifest.json');
let sourceManifest,manifestHash=null;
if(existsSync(manifestPath)){
 sourceManifest=JSON.parse(readFileSync(manifestPath));manifestHash=digest(manifestPath);
 for(const item of [...sourceManifest.inputs,...(sourceManifest.generated||[])])if(digest(resolve(ROOT,item.path))!==item.sha256)throw Error('Source manifest mismatch '+item.path);
}else{
 if(manifestArg)throw Error('Explicit source manifest missing');
 const git=(...args)=>{const r=spawnSync('git',['-C',ROOT,...args],{encoding:'utf8'});if(r.status!==0)throw Error('ABYSS_ROOT must be a Git checkout or supply a verified source manifest');return r.stdout.trim()};
 sourceManifest={commit:git('rev-parse','HEAD'),tree:git('rev-parse','HEAD^{tree}'),sourceDirty:git('status','--porcelain','--untracked-files=normal')!==''};
}
const moduleInputs=[];
const{toLua}=await import(pathToFileURL(resolve(ROOT,'scripts/build-lua-data.mjs')));
const save=JSON.parse(readFileSync(resolve(ROOT,'experiments/art-tech-lab/seed.save.json')));const root=save.assets.server.root.children[0];const samples=Object.fromEntries(root.children.map(n=>[n.kind,structuredClone(n)]));const container=structuredClone(root);let seq=3000;
const argb=(hex='#ffffff',opacity=1)=>{const rgb=hex.slice(1,7);const a=Math.round((hex.length===9?parseInt(hex.slice(7),16):255)*opacity);return a*16777216+parseInt(rgb,16)};
function convert(spec){const kind={container:'container',image:'image',text:'textbox',cursorArea:'cursor'}[spec.kind];if(!kind)throw Error('unsupported '+spec.kind);
 const n=structuredClone(kind==='container'?container:samples[kind]);n.id='slice'+(++seq);n.guid=1073800000+seq;n.name=spec.name;n.scriptMappingIds=[];n.children=(spec.children||[]).map(convert);n.isRootContainer=false;
 const[x,y]=spec.position||[0,0],[w,h]=spec.size||[1280,720];for(const t of Object.values(n.transformByPlatform)){t.offset={x,y};t.rotation={x:0,y:0,z:spec.rotation||0};t.size={x:w,y:h};t.scale={x:spec.scale?.[0]??1,y:spec.scale?.[1]??1,z:1};t.anchorMin={x:.5,y:.5};t.anchorMax={x:.5,y:.5}}
 if(kind==='image'){n.imageId=spec.image;n.imageColor=argb(spec.colour,spec.opacity??1)}
 if(kind==='textbox')Object.assign(n,{text:spec.text.content||'',fontSize:spec.text.fontSize,minimumFontSize:spec.text.minFontSize||spec.text.fontSize,fontColor:argb(spec.text.colour),bgColor:0,enableOutline:false,horizontalAlignment:'Middle',verticalAlignment:'Middle'});
 if(spec.visible===false)n.visible=false;
 if(n.children.length>60)throw Error('child budget '+n.name+' '+n.children.length);return n;
}
const caption=(name,y,content)=>({name,kind:'text',position:[0,y],size:[900,60],text:{content,fontSize:22,colour:'#e9c77b'}});
const button=(name,y,label)=>({name,kind:'container',position:[0,y],size:[300,54],children:[{name:'face',kind:'image',size:[300,54],image:100001,colour:'#23180f'},caption('label',0,label),{name:'hit',kind:'cursorArea',size:[300,54]}]});
const previewReturn=button('previewReturn',-412,'返回当前房间');previewReturn.visible=false;tree.controls.find(c=>c.name==='stage').children.push(previewReturn);
const mapRoot={name:'mapRoot',kind:'container',size:[1280,720],children:tree.controls};
const roomPanel={name:'roomPanel',kind:'container',size:[1280,720],visible:false,children:[{name:'roomBackdrop',kind:'image',size:[1280,720],image:100001,colour:'#0b0606'},caption('roomTitle',100,'已进入真实房间'),caption('roomScope',30,'地图移植切片：此处不模拟或自动完成战斗'),button('roomRoute',-70,'查看路线')]};
const loadingPanel={name:'loadingPanel',kind:'container',size:[1280,720],children:[{name:'loadingBackdrop',kind:'image',size:[1280,720],image:100001,colour:'#0b0606'},caption('loadingTitle',0,'正在建立真实测试局…')]};
const sceneTree={controls:[mapRoot,roomPanel,loadingPanel]};
root.children=sceneTree.controls.map(convert);root.name='FigmaMapNativeSlice';root.scriptMappingIds=[1073990001];
const mods=new Map();const norm=v=>typeof v==='string'&&/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v)?{r:parseInt(v.slice(1,3),16),g:parseInt(v.slice(3,5),16),b:parseInt(v.slice(5,7),16),a:v.length===9?parseInt(v.slice(7),16):255}:Array.isArray(v)?v.map(norm):v&&typeof v==='object'?Object.fromEntries(Object.entries(v).map(([k,x])=>[k,norm(x)])):v;
mods.set('abyss_theme','return '+toLua(norm(theme)));mods.set('abyss_map_layout','return '+toLua(geometry));mods.set('curve',readFileSync('curve.lua','utf8'));mods.set('presentation',readFileSync('presentation.lua','utf8'));mods.set('scenario',readFileSync('scenario.lua','utf8'));
function include(name){if(mods.has(name))return;const path=[resolve(ROOT,'src/lua',name+'.lua'),resolve(ROOT,'build/lua',name+'.lua')].find(existsSync);if(!path)throw Error('missing module '+name);const source=readFileSync(path,'utf8');moduleInputs.push({name,path:path.slice(resolve(ROOT).length+1),sha256:digest(path)});mods.set(name,source);for(const m of source.matchAll(/require\s*\(?\s*["']([^"']+)["']/g))include(m[1]);}
for(const name of['abyss_map','abyss_run','abyss_nodes','abyss_map_ui','abyss_data'])include(name);
const loader='local factories,loaded={},{}\nlocal function require(name) if loaded[name]~=nil then return loaded[name]end;assert(factories[name],"missing slice module "..name);local value=factories[name]();loaded[name]=value;return value end\n';
const source=loader+[...mods].map(([name,code])=>`factories[${JSON.stringify(name)}]=function()\n${code}\nend\n`).join('')+'local FIGMA_SCENARIO='+JSON.stringify(process.env.FIGMA_SCENARIO||'start')+'\n'+readFileSync('scene.lua','utf8');
writeFileSync('scene.generated.lua',source);writeFileSync('controls.json',JSON.stringify(tree));writeFileSync('controls.lua','return '+toLua(sceneTree));writeFileSync('theme.lua',mods.get('abyss_theme'));writeFileSync('geometry.lua',mods.get('abyss_map_layout'));
save.assets.scripts=[{id:'nativeSlice',guid:1073990001,path:'scene.generated.lua',source,controlId:root.id,controlAsset:'server-control-template'}];save.meta.name='Figma native map slice — real Lua rules';function reverse(n){n.children.forEach(reverse);n.children.reverse()}reverse(root);writeFileSync('scene.save.json',JSON.stringify(save));
let count=0;function visit(n){count++;n.children.forEach(visit)}visit(root);writeFileSync('scene-inventory.json',JSON.stringify({sourceCommit:sourceManifest.commit,sourceTree:sourceManifest.tree,sourceManifestSha256:manifestHash,sourceDirty:sourceManifest.sourceDirty??false,moduleInputs,experimentInputs:Object.fromEntries(['build-scene.mjs','layout.mjs','curve.lua','presentation.lua','scene.lua','scenario.lua'].map(p=>[p,digest(p)])),scenario:process.env.FIGMA_SCENARIO||'start',saveSha256:digest('scene.save.json'),controls:count,modules:mods.size,sourceBytes:Buffer.byteLength(source),shapePool:1536,glowPool:256,additionalAnimatedApiWrites:256,officialVerified:false},null,2));console.log({controls:count,modules:mods.size});
