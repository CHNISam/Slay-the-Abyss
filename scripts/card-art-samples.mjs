// Candidate assembly only. Geometry is read by the pinned Image Editor parser,
// never fitted/exported here. The ordinary card component remains unchanged.
import { readFileSync, realpathSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname, isAbsolute } from 'node:path';
import { fileRecord, sha256 } from './evidence-files.mjs';
import { toLua } from './build-lua-data.mjs';
import { createRequire } from 'node:module';

const editorCommit = '103025f9095d8089e3f9bf097f4d0c5fe039d546';
const vector = (x, n) => Array.isArray(x) && x.length === n && x.every(Number.isFinite);
const same = (a,b) => JSON.stringify(a) === JSON.stringify(b);
// Preserve filesystem-selected symlink/.. identity before applying root guards.
const inputRecord=(path,root)=>fileRecord(realpathSync.native(isAbsolute(path)?path:`${root}/${path}`),root);
export const nativeArtSlotPath = index => [`group${String(Math.floor(index/60)).padStart(3,'0')}`, `shape${String(index).padStart(4,'0')}`];

export function nativeCardArtArgs(argv) {
  const args=[],hosts=[];let count,registry,readyCardArt;
  for(const arg of argv) {
    if(arg==='--no-ready-card-art'){if(readyCardArt===false)throw Error('Duplicate ready art disable');readyCardArt=false;continue;}
    if(arg.startsWith('--native-card-art-count=')) {
      if(count!==undefined)throw new Error('Duplicate native art count');
      count=arg.slice('--native-card-art-count='.length);if(!['0','1','5','10'].includes(count))throw new Error('Native art count must be 0/1/5/10');
    } else if(arg.startsWith('--native-card-art-registry=')) {
      if(registry!==undefined)throw new Error('Duplicate native art registry');
      registry=arg.slice('--native-card-art-registry='.length);if(!registry)throw new Error('Missing native art registry');
    } else if(arg.startsWith('--native-card-art-host=')) hosts.push(arg.slice('--native-card-art-host='.length));
    else if(arg.startsWith('--native-card-art-'))throw new Error('Unknown native art option; use --option=value');
    else args.push(arg);
  }
  if(count!==undefined&&hosts.length)throw new Error('Choose native art count OR explicit hosts');
  if(count==='0')return {args,nativeCardArt:undefined,...(count==='0'||readyCardArt===false?{readyCardArt:false}:{})};
  if(count===undefined&&!hosts.length) {
    if(registry!==undefined)throw new Error('Native art registry requires explicit hosts/count');
    return {args,nativeCardArt:undefined,...(count==='0'||readyCardArt===false?{readyCardArt:false}:{})};
  }
  if(!registry)throw new Error('Native art candidate requires a registry');
  return {args,...(readyCardArt===false?{readyCardArt:false}:{}),nativeCardArt:{registry,hosts:hosts.length?hosts:Array.from({length:Number(count)},(_,i)=>`battlePanel/card${i+1}`)}};
}

export function validateNativeCardArt(registry) {
  if (registry?.schemaVersion !== 2 || registry.editorCommit !== editorCommit || !same(registry.canvas,[144,64])) throw new Error('Invalid native art registry');
  const assets = Object.entries(registry.assets ?? {});
  if (!assets.length || assets.length > 3) throw new Error('Native art requires one to three reviewed candidate assets');
  let capacity = 0;
  for (const [id, asset] of assets) {
    if (!['armaments','cleave','heavy_blade'].includes(id) || asset.cardId !== id || !/^[a-f0-9]{64}$/.test(asset.luaSha256 ?? '')
      || !/^[a-f0-9]{64}$/.test(asset.jsonSha256 ?? '')) throw new Error('Invalid native art identity/hash');
    if (!Array.isArray(asset.slots) || !asset.slots.length || asset.slots.length > 2657) throw new Error('Native art exceeds the explicit two-sample capacity');
    for (const slot of asset.slots) {
      if (!same(Object.keys(slot).sort(),['anchorMax','anchorMin','colour','image','imageType','pivot','position','rotation','scale','size'].sort())) throw new Error('Unexpected native art slot field');
      if (![100001,100002,100003,106056,106057].includes(slot.image) || !['basic','stretch'].includes(slot.imageType)) throw new Error('Unsupported native art image/type');
      if (!vector(slot.position,2) || !vector(slot.size,2) || slot.size.some(n=>n<=0) || !vector(slot.rotation,3)
        || !same(slot.scale,[1,1]) || !['pivot','anchorMin','anchorMax'].every(k=>same(slot[k],[.5,.5]))
        || !vector(slot.colour,4) || slot.colour.some(n=>!Number.isInteger(n)||n<0||n>255)) throw new Error('Invalid native art slot geometry/RGBA');
    }
    capacity = Math.max(capacity,asset.slots.length);
  }
  return capacity;
}

export function nativeArtPool(capacity) {
  const children=[];
  for(let i=0;i<capacity;i++) {
    const [group,name]=nativeArtSlotPath(i);
    if(i%60===0)children.push({name:group,kind:'container',position:[0,0],size:[144,64],children:[]});
    children.at(-1).children.push({name,kind:'image',position:[0,0],size:[1,1],image:100001,colour:'#FFFFFF',opacity:0,visible:false});
  }
  return {name:'artSamples',kind:'container',position:[0,40],size:[144,64],visible:false,children};
}

export function prepareNativeCardArt(options,{root}={}) {
  if (!options) return null;
  const registryPath=typeof options.registry==='string'?(root?inputRecord(options.registry,root).path:options.registry):null;
  const source = registryPath ? readFileSync(registryPath) : null;
  const registry = source ? JSON.parse(source) : structuredClone(options.registry);
  const capacity = validateNativeCardArt(registry), hosts = options.hosts;
  const inputPaths=[];
  if(source) {
    if(!Array.isArray(registry.sourceInputs)||registry.sourceInputs.length!==Object.keys(registry.assets).length*2)throw new Error('Native art file registry requires original source inputs');
    const seen=new Set();
    for(const entry of registry.sourceInputs) {
      const key=entry.cardId+'/'+entry.kind;
      if(seen.has(key)||!['lua','json'].includes(entry.kind)||!registry.assets[entry.cardId]||typeof entry.path!=='string'
        || entry.sha256!==registry.assets[entry.cardId][entry.kind+'Sha256'])throw new Error('Invalid native art source provenance');
      const path=root?inputRecord(entry.path,root).path:entry.path;
      if(createHash('sha256').update(readFileSync(path)).digest('hex')!==entry.sha256)throw new Error('Native art original source hash mismatch');
      seen.add(key);inputPaths.push(path);
    }
    inputPaths.push(registryPath);
  }
  if (!Array.isArray(hosts) || !hosts.length || hosts.length > 10 || new Set(hosts).size !== hosts.length
    || hosts.some(p=>typeof p!=='string' || !/^(battlePanel\/card(?:[1-9]|10)|nodePanel\/(shopView\/card[1-7]|pickerView\/(card[1-6]|before|after|target)))$/.test(p))) {
    throw new Error('Native art candidate requires 1–10 explicit real static hosts; deck templates are unbounded');
  }
  return {registry,capacity,hosts:[...hosts],inputPaths,
    registrySha256:createHash('sha256').update(source??JSON.stringify(registry)).digest('hex')};
}

export function attachNativeCardArt(tree,candidate,{battleOnly=false}={}) {
  const wanted = candidate.hosts.filter(p=>!battleOnly||p.startsWith('battlePanel/'));
  const found=new Set();
  function visit(node,path=[]) {
    const next=[...path,node.name],children=node.children??node.controls??[];
    const host=wanted.find(p=>next.slice(-p.split('/').length).join('/')===p
      || battleOnly && p.startsWith('battlePanel/') && next.at(-1)===p.split('/')[1] && next.at(-2)==='stage');
    if(host) {
      if(found.has(host) || !children.some(c=>c.name==='artPlate') || children.some(c=>c.name==='artSamples')) throw new Error('Ambiguous native art host');
      // Insert after the legacy art/icon layer, before type trims/overlays.
      // This also preserves PR256's artWell and typeEdge/typeTag layering.
      const plate=children.find(c=>c.name==='artPlate'),index=children.findLastIndex(c=>c.name==='art'||c.name.startsWith('art_'))+1;
      if(!same(plate.size,[144,64]) || !same(plate.position,[0,40]) || index===0)throw new Error('Native art host aperture changed');
      children.splice(index,0,nativeArtPool(candidate.capacity));found.add(host);
    }
    for(const child of children)if(child.name!=='artSamples')visit(child,next);
  }
  visit(tree);
  if(found.size!==wanted.length)throw new Error('Missing native art candidate host');
}

export function bindNativeArtPresentation(cards,candidate) {
  for(const [id,asset] of Object.entries(candidate.registry.assets)) {
    if(!cards[id])throw new Error('Missing native art card presentation');
    cards[id].nativeArt={...structuredClone(asset),capacity:candidate.capacity,
      slots:asset.slots.map((slot,i)=>({...structuredClone(slot),path:nativeArtSlotPath(i)}))};
  }
}

export function nativeArtReceipt(candidate) {
  const controlsPerPool=candidate.capacity+Math.ceil(candidate.capacity/60)+1;
  return {schemaVersion:1,registrySha256:candidate.registrySha256,hosts:candidate.hosts,
    sources:Object.fromEntries(Object.entries(candidate.registry.assets).map(([id,a])=>[id,{luaSha256:a.luaSha256,jsonSha256:a.jsonSha256,images:a.slots.length}])),
    capacity:candidate.capacity,controlsPerPool,staticPools:candidate.hosts.length,
    staticAddedControls:controlsPerPool*candidate.hosts.length,deckTemplateEnabled:false,
    officialImport:'not_run',PC:'not_run',physicalAndroid:'not_run',performance:'not_measured'};
}

// Candidate-only provenance, separate from the ordinary source payload digest.
// These records bind actual art inputs AND the generated files consumed by MCP.
export function nativeCardArtBuildReceipt(candidate,{root,directory}) {
  const expected=nativeArtReceipt(candidate);
  const generated=JSON.parse(readFileSync(join(directory,'native-card-art-receipt.json'),'utf8'));
  if(!same(generated,expected))throw new Error('Generated native art receipt differs from requested candidate');
  const layout=JSON.parse(readFileSync(join(directory,'game-ui.json'),'utf8'));
  const pools=[];
  function visit(node,path=[]) {
    const next=[...path,node.name];
    if(node.name==='artSamples')pools.push({path:path.join('/'),node});
    for(const child of node.children??node.controls??[])visit(child,next);
  }
  visit(layout);
  if(pools.length!==candidate.hosts.length || candidate.hosts.some(host=>
    pools.filter(pool=>pool.path.endsWith('/'+host) && same(pool.node,nativeArtPool(candidate.capacity))).length!==1))
    throw new Error('Generated native art layout does not consume the selected pools');
  const templates=JSON.parse(readFileSync(join(directory,'game-ui-templates.json'),'utf8'));
  pools.length=0;templates.forEach(template=>visit(template));
  if(pools.length)throw new Error('Native art deck templates must stay disabled');
  const presentation=readFileSync(join(directory,'abyss_presentation.lua'),'utf8');
  const cards=Object.fromEntries(Object.keys(candidate.registry.assets).map(id=>[id,{}]));
  bindNativeArtPresentation(cards,candidate);
  // Ordinary build-ui is also run in the dependency-free presentation job.
  // Load the locked parser only when native art consumption must be verified.
  const luaparse=createRequire(import.meta.url)('luaparse');
  const chunk=luaparse.parse(presentation,{luaVersion:'5.3',ranges:true,encodingMode:'pseudo-latin1'});
  const result=chunk.body.length===1&&chunk.body[0];
  const table=result?.type==='ReturnStatement'&&result.arguments.length===1&&result.arguments[0];
  if(table?.type!=='TableConstructorExpression')throw new Error('Generated presentation does not consume a literal native art table');
  // toLua generates canonical bracket keys. Reject aliases/bare keys and any
  // duplicates rather than overlooking Lua's last-key-wins table semantics.
  for(const current of [table,...table.fields.map(row=>row.value)]) {
    const keys=new Set();
    if(current.type!=='TableConstructorExpression')throw new Error('Generated presentation does not consume canonical card tables');
    for(const row of current.fields) {
      if(row.type!=='TableKey'||row.key.type!=='StringLiteral'||row.key.raw!==toLua(row.key.value)||keys.has(row.key.value))
        throw new Error('Generated presentation does not consume unique canonical card fields');
      keys.add(row.key.value);
    }
  }
  const field=(table,key)=>table.fields.filter(row=>row.key.value===key);
  for(const [id,card] of Object.entries(cards)) {
    const entries=field(table,id),native=entries.length===1?field(entries[0].value,'nativeArt'):[];
    if(native.length!==1||presentation.slice(...native[0].value.range)!==toLua(card.nativeArt))
      throw new Error('Generated presentation does not consume native art slots for '+id);
  }
  if(table.fields.filter(row=>field(row.value,'nativeArt').length).length!==Object.keys(cards).length)
    throw new Error('Generated presentation consumes undeclared native art');
  const inputs=candidate.inputPaths.map(path=>fileRecord(path,root));
  const outputs=['game-ui.json','game-ui-templates.json','abyss_presentation.lua','native-card-art-receipt.json']
    .map(name=>fileRecord(join(directory,name),root));
  return {...expected,registry:inputs.at(-1),inputs,inputDigest:sha256(JSON.stringify(inputs)),outputs};
}

export function verifyNativeCardArtReceipt(receipt,{root=process.cwd()}={}) {
  if(receipt===undefined)return;
  if(!receipt || !Array.isArray(receipt.inputs) || !Array.isArray(receipt.outputs)
    || receipt.inputs.length<3 || receipt.outputs.length!==4 || !receipt.registry?.path)
    throw new Error('Incomplete native art candidate provenance');
  for(const record of [...receipt.inputs,...receipt.outputs]) {
    const actual=fileRecord(record.path,root);
    if(!same(actual,record))throw new Error('Native art input/output changed since candidate build');
  }
  const candidate=prepareNativeCardArt({registry:receipt.registry.path,hosts:receipt.hosts},{root});
  const expected=nativeCardArtBuildReceipt(candidate,{root,directory:dirname(receipt.outputs[0].path)});
  if(!same(receipt,expected))throw new Error('Native art candidate provenance or generated consumption differs');
}
