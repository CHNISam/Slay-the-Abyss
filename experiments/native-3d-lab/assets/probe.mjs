import {readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {resolve,join,dirname,relative} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash,randomUUID} from 'node:crypto';
import {assetControls,materialSample} from './specimen.mjs';
import {controlsForReadback} from '../ui-readback.mjs';
import {equivalent} from '../../../scripts/native-candidate-audit.mjs';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../../..');
const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const record=p=>({path:relative(root,p).replaceAll('\\','/'),sha256:hash(p),bytes:readFileSync(p).length});
const input=resolve(process.argv[2]||'.artifacts/native-3d-base/base.gil');
const output=resolve('.artifacts/native-3d-material-probe',randomUUID());mkdirSync(output,{recursive:true});
const {addClientTemplate,getClientUi}=await import(pathToFileURL(join(toolRoot,'src/scene-save.mjs')));
const baselinePath=join(root,'art/performance/background-budget-v1.json'),baseline=read(baselinePath);
if(baseline.width!==480||baseline.height!==270||baseline.count!==4500||baseline.rows.length!==4500)throw Error('Recorded background baseline changed');
const template=assetControls({visible:true});
const written=addClientTemplate({mapPath:input,...template,outputName:'native-material-specimen'},output);
const actual=getClientUi({mapPath:written.mapPath,template:template.name});
if(!equivalent(controlsForReadback([template],true),controlsForReadback([actual.template]),'controls'))throw Error('Native material readback differs');
const sheet=join(toolRoot,materialSample.sourceSheet),sheetCopy=join(here,'plate-colour_03.jpg');copyFileSync(sheet,sheetCopy);
const imageIndex=read(join(toolRoot,'src/scene/image-library/index.json'));
const effects=read(join(toolRoot,'src/scene/media/effects.json'));
const receipt={schemaVersion:1,sample:materialSample,input:record(input),output:record(written.mapPath),templateIndex:written.templateIndex,
  statuses:{staticTemplateWrite:'pass',templateReadback:'pass',officialImport:'not_run',visualInClient:'not_run',mobile:'not_run',officialLoad:'not_run'},
  catalogue:{images:imageIndex.categories.reduce((n,c)=>n+c.count,0),timedEffects:effects.timed.length,loopingEffects:effects.looping.length},
  inspectedSource:{toolRelativePath:materialSample.sourceSheet,sha256:hash(sheet),copiedSheet:record(sheetCopy),tileId:107134,
   observation:'contact sheet bottom row, purple/blue rectangular patterned plate labelled 107134; visible material reviewed, no claim of landscape resemblance'},
  sourceComparison:{baseline:record(baselinePath),baselineRole:'reference custom MENU background route; not the active battle backdrop',baselineDrawnImages:baseline.count,candidateDrawnImages:2,drawnImagesAvoidable:baseline.count-2,
   lowerBoundBaselineControls:baseline.count+1,candidateControls:3,lowerBoundControlsAvoidable:baseline.count-2,
   sameVisualContent:false,actualCandidateCacheFreed:false,explanation:'counterfactual source-level opportunity if the menu changes art direction; not measured savings from this in-battle toggle. Baseline group wrappers make actual total larger. The experiment retains baseline for switching, so hidden caches remain possible.'},
  currentBattleComparison:{savingsEstablished:false,currentVisibilityMeasured:false,
   existingSource:'scripts/official-backdrop-layout.mjs',existingRoute:'one native picture plus readability veil per visible backdrop',
   sampleRole:'different-art fallback specimen, not proof of fewer controls than the already-native battle background',
   forbiddenClaims:['current battle saves 4498 controls','better FPS','lower official load','same-quality compression']},
  integration:{layoutExport:'assetControls / installAssetControls from assets/specimen.mjs',luaModule:'abyss_3d_material_sample',luaSource:'assets/runtime.lua',api:'toggle(script.object, boolean) -> screen message',
   lifecycle:'caller re-applies toggle while comparison active after page refresh, invokes destroy before engine teardown; keep sample below battlePanel and HUD'},
};
writeFileSync(join(here,'specimen-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
writeFileSync(join(here,'specimen-template.json'),JSON.stringify(template,null,2)+'\n');
console.log(JSON.stringify({templateIndex:receipt.templateIndex,images:receipt.catalogue.images,effects:receipt.catalogue.timedEffects+receipt.catalogue.loopingEffects,baselineImages:baseline.count,candidateImages:2,statuses:receipt.statuses}));
