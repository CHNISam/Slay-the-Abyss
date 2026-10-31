import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';

const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const metadata=JSON.parse(read('tests/fixtures/card-detail-preview-partitions.json'));
const entry='tests/lua/card_detail_preview.lua';
const prefix='local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 3\nlocal registered=0\n';
const originalTest="local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end";
const selectedTest="local function test(name,fn)\n registered=registered+1\n if registered<sliceFirst or registered>sliceLast then return end\n fn();passed=passed+1;print('PASS '..name)\n print('CARD_DETAIL_PREVIEW_CASE '..registered)\nend";
const footer="assert(registered==11,'all original card detail groups must register')\nassert(passed==sliceLast-sliceFirst+1,'every selected card detail group must execute')\n";

function assertCoverage(slices) {
 const actual=slices.flatMap(part=>Array.from({length:part.last-part.first+1},(_,index)=>part.first+index));
 assert.deepEqual(actual,Array.from({length:11},(_,index)=>index+1));
}

test('card detail partitions restore the complete original Git bytes and discover all eleven groups',()=>{
 assert.equal(metadata.base,'96411b6c74349f25e3434509dd922e423b47c45f');
 assert.equal(metadata.originalSha256LF,'06cf6450738fd6744e9eadd8309b5108c906d966cd149206522147e12b3cb11c');
 assert.equal(metadata.originalGitBlob,'645e09522a9eb9069aa5d4d6bc764cd865466ead');
 assert.deepEqual(metadata.slices,[
  {path:entry,first:1,last:3},
  {path:'tests/lua/card_detail_preview_slice_2.lua',first:4,last:6},
  {path:'tests/lua/card_detail_preview_slice_3.lua',first:7,last:9},
  {path:'tests/lua/card_detail_preview_slice_4.lua',first:10,last:11},
 ]);
 let source=read(entry);
 assert.ok(source.startsWith(prefix));assert.ok(source.endsWith(footer));
 source=source.slice(prefix.length,-footer.length);
 assert.equal(source.split(selectedTest).length,2);
 source=source.replace(selectedTest,originalTest);
 assert.equal(createHash('sha256').update(source).digest('hex'),metadata.originalSha256LF);
 const bytes=Buffer.from(source);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),metadata.originalGitBlob);
 const files=readdirSync('tests/lua').filter(name=>/^card_detail_preview(?:_slice_\d+)?\.lua$/.test(name)).sort();
 assert.deepEqual(files,metadata.slices.map(part=>part.path.replace('tests/lua/','')).sort());
 for(const [index,part]of metadata.slices.entries())if(index)
  assert.equal(read(part.path),`assert(loadfile('${entry}'))(${part.first},${part.last})\n`);
 assertCoverage(metadata.slices);
});

test('card detail coverage rejects omitted and repeated original cases',()=>{
 for(const mutate of [slices=>slices.splice(1,1),slices=>{slices[1].first=5;},slices=>{slices[2].first=6;}]){
  const slices=structuredClone(metadata.slices);mutate(slices);assert.throws(()=>assertCoverage(slices));
 }
});
