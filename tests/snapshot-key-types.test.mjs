import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {beforeSnapshotKeyTypes,keyTypesProof as proof} from './helpers/snapshot-key-types-inverse.mjs';

const hash=s=>createHash('sha256').update(s).digest('hex');
const read=()=>readFileSync('src/lua/abyss_snapshot.lua','utf8').replaceAll('\r\n','\n');
test('key-type cache is an exact local traversal increment over the complete captured graph',()=>{
 const source=read(),before=beforeSnapshotKeyTypes(source);
 assert.equal(proof.base,'b4ac63145689b9dd632db100eee49087f6182b39');
 assert.equal(hash(source),proof.afterSourceSha256);
 assert.equal(hash(before),proof.beforeSourceSha256);
 assert.equal(source.slice(source.indexOf('local function restore()')),before.slice(before.indexOf('local function restore()')),'restore, owner and release remain byte-identical and never close over key cache');
});
test('partial, additional and incorrect cache blocks cannot pass the old-source inverse',()=>{
 const source=read();
 const additional=source.replace('local keyTables={}','local keyTables={};keyTables[false]=true');
 assert.notEqual(hash(beforeSnapshotKeyTypes(additional)),proof.beforeSourceSha256,'additional statements remain visible to the original golden source hash');
 for(const mutant of [
  source.replace('keyTables[k]=tableKey','keyTables[k]=true'),
  source.replace('tableKey==nil','not tableKey'),
  source.replace('if tableKey and not saved[k] then',"if kind(k)=='table' and not saved[k] then"),
  source+'\n'+proof.changes[1].after,
 ])assert.throws(()=>beforeSnapshotKeyTypes(mutant),/exact unique snapshot key-type cache block/);
});
test('false keys, table-key cycles, independent captures and single-use owners retain semantics',()=>{
 const result=runLua('tests/lua/snapshot_key_types.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/SNAPSHOT_KEY_TYPES_PASS 1/);
});
