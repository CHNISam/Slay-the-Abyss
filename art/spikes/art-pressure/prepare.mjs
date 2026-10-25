// Single-save pressure gallery; reuses existing audited art exporters unchanged.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync,existsSync,readdirSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {connectMcp} from './mcp.mjs';
if(!process.argv[2]||!process.argv[3])throw Error('Usage: node prepare.mjs <clean-base.gil> <new-output-directory>');
const here=dirname(fileURLToPath(import.meta.url)),repo=resolve(here,'../../..');
const base=resolve(process.argv[2]),out=resolve(process.argv[3]);
if(existsSync(out)&&readdirSync(out).length)throw Error('Output directory must be empty: '+out);
mkdirSync(out,{recursive:true});
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const baseHash=hash(base);
const client=await connectMcp('single-scene-art-pressure',out);
let mapPath=join(out,'base.gil'),step=0;copyFileSync(base,mapPath);
const manifest={state:'preparing',baseHash,sourceRepo:repo,modules:[],performance:'UNVERIFIED'};
writeFileSync(join(out,'candidate.json'),JSON.stringify(manifest,null,2));
async function call(name,args){
 const r=await client.callTool({name,arguments:{mapPath,...args}},undefined,{timeout:120000});
 const data=r.structuredContent??JSON.parse(r.content.find(c=>c.type==='text').text);
 writeFileSync(join(out,`${String(++step).padStart(2,'0')}-${name}.json`),JSON.stringify(data,null,2));
 if(r.isError||data.error)throw Error(JSON.stringify(data));if(data.mapPath)mapPath=data.mapPath;return data;
}
try{
 for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeFileSync(join(out,uri.split('//')[1]+'.json'),JSON.stringify(await client.readResource({uri}),null,2));
 const image=await call('scene_add_client_template',{template:{name:'AP_Image',kind:'image',image:100001,size:[20,20],mask:false},outputName:'pressure-image'});
 const text=await call('scene_add_client_template',{template:{name:'AP_Text',kind:'text',size:[180,40],text:{content:'',fontSize:18,backgroundOpacity:0,outline:false}},outputName:'pressure-text'});
 const host=await call('scene_add_client_template',{template:{name:'AP_Host',kind:'container',size:[20,20]},outputName:'pressure-host'});
 for(const id of [image.templateIndex,text.templateIndex,host.templateIndex])if(!Number.isSafeInteger(id)||id<=0)throw Error('Invalid template index');
 const sources=[['AP_A','art/processed/ai-samples/lumine/A/asset.lua',1.25],['AP_B2','art/processed/ai-samples/lumine/B2/asset.lua',.72],['AP_Card','art/spikes/card-capacity/reference/card.lua',.62],['AP_HighCard','art/processed/ai-samples/starfall/B/card.lua',.50]];
 for(const [name,path,scale] of sources){
  const raw=readFileSync(join(repo,path),'utf8');
  let source=raw.split('\n').filter(line=>!line.startsWith('-- MILIASTRA_EDITOR_SCENE_V1')).join('\n');
  source=source.replace(/local IMAGE_PREFAB_ID\s*=\s*0\b/,`local IMAGE_PREFAB_ID = ${image.templateIndex}`).replace(/local TEXTBOX_PREFAB_ID\s*=\s*0\b/,`local TEXTBOX_PREFAB_ID = ${text.templateIndex}`).replace(/local BASE_SCALE\s*=\s*1\b/,`local BASE_SCALE = ${scale}`);
  source=`return function(host)\nlocal script={object=host}\nlocal OnStart,OnDestroy\nlocal printerr=function(message) error(message) end\n${source}\nreturn {start=OnStart,destroy=OnDestroy}\nend\n`;
  const file=join(out,`${name}.lua`);writeFileSync(file,source);
  await call('scene_set_client_script',{name,sourceFile:file,outputName:`pressure-${name}`});
  manifest.modules.push({name,source:path,sourceHash:hash(join(repo,path)),boundHash:hash(file),scale});
 }
 const icon=`return function(host,count)
 local controls={}
 return {start=function()
  for i=1,count do
   local c=assert(game.InstantiateClientUIControl(${image.templateIndex},host));controls[#controls+1]=c
   c:SetActive(true);c:SetVisible(true);c:SetImage(Enum.ImageSource.StaticReference,100002)
   local angle=i*2.39996323;local radius=math.sqrt(i)*3
   c:SetAnchoredPosition(math.cos(angle)*radius,math.sin(angle)*radius)
   c:SetSizeDelta(5+i%6,5+i%5);c.imageColor=Color.FromRGBA(150+i%100,100+i%120,45+i%90,220)
  end
 end,destroy=function() controls={} end}
end`;
 writeFileSync(join(out,'AP_Icon.lua'),icon);
 await call('scene_set_client_script',{name:'AP_Icon',sourceFile:join(out,'AP_Icon.lua'),outputName:'pressure-icon'});
 const controller=readFileSync(join(here,'controller.lua'),'utf8').replace('local HOST_PREFAB_ID = 0',`local HOST_PREFAB_ID = ${host.templateIndex}`);
 writeFileSync(join(out,'AP_Control.lua'),controller);
 await call('scene_set_client_script',{name:'AP_Control',sourceFile:join(out,'AP_Control.lua'),outputName:'pressure-controller'});
 const controls=[{name:'Backdrop',kind:'image',image:100001,size:[1280,720],colour:'#131923'},
  {name:'Status',kind:'text',position:[0,330],size:[1240,35],text:{content:'二维自绘同屏压力测试',fontSize:22,backgroundOpacity:0,outline:false}},
  {name:'Metrics',kind:'text',position:[0,295],size:[1240,35],text:{content:'准备中',fontSize:17,backgroundOpacity:0,outline:false}}];
 const buttons=[['Prev','上一档'],['Next','下一档'],['Clear','清空'],['Rebuild','重建当前档'],['Motion','整组移动'],['Auto','自动逐档'],['Reuse','缓存复用'],['Mid','5角色+10轻卡'],['Masked','3高精角色'],['High','5角色+10高卡'],['Extreme','极限8125'],['Icons','10技能图标']];
 const toolbar=[];
 buttons.forEach(([name,label],i)=>{
  const x=-500+(i%6)*200,y=250-Math.floor(i/6)*42;
  toolbar.push({name:name+'Plate',kind:'image',position:[x,y],image:100001,size:[190,36],colour:'#343c52'},
   {name:name+'Label',kind:'text',position:[x,y],size:[190,34],text:{content:label,fontSize:16,backgroundOpacity:0,outline:false}},
   {name,kind:'cursorArea',position:[x,y],size:[190,36]});
 });
 // Draw diagnostics last so artwork can never hide or eat the control panel.
 controls.push({name:'Toolbar',kind:'container',children:toolbar});
 await call('scene_add_client_ui',{name:'ART_PRESSURE_ALL',script:'AP_Control',controls,showCursor:true,replace:true,outputName:'art-pressure-all'});
 const checked=await call('scene_check_client',{});if(!checked.ok||checked.errors)throw Error(JSON.stringify(checked));
 const candidate=join(out,'art-pressure-all.gil');copyFileSync(mapPath,candidate);
 if(hash(base)!==baseHash)throw Error('Original base changed');
 Object.assign(manifest,{state:'prepared',candidate,candidateHash:hash(candidate),checked,stages:20,liveWrite:false});
 writeFileSync(join(out,'candidate.json'),JSON.stringify(manifest,null,2));console.log(JSON.stringify({candidate,sha256:manifest.candidateHash,checked}));
}finally{await client.close();}
