import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {join,resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {prepareShapeSample,shapeSample} from './hexaghost.mjs';
import {shapeTools} from '../upstream-shapes.mjs';
import {createHash} from 'node:crypto';
const here=dirname(fileURLToPath(import.meta.url));
const toolRoot=resolve(process.env.MILIASTRA_MCP_ROOT||'.artifacts/miliastra-upstream');
const workspace=join(here,'.local');mkdirSync(workspace,{recursive:true});
const sdk=join(toolRoot,'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(join(sdk,'index.js'))),{StdioClientTransport}=await import(pathToFileURL(join(sdk,'stdio.js')));
const client=new Client({name:'abyss-shape-probe',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:['D:/MiliastraTools/genshin-miliastra-mcp/src/server.mjs'],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_SAVE_ROOTS:JSON.stringify([resolve('.')]),MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
const shapeAdapter=await shapeTools(workspace);
let index=0;
async function call(name,args){
 console.log('SHAPE',name);
 const raw=name==='scene_add_shape_prefab'||name==='scene_preview_shapes'?await shapeAdapter.call(name,args):await client.callTool({name,arguments:args},undefined,{timeout:120000});
 writeFileSync(join(workspace,`${++index}-${name}.json`),JSON.stringify(raw,null,2));
 if(raw.isError)throw Error(JSON.stringify(raw));
 const value=raw.structuredContent??JSON.parse(raw.content.find(c=>c.type==='text').text);
 if(value.error)throw Error(JSON.stringify(value));return value;
}
try{
 for(const uri of ['miliastra://workflow','miliastra://platform-rules'])await client.readResource({uri});
 const source=process.argv[2]||'.artifacts/native-3d-lab/85472c95-6d2f-421c-b16a-8e8b8dc1a4d2/native-3d-lab.gil';
 const previews=await shapeAdapter.call('scene_preview_shapes',{parts:shapeSample.parts,views:['front','side','top','angle'],size:512});
 if(previews.isError)throw Error(JSON.stringify(previews));
 mkdirSync(join(here,'preview'),{recursive:true});
 const views=previews.structuredContent.views,images=previews.content.filter(c=>c.type==='image');
 for(const [i,image]of images.entries())writeFileSync(join(here,'preview',views[i]+'.png'),Buffer.from(image.data,'base64'));
 const metadata={...previews.structuredContent,provenance:shapeAdapter.provenance,views:images.map((image,i)=>({view:views[i],sha256:createHash('sha256').update(Buffer.from(image.data,'base64')).digest('hex')}))};
 writeFileSync(join(here,'preview/receipt.json'),JSON.stringify(metadata,null,2));
 const result=await prepareShapeSample({mapPath:resolve(source),call});
 const readbackPreviews=await shapeAdapter.call('scene_preview_shapes',{mapPath:result.mapPath,prefab:result.prefabId,views:['front','side','top','angle'],size:512});
 if(readbackPreviews.isError)throw Error(JSON.stringify(readbackPreviews));
 const finalImages=readbackPreviews.content.filter(c=>c.type==='image'),finalViews=readbackPreviews.structuredContent.views;
 for(const [i,image]of finalImages.entries())writeFileSync(join(here,'preview',finalViews[i]+'.png'),Buffer.from(image.data,'base64'));
 writeFileSync(join(here,'preview/receipt.json'),JSON.stringify({...readbackPreviews.structuredContent,provenance:shapeAdapter.provenance,source:'GIL prefab readback, not source-parts-only',views:finalImages.map((image,i)=>({view:finalViews[i],sha256:createHash('sha256').update(Buffer.from(image.data,'base64')).digest('hex')}))},null,2));
 writeFileSync(join(workspace,'sample.json'),JSON.stringify(result,null,2));
 console.log('SHAPE_DONE',JSON.stringify({mapPath:result.mapPath,inventory:result.inventory}));
}finally{await client.close()}
