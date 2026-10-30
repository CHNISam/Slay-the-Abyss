import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('gesture budget slices jointly register and execute all eleven original groups once',()=>{
 const body=readFileSync('tests/lua/battle_ui_gestures.lua','utf8');
 const cases=[...body.matchAll(/^test\("([^"\n]+)"/gm)].map(match=>match[1]);
 assert.equal(cases.length,11);assert.equal(new Set(cases).size,11);
 assert.match(body,/first,last=first or 1,last or 6/);
 assert.match(body,/registered=registered\+1\s+if registered<first or registered>last then return end\s+executed=executed\+1/);
 assert.match(body,/assert\(registered==11 and executed==last-first\+1,'gesture partition coverage changed'\)/);
 assert.equal(readFileSync('tests/lua/battle_ui_gestures_slice_2.lua','utf8').trim(),
  "assert(loadfile('tests/lua/battle_ui_gestures.lua'))(7,11)");
 const union=[[1,6],[7,11]].flatMap(([first,last])=>cases.map((_,index)=>index+1).filter(index=>index>=first&&index<=last));
 assert.deepEqual(union,Array.from({length:11},(_,index)=>index+1));
});
