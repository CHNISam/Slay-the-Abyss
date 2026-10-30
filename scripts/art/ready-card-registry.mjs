// Read frozen exporter literals; never execute, refit or render artwork.
import {readFileSync} from 'node:fs';
import {resolve,join,dirname,relative,isAbsolute} from 'node:path';
import {prepareOutputDirectory,writeExclusive} from '../evidence-files.mjs';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {validateNativeCardArt} from '../card-art-samples.mjs';
const ids=['armaments','cleave','heavy_blade'];
const sha=s=>createHash('sha256').update(s).digest('hex');
export function readExportTables(source) {
 // A deliberately narrow numeric/string-array reader, not a Lua evaluator.
 // Source hashes are checked by the caller before these four frozen tables.
 const tables={};
 for(const name of ['ROOT','ELEMENTS','ROTATIONS','IMAGE_TYPES']) {
  const matches=[...source.matchAll(new RegExp('^local '+name+'\\s*=\\s*','gm'))];
  if(matches.length!==1)throw Error((matches.length?'duplicate':'missing')+' exporter literal '+name);
  let i=matches[0].index+matches[0][0].length;
  const ws=()=>{while(/\s/.test(source[i]??'')&&i<source.length)i++;};
  function value() {
   ws();
   if(source[i]==='{') {
    i++;const rows=[];ws();if(source[i]==='}'){i++;return rows;}
    while(i<source.length) {
     rows.push(value());ws();if(source[i]==='}'){i++;return rows;}
     if(source[i++]!==',')throw Error('Expected literal separator');
     ws();if(source[i]==='}'){i++;return rows;}
    }
    throw Error('Unterminated exporter literal');
   }
   const token=source.slice(i).match(/^(?:-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|"(?:basic|stretch)")/);
   if(!token)throw Error('Expected numeric or image-type literal');
   i+=token[0].length;const result=JSON.parse(token[0]);
   if(typeof result==='number'&&!Number.isFinite(result))throw Error('Nonfinite literal');
   return result;
  }
  tables[name]=value();if(!Array.isArray(tables[name]))throw Error('Expected literal array');
 }
 return tables;
}
export function buildReadyCardRegistry({root=process.cwd(),read=p=>readFileSync(p,'utf8')}={}) {
 const assets={},sourceInputs=[];
 for(const id of ids) {
  const base=join(root,'art/cards/traveler-geo',id),manifest=JSON.parse(read(join(base,'asset.json')));
  if(manifest.card_id!==id||manifest.approval?.status!=='owner-reviewed-offline-visual'
    ||!manifest.approval.scope.includes('native-redraw'))throw Error('Missing native approval: '+id);
  const data={};
  for(const kind of ['lua','json']) {
   const path=join(base,'native-art.'+kind),bytes=read(path),hash=sha(bytes);
   if(hash!==manifest.files['native-art.'+kind].sha256)throw Error('Native source hash mismatch: '+id);
   data[kind]=bytes;sourceInputs.push({cardId:id,kind,path,sha256:hash});
  }
  const scene=JSON.parse(data.json),t=readExportTables(data.lua);
  if(JSON.stringify(t.ROOT)!==JSON.stringify([0,0,144,64,.5,.5,.5,.5,.5,.5,1,1,0])
    ||scene.canvas.width!==144||scene.canvas.height!==64||scene.elements.length!==t.ELEMENTS.length
    ||t.ROTATIONS.length!==t.ELEMENTS.length||t.IMAGE_TYPES.length!==t.ELEMENTS.length
    ||manifest.controls.masks!==0)throw Error('Frozen native canvas/count mismatch: '+id);
  const slots=t.ELEMENTS.map((r,i)=>{
   if(r.length!==18||t.ROTATIONS[i].length!==2)throw Error('Malformed native row');
   return {image:r[0],position:r.slice(1,3),size:r.slice(3,5),pivot:r.slice(5,7),anchorMin:r.slice(7,9),
    anchorMax:r.slice(9,11),scale:r.slice(11,13),rotation:[...t.ROTATIONS[i],r[13]],colour:r.slice(14,18),imageType:t.IMAGE_TYPES[i]};
  });
  assets[id]={cardId:id,luaSha256:sha(data.lua),jsonSha256:sha(data.json),slots};
 }
 const registry={schemaVersion:2,editorCommit:'103025f9095d8089e3f9bf097f4d0c5fe039d546',canvas:[144,64],assets,sourceInputs};
 validateNativeCardArt(registry);return registry;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 const output=resolve(process.argv[2]??'build/ready-card-art/registry.json');
 const rel=relative(resolve('build'),output);
 if(!rel||rel==='..'||rel.startsWith('..'+(process.platform==='win32'?'\\':'/'))||isAbsolute(rel))throw Error('Registry output must be in build/');
 const registry=buildReadyCardRegistry();prepareOutputDirectory(process.cwd(),dirname(output));writeExclusive(output,registry);
 console.log(`Ready native registry: ${ids.join(', ')}; ${output}; device acceptance pending`);
}
