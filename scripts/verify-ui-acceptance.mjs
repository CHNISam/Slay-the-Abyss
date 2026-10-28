import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import Ajv from 'ajv';
import { resolve, dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { fileRecord, validDate, sha256 } from './evidence-files.mjs';
import { inside } from './evidence-files.mjs';
import { requireStartupEvidence } from './native-playtest-evidence.mjs';
import { sourceInputs, payloadDigest } from './build-native-candidate.mjs';
import { verifyNativeCardArtReceipt } from './card-art-samples.mjs';

const validate=new Ajv({strict:true,allErrors:true}).compile(JSON.parse(readFileSync(new URL('../schemas/ui-acceptance.schema.json',import.meta.url),'utf8')));
function decodeImage(file) {
  const result=spawnSync(process.env.ABYSS_PYTHON||'python',['-c','from PIL import Image; import sys; im=Image.open(sys.argv[1]); im.verify(); im=Image.open(sys.argv[1]); im.load(); assert im.width>0 and im.height>0',file],{encoding:'utf8',timeout:10000});
  if(result.error || result.status!==0)throw new Error(`Image decode failed: ${result.error?.message||result.stderr}`);
}
export function approvedDesignDigest(root=resolve('docs/design')) {
  const files=['UI_DESIGN.md'];
  function walk(dir){for(const entry of readdirSync(join(root,dir),{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){const path=`${dir}/${entry.name}`;if(entry.isDirectory())walk(path);else files.push(path);}}
  walk('prototype');walk('screens');
  // The current canvas supersedes PR19 on the screens it specifies. Retired
  // PatchNotes remains historical source and must never certify the product.
  if (existsSync(join(root, 'ui-canvas'))) {
    for (const entry of readdirSync(join(root, 'ui-canvas')).sort()) {
      if (entry !== 'PatchNotes.dc.html' && /\.(html|json|md)$/.test(entry)) files.push(`ui-canvas/${entry}`);
    }
  }
  return sha256(JSON.stringify(files.sort().map(path=>({path,sha256:fileRecord(join(root,path),root).sha256}))));
}

// Critical information/actions from the approved PR19 specification. Decoration
// and animations may remain in the parity ledger; missing HP may not.
export const criticalUiChecks = {
  menu: ['start', 'instructions'],
  character: ['selection', 'initialStats', 'initialDeck', 'confirm', 'back'],
  potions: ['effect', 'target', 'cancelWithoutConsumption', 'discard'],
  exit: ['discoverable', 'blocksUnderlyingInput', 'cancelPreservesRun', 'platformSettlement'],
  map: ['route', 'currentFloor', 'reachableNodes', 'gold', 'hpAndMaxHp'],
  battle: ['actorHpAndMaxHp', 'block', 'energy', 'intent', 'cardText', 'enemyAction'],
  rewards: ['gold', 'cardAddedOrSkipped', 'returnToMap'],
  cardChoice: ['readableChoices', 'clearSelection'],
  camp: ['healOrUpgrade', 'upgradeInformation'],
  shop: ['readableGoods', 'separatePrice', 'soldOrUnaffordable', 'leave'],
  event: ['readableText', 'clearChoices', 'result'], treasure: ['reward', 'continue'],
  result: ['outcome', 'statistics', 'restart', 'platformSettlement'],
  deck: ['ownedCards', 'upgrades', 'close'],
};

// Every screen is reviewed at the native base resolution on both input surfaces.
// These are human evidence checks, not conclusions from web screenshots.
for (const checks of Object.values(criticalUiChecks)) checks.push(
  'native1280x720', 'pcSafeArea', 'mobileSafeArea', 'fontAndLayers', 'input', 'capacityAndPerformance');

export function reviewUiAcceptance(manifest, expected, {evidenceRoot=process.cwd(),baselineRoot=resolve('docs/design')}={}) {
  const errors = [];
  if(!validate(manifest))errors.push(`Evidence schema: ${validate.errors.map(row=>row.instancePath+' '+row.message).join('; ')}`);
  const candidateHash=typeof expected==='string'?expected:expected.candidateHash;
  if(typeof expected!=='object'||!expected.buildId||!expected.runId||manifest.buildId!==expected.buildId||manifest.runId!==expected.runId||manifest.payloadDigest!==expected.payloadDigest)errors.push('Evidence does not match expected build/run/payload');
  if(!expected.baselineRevision||manifest.baselineRevision!==expected.baselineRevision)errors.push('Approved design revision changed or is missing');
  const used=new Map(),images=new Set();
  for (const [screen, required] of Object.entries(criticalUiChecks)) {
    const row = manifest.screens?.[screen];
    if (!row || row.status !== 'pass') { errors.push(`${screen}: ${row?.status || 'no review'}`); continue; }
    if (row.candidateHash !== candidateHash) errors.push(`${screen}: evidence belongs to another candidate`);
    if(row.runId!==manifest.runId||row.buildId!==manifest.buildId)errors.push(`${screen}: another build/run`);
    for(const [field,root] of [['baseline',baselineRoot],['screenshot',evidenceRoot]]) {
      try {
        if(!row[field])throw new Error('missing');
        const record=fileRecord(resolve(root,row[field]),root);
        if(record.sha256!==row[`${field}Hash`])throw new Error('hash mismatch');
        if(!images.has(record.path)){decodeImage(record.path);images.add(record.path);}
        if(field==='screenshot') {
          const previous=used.get(record.sha256);
          if(previous && (!row.sharedScreenshotReason || !manifest.screens[previous].sharedScreenshotReason))errors.push(`${screen}: shared screenshot requires explicit human explanation`);
          used.set(record.sha256,screen);
        }
      } catch(error) {errors.push(`${screen}: ${field} missing or invalid (${error.message})`);}
    }
    if (!row.reviewer?.trim() || !validDate(row.reviewedAt) || Date.parse(row.reviewedAt)>Date.now() || !row.reviewScope?.trim() || !row.operations?.length || !Array.isArray(row.unresolved) || row.unresolved.length) errors.push(`${screen}: screenshot comparison has not been reviewed completely`);
    for (const field of required) if (row.checks?.[field] !== true) errors.push(`${screen}: ${field} not verified in game`);
  }
  return errors;
}

export function verifyUiCandidateInputs(receipt,candidateFile,{root=process.cwd()}={}) {
  if(receipt.candidate.sha256!==fileRecord(candidateFile).sha256 || receipt.payloadDigest!==payloadDigest(sourceInputs(root)))throw new Error('Candidate receipt/payload is stale');
  verifyNativeCardArtReceipt(receipt.nativeCardArt,{root});
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [manifestFile = 'docs/design/ui-acceptance.json', candidateFile] = process.argv.slice(2);
  if (!candidateFile) throw new Error('Usage: node scripts/verify-ui-acceptance.mjs <review.json> <candidate.gil>');
  const manifest = JSON.parse(readFileSync(manifestFile, 'utf8'));
  const receipt=JSON.parse(readFileSync(join(dirname(resolve(candidateFile)),'candidate.json'),'utf8'));
  const startup=JSON.parse(readFileSync(join(dirname(resolve(candidateFile)),'startup-evidence.json'),'utf8'));
  const hash=fileRecord(candidateFile).sha256;
  verifyUiCandidateInputs(receipt,candidateFile);
  if(startup.candidateHash!==hash||startup.buildId!==receipt.buildId)throw new Error('Startup evidence belongs to another candidate/build');
  inside(dirname(resolve(candidateFile)),startup.expected.runDir);
  const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
  const {inspectDebugLog}=await import(pathToFileURL(join(toolRoot,'src/debug-log.mjs')));
  requireStartupEvidence(startup.statusSnapshot,startup.expected,{decodeLog:bytes=>inspectDebugLog(bytes,{limit:100000}),parserVersion:fileRecord(join(toolRoot,'src/debug-log.mjs')).sha256});
  const errors = reviewUiAcceptance(manifest,{candidateHash:hash,buildId:receipt.buildId,runId:startup.runId,payloadDigest:receipt.payloadDigest,baselineRevision:approvedDesignDigest()},
    {evidenceRoot:startup.expected.runDir});
  if (errors.length) { console.error('UI acceptance incomplete:\n' + errors.map(row => `- ${row}`).join('\n')); process.exitCode = 1; }
  else console.log('Critical UI information/actions accepted against approved baseline for this exact candidate.');
}
