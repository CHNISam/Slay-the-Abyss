import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {prePhaseFourCardCountSource} from './helpers/phase-four-card-count-inverse.mjs';
import {withHistoricalBaseline} from './helpers/historical-baseline-inputs.mjs';
const read=p=>preFormalEntrySource(p,prePhaseFourCardCountSource(p,readFileSync(p,'utf8')));
const readCurrent=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const sha=s=>createHash('sha256').update(s).digest('hex');
// Current full-source class catalogs include both Bell and Necronomicurse.
const currentRenderVariants=[82,92,92,102].map(cards=>cards*2);
const suites=[
  {
    "name": "act3_transient",
    "total": 19,
    "defaultLast": 10,
    "ranges": [
      [
        1,
        10
      ],
      [
        11,
        17
      ],
      [
        18,
        19
      ]
    ],
    "needle": "local function test(name,fn)local ok,why=pcall(fn);",
    "insert": "registered=registered+1;if registered<first or registered>last then return end;",
    "originalFooter": "",
    "footer": "assert(registered==19 and count==last-first+1,'Transient slice coverage changed')\n",
    "hash": "690420d1e3e1fa83d133dd9e26468eab5efd172aa36958409d991ffb41b88601",
    "header": "local first,last=...\nfirst,last=first or 1,last or 10\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=19 and first<=last,'invalid original fixture slice')\nlocal registered=0\n"
  },
  {
    "name": "phase_four_presentation_render",
    "total": 4,
    "defaultLast": 1,
    "ranges": [
      [
        1,
        1
      ],
      [
        2,
        2
      ],
      [
        3,
        3
      ],
      [
        4,
        4
      ]
    ],
    "needle": "local function test(name,fn)fn();",
    "insert": "registered=registered+1;if registered<first or registered>last then return end;",
    "originalFooter": "eq(cases,4);eq(rendered,720)\n",
    "footer": "assert(registered==4,'class render discovery changed')\nlocal expected=0;for i=first,last do expected=expected+({160,180,180,200})[i]end\neq(cases,last-first+1);eq(rendered,expected)\n",
    "hash": "c78d9203acbf4ed07bac9c5f73fe00d9df7bb2d6f95fee18dcd570a1f47c6de9",
    "header": "local first,last=...\nfirst,last=first or 1,last or 1\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=4 and first<=last,'invalid original fixture slice')\nlocal registered=0\n"
  }
];
for(const s of suites)test('PR266 original body and complete raw discovery: '+s.name,()=>{
 const source=withHistoricalBaseline(()=>read('tests/lua/'+s.name+'.lua'));
 assert.ok(source.startsWith(s.header));assert.equal(source.split(s.insert).length,2);
 const original=source.replace(s.header,'').replace(s.insert,'').replace(s.footer,s.originalFooter);
 assert.equal(sha(original),s.hash,'every original assertion, loop, setup and seed must remain');
 assert.notEqual(sha(original.replace('assert(','assert(true or ')),s.hash,'weakened original assertion must be rejected');
 const current=readCurrent('tests/lua/'+s.name+'.lua');
 const currentFooter=s.name==='phase_four_presentation_render'
  ? `assert(registered==4,'class render discovery changed')\nlocal expected=0;for i=first,last do expected=expected+({${currentRenderVariants.join(',')}})[i]end\neq(cases,last-first+1);eq(rendered,expected)\n`
  :s.footer;
 for(const harness of [s.header,s.insert,currentFooter])assert.equal(current.split(harness).length,2,'current range and count gates remain executable exactly once');
 const files=s.ranges.map((r,i)=>s.name+(i?'_slice_'+(i+1):'')+'.lua');
 const found=readdirSync('tests/lua').filter(f=>f===s.name+'.lua'||f.startsWith(s.name+'_slice_'));
 assert.deepEqual(found.sort(),[...files].sort());
 assert.deepEqual(s.ranges.flatMap(([a,b])=>Array.from({length:b-a+1},(_,i)=>a+i)),Array.from({length:s.total},(_,i)=>i+1));
 for(let i=1;i<files.length;i++)assert.equal(readCurrent('tests/lua/'+files[i]),`assert(loadfile('tests/lua/${s.name}.lua'))(${s.ranges[i][0]},${s.ranges[i][1]})\n`);
});
test('PR266 keeps all four class matrices and the original per-process deadline',()=>{
 assert.deepEqual(suites[1].ranges,[[1,1],[2,2],[3,3],[4,4]]);
 assert.equal([160,180,180,200].reduce((a,b)=>a+b),720);
 assert.equal(currentRenderVariants.reduce((a,b)=>a+b),736,'current basic and upgrade variants include both admitted curses');
 assert.match(readCurrent('scripts/test-lua.mjs'),/timeout \?\?= normalizedScript\.endsWith\('tests\/lua\/encounter_coverage\.lua'\) \? 120000 : mapProperties \? 120000 : fixture \|\| composedHost \? 60000 : 30000;/);
});
