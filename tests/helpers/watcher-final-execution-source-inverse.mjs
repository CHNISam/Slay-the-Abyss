// This exact outer epoch preserves the original complete Watcher source.
// A successful inverse authenticates the caller's current owner on every call.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalize=s=>s.replaceAll('\r\n','\n');
export const watcherExecutionPath='src/lua/abyss_watcher_final_cards.lua';
export const watcherBefore=readFileSync(new URL('./watcher-final-execution-before.lua',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(watcherBefore),'343888e746943d3c97608033ac65f52fe02a390c0dba8283b23f18c4a2118018');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(watcherBefore)+'\0'+watcherBefore).digest('hex'),'4b318364ccf3786bdaf0204ead541535d6d3194b');
export const watcherExecutionAfterSha256='e4a2edb86d70500dc26174d7e0ea46a8879d7f88ba31fc34af839eaee7090224';
const matches=(path,s)=>path===watcherExecutionPath&&typeof s==='string'&&hash(normalize(s))===watcherExecutionAfterSha256;
const readLive=p=>readFileSync(p,'utf8'),rawReaders=new WeakMap();
export function preWatcherExecutionSource(path,source,{readSource=readLive}={}){
 if(!matches(path,source))return source;
 assert.equal(typeof readSource,'function','Watcher execution linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 let current;try{current=readSource(path);}catch(error){assert.fail('Watcher execution linked owner missing: '+String(error?.message??error));}
 assert(matches(path,current),'Watcher execution linked owner identity: '+path);
 return watcherBefore;
}
export function watcherExecutionReader(readSource=readLive){
 assert.equal(typeof readSource,'function','Watcher execution linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preWatcherExecutionSource(path,readSource(path),{readSource});rawReaders.set(reader,readSource);return reader;
}
