// Derived metadata only. Explicit JDK8+ non-tree HashMap profile, never a
// claim about the unobserved original game's bundled Java runtime.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
const flag=name=>args.includes(name);
const option=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
const registrationPath=path.resolve(option('--registration',path.join(root,'data/reference/sts1-card-pools/registration.json')));
const outputPath=path.resolve(option('--output',path.join(root,'docs/rules/evidence/source-card-pools-319009-jdk8plus.json')));
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const requireThat=(condition,message)=>{if(!condition)throw new Error(message);};
const raw=fs.readFileSync(registrationPath);
const source=JSON.parse(raw);
const rows=[...source.registration].sort((a,b)=>a.registrationIndex-b.registrationIndex);
requireThat(source.source.commit==='319009d5df0a82d9fb0f23cc22322286c6a87ec0','wrong source commit');
requireThat(rows.length===370 && new Set(rows.map(r=>r.id)).size===370,'expected complete 370 unique registrations');
rows.forEach((r,i)=>requireThat(r.registrationIndex===i,'missing registration position'));
const groups=['red','green','blue','purple','colorless','curse'];
requireThat(rows.map(r=>r.registrationGroup).every((g,i,a)=>groups.indexOf(g)>=0 && (i===0 || groups.indexOf(a[i-1])<=groups.indexOf(g))),'registration initialization groups changed');

function stringHashCode(value){
  let h=0;
  for(let i=0;i<value.length;i++)h=(Math.imul(h,31)+value.charCodeAt(i))|0;
  return h;
}
let table=[],size=0,threshold=0,maxChain=0;
const resizes=[];
function resize(){
  const old=table,oldCap=old.length,newCap=oldCap===0?16:oldCap*2;
  table=Array.from({length:newCap},()=>[]);
  if(oldCap>0){
    for(let i=0;i<oldCap;i++){
      // JDK8 resize preserves the old chain order within each split half.
      for(const entry of old[i])table[i+((entry.spread&oldCap)!==0?oldCap:0)].push(entry);
    }
  }
  threshold=newCap*0.75;
  resizes.push({sizeBeforeInsertionOrResize:size,oldCapacity:oldCap,newCapacity:newCap,threshold});
}
for(const row of rows){
  if(table.length===0)resize();
  const javaHash=stringHashCode(row.id),spread=(javaHash^(javaHash>>>16))>>>0;
  const chain=table[spread&(table.length-1)];
  requireThat(!chain.some(e=>e.row.id===row.id),'duplicate map key');
  chain.push({row,javaHash,spread});size++;
  maxChain=Math.max(maxChain,chain.length);
  // The actual fixed keys never reach this guard. Refuse to invent tree-bin
  // behavior if a future metadata input changes that boundary.
  requireThat(chain.length<8,'treeification/early resize profile needs separate audit');
  if(size>threshold)resize();
}
const entries=[];
table.forEach((chain,bucket)=>chain.forEach((entry,chainIndex)=>entries.push({...entry,bucket,chainIndex})));
const libraryOrder=entries.map(e=>e.row.id);
const classes={};
for(const [classId,color]of Object.entries({ironclad:'RED',silent:'GREEN',defect:'BLUE',watcher:'PURPLE'})){
  const colored=entries.filter(e=>e.row.color===color);
  requireThat(colored.length===75,`incomplete ${color} catalog`);
  const tmp=colored.filter(e=>e.row.rarity!=='BASIC');
  const normal={},src={};
  for(const rarity of ['COMMON','UNCOMMON','RARE']){
    normal[rarity]=tmp.filter(e=>e.row.rarity===rarity).map(e=>e.row.id);
    // CardGroup.addToTop appends; clone uses addToBottom, i.e. insert(0).
    src[rarity]=[...normal[rarity]].reverse();
  }
  const combined=['COMMON','UNCOMMON','RARE'].flatMap(rarity=>src[rarity]);
  const byId=new Map(colored.map(e=>[e.row.id,e.row]));
  const nonHealing=combined.filter(id=>!byId.get(id).tags.includes('HEALING'));
  classes[classId]={
    color,
    libraryOrder:colored.map(e=>({...e.row,javaStringHashCode:e.javaHash,hashMapSpreadUnsigned:e.spread,
      finalBucket:e.bucket,bucketChainIndex:e.chainIndex,globalLibraryIndex:libraryOrder.indexOf(e.row.id)})),
    unlockedNonBasicTmpPool:tmp.map(e=>e.row.id),
    normalRarityPools:normal,
    sourceRarityPools:src,
    sourceCommonThenUncommonThenRare:combined,
    inCombatAny:nonHealing,
    inCombatByType:Object.fromEntries(['ATTACK','SKILL','POWER'].map(type=>[type,nonHealing.filter(id=>byId.get(id).type===type)])),
  };
}
const manifest={
  schemaVersion:1,
  evidenceStatus:'derived-candidate-runtime-profile-not-original-client-certified',
  source:{...source.source,registrationSha256:sha(raw),registrationCount:rows.length},
  runtimeProfile:{id:'jdk8plus-default-string-hashmap-no-tree-bins-v1',
    javaStringHash:'UTF16 code units; signed int32 h=31*h+char',
    spread:'unsigned32(h ^ (h >>> 16))',initialCapacity:16,loadFactor:0.75,
    insertion:'append to collision chain',resize:'double capacity, stable low/high bucket split',
    iteration:'ascending table bucket, then chain order',runtimeOfOriginalClient:'unknown'},
  assumptions:{freshCardLibrary:true,allCardsUnlocked:true,allCharactersUnlocked:true,ascension:0,
    dailyMods:false,externalMods:false,postInitializationPoolMutation:false,
    unlockFiltersRecordedAtRuntime:false,initializeCardPoolsConsumesSourceRng:false},
  diagnostics:{finalSize:size,finalCapacity:table.length,finalThreshold:threshold,
    maxChainDuringInsertion:maxChain,maxFinalChain:Math.max(...table.map(c=>c.length)),resizes,
    libraryOrderSha256:sha(libraryOrder.join('\n')+'\n')},
  hashMapEntryOrder:libraryOrder,
  classes,
};
const encoded=JSON.stringify(manifest,null,2)+'\n';
if(flag('--verify'))requireThat(fs.readFileSync(outputPath,'utf8')===encoded,'manifest differs; regenerate and review');
else{fs.mkdirSync(path.dirname(outputPath),{recursive:true});fs.writeFileSync(outputPath,encoded);}

let javaEvidence;
if(flag('--java-check')){
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'source-card-map-'));
  try{
    const javaFile=path.join(dir,'CardMapOracle.java'),input=path.join(dir,'ids.txt');
    fs.writeFileSync(input,rows.map(r=>r.id).join('\n')+'\n');
    fs.writeFileSync(javaFile,`import java.nio.file.*;import java.nio.charset.*;import java.util.*;
class CardMapOracle {public static void main(String[] args)throws Exception {
 System.err.println(System.getProperty("java.runtime.version"));
 HashMap<String,Integer> m=new HashMap<>();int i=0;
 for(String id:Files.readAllLines(Path.of(args[0]),StandardCharsets.UTF_8))m.put(id,i++);
 for(Map.Entry<String,Integer> e:m.entrySet())System.out.println(e.getKey());
}}
`);
    const run=spawnSync('java',[javaFile,input],{encoding:'utf8',timeout:30000});
    requireThat(run.status===0,`independent Java oracle failed: ${run.stderr}`);
    const actual=run.stdout.trimEnd().split('\n');
    requireThat(JSON.stringify(actual)===JSON.stringify(libraryOrder),'independent Java HashMap order differs');
    javaEvidence={schemaVersion:1,scope:'independent-host-runtime-check-not-original-client-runtime',
      runtimeVersion:run.stderr.trim(),entriesCompared:actual.length,
      registrationSha256:sha(raw),manifestSha256:sha(encoded),libraryOrderSha256:manifest.diagnostics.libraryOrderSha256,
      all370EntryPositionsMatch:true};
    const evidencePath=option('--java-evidence',null);
    if(evidencePath)fs.writeFileSync(path.resolve(evidencePath),JSON.stringify(javaEvidence,null,2)+'\n');
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
}
console.log(JSON.stringify({manifest:outputPath,manifestSha256:sha(encoded),profile:manifest.runtimeProfile.id,
  diagnostics:manifest.diagnostics,
  counts:Object.fromEntries(Object.entries(classes).map(([id,c])=>[id,{registered:c.libraryOrder.length,
    regular:c.sourceCommonThenUncommonThenRare.length,combatAny:c.inCombatAny.length,
    byType:Object.fromEntries(Object.entries(c.inCombatByType).map(([type,pool])=>[type,pool.length]))}])),
  javaEvidence},null,2));
