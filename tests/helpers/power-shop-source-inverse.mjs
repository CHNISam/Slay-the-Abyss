// One exact outer source epoch. Old archives remain immutable; linked owners are
// authenticated afresh on every recognized input, including a newly added leaf.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const archive=readFileSync(new URL('./power-shop-before-2c85.json.gz',import.meta.url));
assert.equal(hash(archive),'9a0e812b775133a4052eaba470bbc6a82eb4b447b5d7cb0f05e4c0bdbb98a52c');
const bytes=gunzipSync(archive);
assert.equal(hash(bytes),'eb41ac2b407423b2f0298f27f07d8f5bed349b9804f144b2b9d8de4ac0d05025');
export const powerShopBefore=JSON.parse(bytes);
assert.equal(powerShopBefore.revision,'2c85bc618f39a4706dbc108eca0ebe5797630081');
for(const entry of Object.values(powerShopBefore.files)){
 assert.equal(hash(entry.source),entry.sha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(entry.source)+'\0'+entry.source).digest('hex'),entry.gitBlob);
 Object.freeze(entry);
}
Object.freeze(powerShopBefore.files);Object.freeze(powerShopBefore);
export const powerShopAfter=Object.freeze({
 'config/architecture.json':'c50bf5e59d8a439ed602dd7dc7437bd8cc8a50f8e947b6e795be2372a8ecbe09',
 'src/lua/abyss_power_order.lua':'7ce009e48cc6eaa9a67fbb713388e01d36fb587249ceb9353efc2fd114ac1cea',
 'src/lua/abyss_turn_powers.lua':'1708245a6366e94ffabae72d9ff3af48c0d578815307a022dcc82f3e4e475ac8',
 'src/lua/abyss_turn_power_phases.lua':'7ac6b71d7f54c871cb992af2fe02dade51557b84446f03e54e59f14d3d92e93b',
 'src/lua/abyss_shop.lua':'562effbddab2b0e5e7e921eb9a94be12940fdabd7799c5d829fee524bd5ae5f6',
});
const tokens=s=>s.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,t=>t.startsWith('"')?t:'');
const matches=(path,s)=>typeof s==='string'&&Object.hasOwn(powerShopAfter,path)
 &&(hash(normalize(s))===powerShopAfter[path]||path==='config/architecture.json'
  &&hash(tokens(s))==='9bb48e6506acb930d95c4b1d3d8232a1908424b0162dadbb761f9d16da530b84');
const readLive=p=>readFileSync(p,'utf8');
export function prePowerShopSource(path,source,{readSource=readLive}={}){
 if(!matches(path,source))return source;
 assert.equal(typeof readSource,'function','Power/Shop linked reader must be a function');
 for(const linked of Object.keys(powerShopAfter)){
  let current;try{current=readSource(linked);}catch(error){assert.fail('Power/Shop linked owner missing: '+linked+': '+String(error?.message??error));}
  assert(matches(linked,current),'Power/Shop linked owner identity: '+linked);
 }
 return powerShopBefore.files[path]?.source??null;
}
