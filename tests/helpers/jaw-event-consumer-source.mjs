import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
export const jawEventConsumerProof=JSON.parse(readFileSync(new URL('../fixtures/jaw-event-consumer-source.json',import.meta.url),'utf8'));
export function preJawEventConsumerSource(source){
 const text=normalize(source),proof=jawEventConsumerProof;
 if(hash(text)===proof.beforeSha256)return text;
 assert.equal(hash(text),proof.afterSha256,'exact current Jaw Worm fixture');
 let old=text;
 for(const insertion of proof.insertions){assert.equal(old.split(insertion).length,2,'one exact consumer insertion');old=old.replace(insertion,'');}
 assert.equal(hash(old),proof.beforeSha256,'exact original partitioned Jaw Worm fixture');
 return old;
}
