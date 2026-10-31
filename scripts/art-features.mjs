import {prepareMonsterArt} from './monster-art.mjs';
import {portraitInventory,portraitSourceInputs} from './official-portraits.mjs';
// Candidate-local developer flags. Never player settings or a remote service.
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
export const artFeatureKeys=Object.freeze(['cards','menuBackground','selectionAvatar','battlePortrait','monsters']);
const cliKeys=['cards','menu-background','selection-avatar','battle-portrait','monsters'];
export const artFeatureModule='abyss_art_features';
export function normalizeArtFeatures(overrides={}) {
 if(!overrides||typeof overrides!=='object'||Array.isArray(overrides)||![Object.prototype,null].includes(Object.getPrototypeOf(overrides)))throw Error('Invalid art features: expected a boolean-key object');
 if(Reflect.ownKeys(overrides).some(key=>!artFeatureKeys.includes(key)||typeof overrides[key]!=='boolean'))throw Error('Invalid art feature: unknown key or non-boolean value');
 return Object.fromEntries(artFeatureKeys.map(key=>[key,overrides[key]??false]));
}
export function resolveArtFeatures({artFeatures,readyCardArt,nativeCardArt}={}) {
 const flags=normalizeArtFeatures(artFeatures);
 if(nativeCardArt!==undefined){
  if(!nativeCardArt||typeof nativeCardArt!=='object'||Array.isArray(nativeCardArt)
   ||Reflect.ownKeys(nativeCardArt).some(key=>!['registry','hosts','count'].includes(key)))throw Error('Invalid native art feature options');
  if(nativeCardArt.count!==undefined&&(![0,1,5,10].includes(nativeCardArt.count)||nativeCardArt.hosts!==undefined))throw Error('Invalid native art feature count/hosts');
  if(nativeCardArt.count!==0&&(nativeCardArt.registry===undefined||nativeCardArt.count===undefined&&!Array.isArray(nativeCardArt.hosts)))throw Error('Invalid native art feature registry/hosts');
 }

 if(readyCardArt!==undefined&&typeof readyCardArt!=='boolean')throw Error('Invalid art feature readyCardArt boolean');
 const legacyOff=readyCardArt===false||nativeCardArt?.count===0;
 const legacyOn=nativeCardArt!==undefined&&nativeCardArt?.count!==0;
 if(legacyOff&&(legacyOn||artFeatures?.cards===true)||legacyOn&&artFeatures?.cards===false)throw Error('Conflicting cards art feature options');
 if(legacyOn)flags.cards=true;
 if(legacyOff)flags.cards=false;
 return flags;
}
export function artFeatureArgs(argv) {
 const args=[],artFeatures={};
 for(const arg of argv) {
  if(!arg.startsWith('--art-')){args.push(arg);continue;}
  const match=/^--art-([a-z-]+)=(true|false)$/.exec(arg),index=match?cliKeys.indexOf(match[1]):-1;
  if(index<0)throw Error('Invalid art feature option: use a known --art-<category>=true|false');
  const key=artFeatureKeys[index];if(Object.hasOwn(artFeatures,key))throw Error('Duplicate art feature option: '+key);
  artFeatures[key]=match[2]==='true';
 }
 return {args,artFeatures};
}
// 2026-10-31 Owner candidate preference: the developer CLIs (build:native / build-native-candidate)
// default the new custom select look, card chrome+art and low-poly scene backgrounds ON. API/build-ui defaults
// stay false. Explicit --art-<category>=false always wins; legacy card-art switches keep deciding cards.
export const candidateArtDefaults=Object.freeze({cards:true,menuBackground:true,selectionAvatar:true,battlePortrait:true});
export function withCandidateArtDefaults(explicit={},{cardsDecided=false}={}) {
 const out={...explicit};
 for(const [key,value]of Object.entries(candidateArtDefaults))if(!Object.hasOwn(out,key)&&!(key==='cards'&&cardsDecided))out[key]=value;
 return out;
}
export function artFeatureBuildArgs(flags){const normalized=normalizeArtFeatures(flags);return artFeatureKeys.map((key,i)=>`--art-${cliKeys[i]}=${normalized[key]}`);}
export function artFeaturesSource(flags) {
 const values=normalizeArtFeatures(flags);
 return `-- Generated developer-controlled candidate configuration; rebuild to change.\nreturn {schemaVersion=2,flags={${artFeatureKeys.map(key=>`${key}=${values[key]}`).join(',')}}}\n`;
}
export function writeArtFeatures(directory,flags){const source=artFeaturesSource(flags);writeFileSync(join(directory,artFeatureModule+'.lua'),source);return source;}
export function artFeatureReceipt(flags) {
 const config={schemaVersion:2,flags:normalizeArtFeatures(flags)};
 return {...config,configSha256:createHash('sha256').update(JSON.stringify(config)).digest('hex')};
}
export function verifyArtFeatureReceipt(receipt) {
 if(!receipt||receipt.schemaVersion!==2||Reflect.ownKeys(receipt).some(k=>!['schemaVersion','flags','configSha256'].includes(k))
  ||!receipt.flags||Reflect.ownKeys(receipt.flags).length!==artFeatureKeys.length)throw Error('Invalid art feature receipt');
 const expected=artFeatureReceipt(receipt.flags);
 if(receipt.configSha256!==expected.configSha256)throw Error('Art feature receipt config digest mismatch');
 return expected.flags;
}
export function artBuildOptionsFromReceipt(receipt) {
 const flags=verifyArtFeatureReceipt(receipt?.artFeatures),native=receipt.nativeCardArt;
 if(flags.cards!==Boolean(native||receipt.readyCardArt?.enabled===true)||native&&receipt.readyCardArt)
  throw Error('Card artwork receipt conflicts with art features');
 if(flags.monsters!==Boolean(receipt.nativeMonsterArt))throw Error('Monster artwork receipt conflicts with art features');
 if(receipt.nativeMonsterArt){
  const actual=receipt.nativeMonsterArt;
  const registry=JSON.parse(readFileSync(new URL('../data/presentation/native-monster-art.json',import.meta.url),'utf8'));
  const art=prepareMonsterArt(registry);
  const records=[...art.sourceInputs.slice(0,2),...Object.values(art.additionalAssets??{}).flatMap(asset=>asset.sourceInputs)];
  const expected={enabled:true,assetCount:Object.keys(art.assets).length,bindingCount:Object.keys(art.bindings).length,
   capacity:art.poolCapacity,allocation:'per-drawable-actor-instance'};
  if(Reflect.ownKeys(actual).some(key=>![...Object.keys(expected),'inputs'].includes(key))
   ||Object.entries(expected).some(([key,value])=>actual[key]!==value)
   ||!Array.isArray(actual.inputs)||actual.inputs.length!==records.length
   ||records.some(record=>actual.inputs.filter(row=>row?.path===record.path&&row.sha256===record.sha256&&Number.isInteger(row.bytes)&&row.bytes>0).length!==1))
   throw Error('Monster artwork inventory differs from art features');
 }
 if(flags.menuBackground!==Boolean(receipt.officialBackground))throw Error('Background artwork receipt conflicts with art features');
 if((flags.selectionAvatar||flags.battlePortrait)!==Boolean(receipt.officialPortraits))throw Error('Portrait artwork receipt conflicts with art features');
 if(receipt.officialPortraits){
  const expected=portraitInventory(flags),actual=receipt.officialPortraits;
  for(const [key,value]of Object.entries(expected))if(JSON.stringify(actual[key])!==JSON.stringify(value))throw Error('Portrait artwork inventory differs from art features: '+key);
  const paths=portraitSourceInputs(flags);
  if(!Array.isArray(actual.inputs)||actual.inputs.length!==paths.length||paths.some(path=>actual.inputs.filter(row=>
   typeof row?.path==='string'&&(row.path.replaceAll('\\','/')===path||row.path.replaceAll('\\','/').endsWith('/'+path))).length!==1))
   throw Error('Portrait artwork input inventory differs from art features');
 }

 if(native&&(typeof native.registry?.path!=='string'||!native.registry.path||!Array.isArray(native.hosts)||!native.hosts.length))throw Error('Invalid static card artwork receipt');
 return {artFeatures:flags,...(native?{nativeCardArt:{registry:native.registry.path,hosts:[...native.hosts]}}:{})};
}
export function readArtFeatures(directory) {
 const source=readFileSync(join(directory,artFeatureModule+'.lua'),'utf8');
 const match=/return \{schemaVersion=2,flags=\{cards=(true|false),menuBackground=(true|false),selectionAvatar=(true|false),battlePortrait=(true|false),monsters=(true|false)\}\}\n$/.exec(source);
 if(!match)throw Error('Invalid generated art feature configuration');
 const flags=Object.fromEntries(artFeatureKeys.map((key,i)=>[key,match[i+1]==='true']));
 if(source!==artFeaturesSource(flags))throw Error('Noncanonical generated art feature configuration');
 return flags;
}
