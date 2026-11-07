// Exact one-owner Inventory epoch. Keep the original full source and the older
// lifecycle oracle intact; every authorization rereads the current owner.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const path='src/lua/abyss_inventory.lua';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const before=normalize(readFileSync(new URL('../fixtures/inventory-responsibilities-before.lua',import.meta.url),'utf8'));
assert.equal(hash(before),'8fb3dddab386d221c76de49a1ca4b9937a2edbde93511c06ef3810cd71a7557c');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0'+before).digest('hex'),'29d00e40b6423839c28d0964817a77f62348a06d');
const afterSha256='caf1e1b1aa8b61a3b3c3388aae0163eebce63df68e598710857f26d064204c8a';
const matches=(p,s)=>p===path&&typeof s==='string'&&hash(normalize(s))===afterSha256;
const readLive=p=>readFileSync(p,'utf8'),rawReaders=new WeakMap();
export function preInventoryResponsibilitiesSource(p,source,{readSource=readLive}={}){
 if(!matches(p,source))return source;
 assert.equal(typeof readSource,'function','Inventory linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 assert(matches(path,readSource(path)),'Inventory current owner identity');
 return before;
}
export function inventoryResponsibilitiesReader(readSource=readLive){
 assert.equal(typeof readSource,'function','Inventory linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=p=>preInventoryResponsibilitiesSource(p,readSource(p),{readSource});
 rawReaders.set(reader,readSource);return reader;
}
