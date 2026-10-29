import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
test('result gesture slices preserve all twenty original cases and their complete inputs',()=>{
  let source=read('tests/lua/game_ui_result_gestures.lua');
  const edits=[
    ['local first,last=...\nfirst,last=first or 1,last or 5\nlocal registered=0\n',''],
    ['    registered=registered+1\n    if registered<first or registered>last then return end\n',''],
    ["assert(registered==20 and total==last-first+1,'complete result gesture range')\n",''],
  ];
  for(const [after,before]of edits){
    assert.equal(source.split(after).length,2,'only the exact range harness is projected');
    source=source.replace(after,before);
  }
  assert.equal(createHash('sha256').update(source).digest('hex'),'b5bf2969f4bf854251f15c2402cad8a1dac207d9479f945e310ebee5fd4b4adf');
  const seen=[1,2,3,4,5];
  for(let i=2;i<=4;i++){
    const first=(i-1)*5+1,last=i*5;
    assert.equal(read(`tests/lua/game_ui_result_gestures_${i}.lua`),`assert(loadfile('tests/lua/game_ui_result_gestures.lua'))(${first},${last})\n`);
    for(let n=first;n<=last;n++)seen.push(n);
  }
  assert.deepEqual(seen,Array.from({length:20},(_,i)=>i+1));
});
