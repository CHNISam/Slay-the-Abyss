import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {gunzipSync} from 'node:zlib';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {buildUiTheme} from '../../scripts/build-ui-theme.mjs';
export const root=path.dirname(fileURLToPath(import.meta.url));
export const repo=path.resolve(root,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
export function themeSource(){const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'native-ui-theme-'));try{return buildUiTheme(path.join(repo,'data/presentation/ui_theme.json'),path.join(repo,'data'),path.join(tmp,'theme.lua'));}finally{fs.rmSync(tmp,{recursive:true,force:true});}}
export function moduleSources(){
 const sources=new Map(),sourceDir=path.join(repo,'src/lua'),generatedDir=path.join(repo,'build/lua');
 for(const f of fs.readdirSync(sourceDir))if(f.endsWith('.lua'))sources.set(f.slice(0,-4),fs.readFileSync(path.join(sourceDir,f),'utf8'));
 const generated=fs.existsSync(generatedDir)?fs.readdirSync(generatedDir):[];
 for(const f of generated)if(f.endsWith('.lua')&&sources.has(f.slice(0,-4)))throw Error('Generated module conflicts with source: '+f.slice(0,-4));
 // This fixture needs only the two generated data modules. Theme is rebuilt below.
 for(const name of ['abyss_data','abyss_original_v4_data'])if(generated.includes(name+'.lua'))sources.set(name,fs.readFileSync(path.join(generatedDir,name+'.lua'),'utf8'));
 sources.set('abyss_theme',themeSource());
 for(const n of ['semantic','approved_arrow'])sources.set(n,read('battle/'+n+'.lua'));
 return sources;
}
export function compileBattle(){const sources=moduleSources(),needed=new Set(),scene=read('battle/scene.lua');function add(n){if(needed.has(n))return;const text=sources.get(n);if(!text)throw Error('Missing Lua module '+n+'; run npm run build:data first.');needed.add(n);for(const m of text.matchAll(/require\s*\(?\s*["']([^"']+)["']/g))add(m[1]);}for(const m of scene.matchAll(/require\s*\(?\s*["']([^"']+)["']/g))add(m[1]);return {modules:[...needed],source:'local loaders,cache={},{}\nlocal function require(name)\n if cache[name] then return cache[name] end\n local value=assert(loaders[name],"missing module "..name)();cache[name]=value;return value\nend\n'+[...needed].map(n=>'loaders['+JSON.stringify(n)+']=function()\n'+sources.get(n)+'\nend\n').join('')+scene};}
export function readLayout(scene){const entry=JSON.parse(read('layouts/'+scene+'.json'));const bytes=gunzipSync(Buffer.from(entry.controlTree,'base64'));if(entry.encoding!=='gzip+base64'||sha(bytes)!==entry.expandedSha256)throw Error('Invalid layout integrity');return JSON.parse(bytes);}
export function createSave(scene,{demo=false}={}){if(!['menu','shop','battle','map'].includes(scene))throw Error('Unknown scene');const save=JSON.parse(fs.readFileSync(path.join(repo,'experiments/art-tech-lab/seed.save.json'),'utf8'));const node=readLayout(scene);const guid=1074990001;node.scriptMappingIds=[guid];save.assets.server.root.children=[node];let source;if(scene==='battle')source='local AUTO_SEMANTIC_DEMO='+demo+'\n'+compileBattle().source;else if(scene==='menu')source='local AUTOMATIC_DEMO='+demo+'\nlocal INITIAL_PAGE="menu"\n'+read('menu/controller.lua')+'\n'+read('menu/scene.lua');else if(scene==='shop')source=read('shop/controller.lua')+'\n'+read('shop/scene.lua');else source=read('map/scene.lua');save.assets.scripts=[{id:'nativePreview',guid,path:scene+'.lua',source,controlId:node.id,controlAsset:'server-control-template'}];save.meta.name='Approved UI native '+scene+' candidate; input unverified; not a complete game';return save;}
export function verifyAssets(scene,cache){const manifest=JSON.parse(read('asset-inputs.json'));for(const a of manifest.scenes[scene]??[]){for(const [name,digest]of [[a.png,a.sha256],[a.border,a.borderSha256]]){const file=path.resolve(cache,name);if(!file.startsWith(path.resolve(cache)+path.sep)||!fs.existsSync(file)||sha(fs.readFileSync(file))!==digest)throw Error('Required private asset absent or different: '+name+'; see asset-inputs.json. No official-ID fallback is permitted for these local aliases.');}}return manifest.scenes[scene].length;}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){try{const args=process.argv.slice(2),scene=args[0]||'menu',value=k=>{const i=args.indexOf(k);return i<0?null:args[i+1];};const save=createSave(scene,{demo:args.includes('--demo')});if(args.includes('--check-only')){console.log('Source/template compiled; no assets loaded, native input unverified.');}else{const cache=value('--cache');if(!cache)throw Error('--cache <private scene image-cache> is required. This repository intentionally contains no private textures.');const count=verifyAssets(scene,cache),dest=path.resolve(value('--out')||path.join(root,'output',scene+'.save.json'));fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,JSON.stringify(save));console.log(JSON.stringify({file:dest,sha256:sha(fs.readFileSync(dest)),verifiedAssetCount:count,nativeInputVerified:false}));}}catch(e){console.error(e.message);process.exitCode=1;}}
