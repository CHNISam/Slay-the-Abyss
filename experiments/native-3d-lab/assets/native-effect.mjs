import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export function nativeHitEffect({toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp'}={}){
  const source=join(toolRoot,'src/scene/media/effects.json'),bytes=readFileSync(source),catalog=JSON.parse(bytes);
  const row=catalog.timed.find(r=>r[0]===7);
  if(!row||row[1]!=='黄色闪光'||row[2]!==1.17||catalog.looping.some(r=>r[0]===7))throw Error('Native hit effect catalog identity changed');
  const indexPath=join(toolRoot,'src/scene/media/fx-thumbs.json'),packPath=join(toolRoot,'src/scene/media/fx-thumbs.bin');
  const indexBytes=readFileSync(indexPath),index=JSON.parse(indexBytes),place=index['7'];
  if(!Array.isArray(place)||place.length!==2)throw Error('Official native hit thumbnail missing');
  const thumbnail=readFileSync(packPath).subarray(place[0],place[0]+place[1]);
  if(hash(thumbnail)!=='b5407eb353da5140bd0a3b2ffa52eb5da84b4ea55f6929919be214065ed650cf')throw Error('Selected effect thumbnail changed; inspect it again');
  return {id:7,name:row[1],kind:'timed',seconds:row[2],source,sourceSha256:hash(bytes),
    sourceNote:catalog.source,thumbnail:{path:'experiments/native-3d-lab/assets/native-hit-thumb.jpg',
      source:packPath,indexSource:indexPath,indexSha256:hash(indexBytes),offset:place[0],bytes:place[1],sha256:hash(thumbnail),
      inspected:true,scope:'official editor catalog thumbnail, not a game screenshot'}};
}
export function addNativeHitEffect(source,branches){
  const anchor="  else{f.setCustomVariable(unit,'LAB_seq',sequence,true);";
  const gate=/(  else if\(command==='hit'&&false\)\{[^\n]*\}\n)  else\{f\.setCustomVariable\(unit,'LAB_seq',sequence,true\);/g;
  if(typeof source!=='string'||!Number.isSafeInteger(branches)||branches<1||branches>3
    ||source.includes('LAB_NATIVE_HIT_FX')||source.split(anchor).length!==branches+1||[...source.matchAll(gate)].length!==1)
    throw Error('Native hit effect insertion anchor changed or already installed');
  // Only the existing hit-capable guardian branch: other models narrow to attack-only.
  return source.replace(gate,(_match,prefix)=>prefix+"  else{/* LAB_NATIVE_HIT_FX: presentation only */if(command==='hit')f.playTimedEffects(7,unit,'GI_RootNode',true,false,[0,1.4,0],[0,0,0],1,true);f.setCustomVariable(unit,'LAB_seq',sequence,true);");
}
export async function installNativeEffect({call,nativeScene}={}){
  const graphId=nativeScene?.graphs?.server?.graphId;
  const record=nativeScene?.sources?.find(r=>r.graphId===graphId);
  if(typeof call!=='function'||!record)throw Error('Native effect requires existing server graph/source and current-copy call');
  const effect=nativeHitEffect();
  const code=addNativeHitEffect(record.code,nativeScene.prefabs?.length);
  // call is the parent's current-map adapter: do not rewind it to an old nativeScene.mapPath.
  const compiled=await call('write_graphs',{graphs:[{graphId,code}]});
  if(compiled.failed||compiled.error||compiled.errors?.length||compiled.written?.length!==1)throw Error('Native effect graph compile/write failed: '+JSON.stringify(compiled));
  const checked=await call('inspect_map',{}),readback=checked.graphs?.find(g=>g.id===graphId);
  if(!readback||readback.nodeCount<=0)throw Error('Native effect server graph readback missing');
  nativeScene.sources=nativeScene.sources.map(r=>r.graphId===graphId?{...r,code}:r);
  nativeScene.mapPath=compiled.mapPath??nativeScene.mapPath;
  return {effect,graphId,mapPath:nativeScene.mapPath,source:code,sourceSha256:hash(code),readback,
    trigger:'existing accepted hit request; Lua card damage already committed',
    maintenance:{extraGraphs:0,extraSignals:0,extraUiControls:0,nativeAssets:1,timedCallPerAcceptedHit:1},
    replaced2DFeedback:false,verification:{compiled:true,readback:true,visual:'not_run',gpuOrMemoryReduction:'not_measured',mobile:'not_run'}};
}
