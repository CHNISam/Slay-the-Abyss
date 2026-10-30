import test from 'node:test';
import {readHistoricalBaselineSource} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';

test('raw presentation slices preserve the entire four-class matrix and register every original case once',()=>{
 const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
 const p=JSON.parse(read('tests/fixtures/phase-three-presentation-partitions.json'));
 assert.equal(p.base,'0a773c1c8e736b564514c2c61adeaa6af541f023');
 assert.equal(p.originalGitBlob,'a7e057c70596a0fa8c37aad35ecbf4f151e600f9');
 assert.equal(p.originalSha256LF,'adfcc0b6c4af4bc64a57d47aaa1350a835020a85352312b095b7737ae08259af');
 assert.equal(p.total,12);assert.equal(p.timeoutMilliseconds,30000);
 assert.equal(p.entry,'tests/lua/phase_three_presentation.lua');
 const prefix="local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 2\nlocal sliceRegistered,sliceExecuted=0,0\n";
 const before="local function test(name,fn)fn();cases=cases+1;print('ok phase_three_presentation '..cases..' - '..name)end";
 const after="local function test(name,fn)\n sliceRegistered=sliceRegistered+1\n if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n fn();sliceExecuted=sliceExecuted+1;cases=cases+1\n print('ok phase_three_presentation '..cases..' - '..name)\n print('PHASE_THREE_CASE '..sliceRegistered)\nend";
 const footer="\nassert(sliceRegistered==12,'all twelve original presentation groups must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'every selected presentation group must execute')\nprint('PHASE_THREE_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted..' '..rendered)\n";
 assert.equal(p.prefix,prefix);assert.equal(p.before,before);assert.equal(p.after,after);assert.equal(p.footer,footer);
 assert.deepEqual(p.slices,[
  {path:'tests/lua/phase_three_presentation.lua',first:1,last:2},
  {path:'tests/lua/phase_three_presentation_slice_2.lua',first:3,last:4},
  {path:'tests/lua/phase_three_presentation_slice_3.lua',first:5,last:12},
 ]);
 // Reconstruct the original body from its original input, while discovery and wrappers below stay current.
 let original=readHistoricalBaselineSource(p.entry).replaceAll('\r\n','\n');assert(original.startsWith(prefix));assert(original.endsWith(footer));
 original=original.slice(prefix.length,-footer.length);
 assert.equal(original.split(after).length,2);original=original.replace(after,before);
 assert.equal(createHash('sha256').update(original).digest('hex'),p.originalSha256LF);
 const bytes=Buffer.from(original);assert.equal(bytes.length,p.originalBytesLF);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),p.originalGitBlob);
 const discovered=readdirSync('tests/lua').filter(file=>file.endsWith('.lua')).sort().map(file=>`tests/lua/${file}`);
 const covered=[];
 for(const [index,part]of p.slices.entries()){
  assert(discovered.includes(part.path),'the ordinary raw Lua runner must discover every slice');
  if(index)assert.equal(read(part.path),`assert(loadfile('${p.entry}'))(${part.first},${part.last})\n`);
  covered.push(...Array.from({length:part.last-part.first+1},(_,i)=>part.first+i));
 }
 assert.deepEqual(covered,Array.from({length:12},(_,i)=>i+1));
});
