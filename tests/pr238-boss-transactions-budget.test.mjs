import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {createHash} from 'node:crypto';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
test('Boss transaction parts preserve all claims, refusal inputs, three seeds per tier and completed/unfinished cases',()=>{
 const f=JSON.parse(read('tests/fixtures/pr238-boss-transactions-budget.json'));assert.equal(f.timeoutMilliseconds,30000);assert.equal(f.base,'7593e8272b363f06d3cdaa62f29967756b3c1102');let s=read(f.entry);
 for(const e of [...f.edits].reverse()){assert.equal(s.split(e.after).length,2);s=s.replace(e.after,e.before);}
 assert.equal(createHash('sha256').update(s).digest('hex'),f.originalSha256LF);
 assert.deepEqual(f.parts.map(p=>p.part),[1,2,3,4,5,6,7]);for(const p of f.parts.slice(1))assert.equal(read('tests/lua/'+p.file),`assert(loadfile('${f.entry}'))(${p.part})\n`);
});
