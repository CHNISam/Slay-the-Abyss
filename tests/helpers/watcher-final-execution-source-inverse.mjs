// A single-owner extraction epoch. Never update the older 391-source proof.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
export const watcherExecutionPath='src/lua/abyss_watcher_final_cards.lua';
export const watcherExecutionBefore=normalize(readFileSync(new URL('./watcher-final-execution-before.lua',import.meta.url),'utf8'));
assert.equal(hash(watcherExecutionBefore),'343888e746943d3c97608033ac65f52fe02a390c0dba8283b23f18c4a2118018');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(watcherExecutionBefore)+'\0'+watcherExecutionBefore).digest('hex'),'4b318364ccf3786bdaf0204ead541535d6d3194b');
const after='ec2ef8388b777de5dccfce1df602ac0981dfd112bbd8b63d2e188d345f0c03cd';
const matches=(path,source)=>path===watcherExecutionPath&&typeof source==='string'&&hash(normalize(source))===after;
const live=path=>readFileSync(path,'utf8'),rawReaders=new WeakMap();
export function preWatcherExecutionSource(path,source,{readSource=live}={}){
 if(!matches(path,source))return source;
 assert.equal(typeof readSource,'function','Watcher execution linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 let current;try{current=readSource(path);}catch(error){assert.fail('Watcher execution linked owner missing: '+String(error?.message??error));}
 assert(matches(path,current),'Watcher execution linked owner identity');
 return watcherExecutionBefore;
}
export function watcherExecutionReader(readSource=live){
 assert.equal(typeof readSource,'function','Watcher execution linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preWatcherExecutionSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);return reader;
}
