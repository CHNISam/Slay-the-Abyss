// Candidate assembly only. Geometry is read by the pinned Image Editor parser,
// never fitted/exported here. The ordinary card component remains unchanged.
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const editorCommit = '103025f9095d8089e3f9bf097f4d0c5fe039d546';
const vector = (x, n) => Array.isArray(x) && x.length === n && x.every(Number.isFinite);
const same = (a,b) => JSON.stringify(a) === JSON.stringify(b);
export const nativeArtSlotPath = index => [`group${String(Math.floor(index/60)).padStart(3,'0')}`, `shape${String(index).padStart(4,'0')}`];

export function nativeCardArtArgs(argv) {
  const args=[],hosts=[];let count,registry;
  for(const arg of argv) {
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
  if(count==='0')return {args,nativeCardArt:undefined};
  if(count===undefined&&!hosts.length) {
    if(registry!==undefined)throw new Error('Native art registry requires explicit hosts/count');
    return {args,nativeCardArt:undefined};
  }
  if(!registry)throw new Error('Native art candidate requires a registry');
  return {args,nativeCardArt:{registry,hosts:hosts.length?hosts:Array.from({length:Number(count)},(_,i)=>`battlePanel/card${i+1}`)}};
}

export function validateNativeCardArt(registry) {
  if (registry?.schemaVersion !== 2 || registry.editorCommit !== editorCommit || !same(registry.canvas,[144,64])) throw new Error('Invalid native art registry');
  const assets = Object.entries(registry.assets ?? {});
  if (!assets.length || assets.length > 2) throw new Error('Native art requires one or two candidate assets');
  let capacity = 0;
  for (const [id, asset] of assets) {
    if (!['cleave','heavy_blade'].includes(id) || asset.cardId !== id || !/^[a-f0-9]{64}$/.test(asset.luaSha256 ?? '')
      || !/^[a-f0-9]{64}$/.test(asset.jsonSha256 ?? '')) throw new Error('Invalid native art identity/hash');
    if (!Array.isArray(asset.slots) || !asset.slots.length || asset.slots.length > 2657) throw new Error('Native art exceeds the explicit two-sample capacity');
    for (const slot of asset.slots) {
      if (!same(Object.keys(slot).sort(),['anchorMax','anchorMin','colour','image','imageType','pivot','position','rotation','scale','size'].sort())) throw new Error('Unexpected native art slot field');
      if (![100001,100003,106056,106057].includes(slot.image) || !['basic','stretch'].includes(slot.imageType)) throw new Error('Unsupported native art image/type');
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

export function prepareNativeCardArt(options) {
  if (!options) return null;
  const source = typeof options.registry === 'string' ? readFileSync(options.registry) : null;
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
      if(createHash('sha256').update(readFileSync(entry.path)).digest('hex')!==entry.sha256)throw new Error('Native art original source hash mismatch');
      seen.add(key);inputPaths.push(entry.path);
    }
    inputPaths.push(options.registry);
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
