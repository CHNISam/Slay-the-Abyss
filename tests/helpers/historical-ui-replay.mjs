import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {formalEntryInverses} from '../support/formal-entry-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync('tests/fixtures/historical-ui-source-closure-20261028.json.gz');
const metadata={"sha256":"1d91d9ec71a1a9421e0b2a5d4c3d1a08f069c291484b191a080b3249ba270b7b","bytes":228252,"files":274};
assert.equal(bytes.length,metadata.bytes,'bounded frozen input payload');
assert.equal(hash(bytes),metadata.sha256,'complete frozen historical closure');
const closure=JSON.parse(gunzipSync(bytes));
assert.equal(closure.schemaVersion,1);
assert.equal(Object.keys(closure.files).length,metadata.files);
// This is an executable historical input closure, not a replacement current-UI golden.
// Existing immutable sources/hunks are reused; unchanged dependencies require exact SHA.
// Current real UI is exercised separately with semantic and strict native-field gates.
assert.equal(closure.base,'e46bd5dd7205d29a4252d73b8623df921bbdab78');
assert.deepEqual(closure.expected,{count:81392,hash:1836812524});
assert.equal(hash(readFileSync(closure.formalBinding.path)),closure.formalBinding.sha256,'original formal hunks retained');
const archives=Object.fromEntries(Object.entries(closure.archives).map(([name,binding])=>{
 const b=readFileSync(binding.path);assert.equal(hash(b),binding.sha256,'original '+name+' archive retained');
 return [name,JSON.parse(gunzipSync(b))];
}));
const normalize=s=>s.replaceAll('\r\n','\n');
function source(binding){
 let result;
 if(binding.kind==='source')result=binding.source;
 else if(binding.kind==='current-exact'||binding.kind==='frozen-file')result=normalize(readFileSync(binding.path,'utf8'));
 else if(binding.kind==='archive')result=archives[binding.archive].beforeSources[binding.path];
 else if(binding.kind==='formal'){
  const b=formalEntryInverses[binding.path],lines=source(binding.before).split('\n');
  assert.equal(hash(lines.join('\n')),b.beforeSha256);
  for(const h of b.hunks){assert.deepEqual(lines.slice(h.at,h.at+h.before.length),h.before);lines.splice(h.at,h.before.length,...h.after);}
  result=lines.join('\n');assert.equal(hash(result),b.afterSha256);
 }else assert.fail('unknown historical source kind');
 assert.equal(hash(result),binding.sha256,'unreviewed historical dependency drift');return result;
}
export function historicalUiSources(){return Object.fromEntries(Object.entries(closure.files).map(([path,b])=>[path,source(b)]));}
export function validateHistoricalUiSources(files){
 assert.deepEqual(Object.keys(files).sort(),Object.keys(closure.files).sort(),'exact historical source closure');
 for(const [path,b]of Object.entries(closure.files)){
  assert(!path.startsWith('/')&&!path.split('/').includes('..'));
  assert.equal(hash(files[path]),b.sha256,'unreviewed historical source drift: '+path);
 }
}
export function withHistoricalUiReplay(action){
 const files=historicalUiSources();validateHistoricalUiSources(files);
 mkdirSync('build',{recursive:true});const directory=mkdtempSync(resolve('build/historical-ui-'));
 try{for(const [path,s]of Object.entries(files)){mkdirSync(dirname(join(directory,path)),{recursive:true});writeFileSync(join(directory,path),s);}return action(directory);}
 finally{rmSync(directory,{recursive:true,force:true});}
}
export function historicalUiIdentity(path,current){
 if(current===null||!closure.liveIdentities[path]||hash(normalize(current))!==closure.liveIdentities[path])return current;
 return source(closure.files[path]);
}
