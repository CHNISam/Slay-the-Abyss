// Recipe only: save writes and validation use the installed MCP, never live-write.
import fs from 'node:fs';
import path from 'node:path';
import { Client } from 'file:///D:/MiliastraTools/genshin-miliastra-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from 'file:///D:/MiliastraTools/genshin-miliastra-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
const root = process.cwd(), out = path.resolve('build/ai-art');
const maps = JSON.parse(fs.readFileSync(path.join(out, 'maps.json'))).result.maps;
const base = maps.find(m => m.mapId === '1073741825');
if (!base) throw Error('Known clean test base missing; inspect list_maps before selecting another.');
const baseCopy = path.join(out, 'base.gil');
fs.copyFileSync(base.path, baseCopy);
const client = new Client({name:'abyss-ai-art-samples', version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,
    args:['D:/MiliastraTools/genshin-miliastra-mcp/src/server.mjs'], env:{...process.env,
      MILIASTRA_WORKSPACE:path.join(out, 'mcp'), MILIASTRA_ALLOW_LIVE_WRITE:'0',
      MILIASTRA_PYTHON:'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe',
      MILIASTRA_PLAYTEST_PYTHON:'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe'}}));
let step = 0;
const call = async (name, args) => {
  const result = await client.callTool({name, arguments:args}, undefined, {timeout:120000});
  fs.writeFileSync(path.join(out, `${++step}-${name}.json`), JSON.stringify({args, ...result}, null, 2));
  if (result.isError) throw Error(JSON.stringify(result.structuredContent || result.content));
  return result.structuredContent || JSON.parse(result.content.find(c => c.type === 'text').text);
};
const theme = JSON.parse(fs.readFileSync('data/presentation/ui_theme.json'));
const text = (name, value, x, y, width=900, size=18) => ({name, kind:'text', position:[x,y],size:[width,40],
  text:{content:value,fontSize:size,backgroundOpacity:0,outline:false,colour:theme.color.text,align:'centre'}});
try {
  for(const uri of ['miliastra://workflow', 'miliastra://platform-rules'])
    fs.writeFileSync(path.join(out, uri.split('/').at(-1)+'.json'), JSON.stringify(await client.readResource({uri}),null,2));
  const template = await call('scene_add_client_template', {mapPath:baseCopy,template:{name:'AI_Image',kind:'image',size:[20,20],image:100001,mask:false},outputName:'ai-template'});
  const textTemplate = await call('scene_add_client_template',{mapPath:template.mapPath,template:{name:'AI_Text',kind:'text',size:[180,40],text:{content:'美术实验',fontSize:18,backgroundOpacity:0,outline:false}},outputName:'ai-text-template'});
  const probe = await call('scene_set_client_script', {mapPath:textTemplate.mapPath,name:'AI_Probe',sourceFile:path.resolve('art/processed/ai-samples/probe.lua'),outputName:'ai-probe'});
  const candidates = {};
  for (const asset of ['baseline', 'lumine', 'starfall']) {
    let mapPath = probe.mapPath;
    const controls = [{name:'Backdrop',kind:'image',size:[1280,720],image:100001,colour:theme.color.backdrop},
      text('Status', `两图资产实验 / ${asset} / B`,0,280,1000,24),
      text('Metrics','客户端dt采样中（10秒；非GPU耗时）',0,-260),
      {name:'Plate',kind:'image',position:[0,-190],size:[240,60],image:100001,colour:theme.color.geoDeep},
      text('ButtonLabel','点击检查',0,-190,240,24),
      {name:'Confirm',kind:'cursorArea',position:[0,-190],size:[240,60]}];
    if (asset !== 'baseline') {
      const luaPath = path.resolve(asset==='lumine'?'art/processed/ai-samples/lumine/B2/asset.lua':'art/processed/ai-samples/starfall/B/card.lua');
      let source = fs.readFileSync(luaPath,'utf8').replace('local IMAGE_PREFAB_ID = 0',`local IMAGE_PREFAB_ID = ${template.templateIndex}`);
      if (asset === 'starfall') source = source.replace('local TEXTBOX_PREFAB_ID = 0',`local TEXTBOX_PREFAB_ID = ${textTemplate.templateIndex}`);
      // Probe only: display lifecycle evidence without changing the upstream drawing functions.
      source += `\nlocal AI_OriginalStart = OnStart\nfunction OnStart()\n AI_OriginalStart()\n print('AI_ART_DRAWN ${asset}')\nend\n`;
      const bound = path.join(out, `AI_${asset}.lua`);
      fs.writeFileSync(bound,source);
      mapPath = (await call('scene_set_client_script',{mapPath,name:'AI_Asset',sourceFile:bound,outputName:`ai-${asset}-script`})).mapPath;
      controls.push({name:'ArtHolder',kind:'container',position:asset==='lumine'?[0,30]:[0,80],size:[400,400],
        children:[{name:'Artwork',kind:'container',size:[252,304],script:'AI_Asset'}]});
      controls.push(text('Budget',asset==='lumine'?'角色 B2 / 252×304 / 770 图 + 169 蒙版':'星陨剑 B / 原生卡面 148×208 / 插图区 144×64',0,-130,1000,18));
    }
    const ui = await call('scene_add_client_ui',{mapPath,name:'AI_Art_Test',script:'AI_Probe',controls,showCursor:true,outputName:`abyss-ai-${asset}`,replace:true});
    const check = await call('scene_check_client',{mapPath:ui.mapPath});
    if(!check.ok) throw Error(JSON.stringify(check));
    candidates[asset] = {mapPath:ui.mapPath,check,templateIndex:template.templateIndex,officialImport:'not_tested',inGame:'not_tested'};
    fs.copyFileSync(ui.mapPath,path.join(out,`abyss-ai-${asset}.gil`));
    console.log(asset,ui.mapPath,`errors=${check.errors} warnings=${check.warnings}`);
  }
  fs.writeFileSync(path.join(out,'candidates.json'),JSON.stringify(candidates,null,2));
} finally {await client.close();}
