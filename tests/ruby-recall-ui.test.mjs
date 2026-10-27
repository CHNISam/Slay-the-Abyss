import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const partitions=JSON.parse(read('tests/fixtures/ruby-recall-ui-partitions.json'));

test('actual generated NodeUI uses the existing last footer without adding camp controls',()=>{
  const root=nodeLayout().controls[0], camp=root.children.find(control=>control.name==='campView');
  assert.deepEqual(camp.children.map(control=>control.name),['medallion','rest','forge']);
  const footer=root.children.find(control=>control.name==='confirm');
  assert.ok(root.children.indexOf(footer)>root.children.indexOf(camp));
  for(const tile of camp.children.filter(control=>['rest','forge'].includes(control.name)))
    assert.ok(footer.position[1]+footer.size[1]/2<tile.position[1]-tile.size[1]/2);
  const source=readFileSync('src/lua/abyss_node_ui.lua','utf8');
  assert.match(source,/confirmLabel, confirmOk = "Recall", true/);
  assert.match(source,/commit\("recall", recallSource/);
});

test('Recall UI partitions restore the exact Git base body and cover every original group once',()=>{
  assert.equal(partitions.base,'4c24aa0e526ab0f1997101c4bf49ba7aa1fdccc1');
  assert.equal(partitions.originalGitBlob,'4179d11f1aceee9862420221e607cf9adc20eb00');
  assert.equal(partitions.originalSha256LF,'794b57516fb4f4671fdc35e1cd4784351921fef2f2c1c4184537814d26934b09');
  assert.equal(partitions.entry,'tests/lua/ruby_recall_ui.lua');
  assert.equal(partitions.total,14);assert.equal(partitions.timeoutMilliseconds,30000);
  assert.equal(partitions.prefix,'local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 7\nlocal sliceRegistered,sliceExecuted=0,0\n');
  assert.equal(partitions.before,"local function test(name,fn)fn();count=count+1;print('ok ruby recall UI '..count..' - '..name)end");
  assert.equal(partitions.after,"local function test(name,fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    fn();sliceExecuted=sliceExecuted+1;count=count+1\n    print('ok ruby recall UI '..count..' - '..name)\n    print('RUBY_RECALL_UI_CASE '..sliceRegistered)\nend");
  assert.equal(partitions.footer,"\nassert(sliceRegistered==14,'all fourteen original Recall UI groups must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'every selected Recall UI group must execute')\nprint('RUBY_RECALL_UI_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n");
  assert.deepEqual(partitions.slices,[
    {path:'tests/lua/ruby_recall_ui.lua',first:1,last:7},
    {path:'tests/lua/ruby_recall_ui_slice_2.lua',first:8,last:12},
    {path:'tests/lua/ruby_recall_ui_slice_3.lua',first:13,last:14},
  ]);
  let original=read(partitions.entry);
  assert(original.startsWith(partitions.prefix));assert(original.endsWith(partitions.footer));
  original=original.slice(partitions.prefix.length,-partitions.footer.length);
  assert.equal(original.split(partitions.after).length,2);
  original=original.replace(partitions.after,partitions.before);
  assert.equal(createHash('sha256').update(original).digest('hex'),partitions.originalSha256LF);
  const bytes=Buffer.from(original);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),partitions.originalGitBlob);
  const covered=[];
  for(const [index,part]of partitions.slices.entries()){
    if(index)assert.equal(read(part.path),`assert(loadfile('${partitions.entry}'))(${part.first},${part.last})\n`);
    for(let group=part.first;group<=part.last;group++)covered.push(group);
  }
  assert.deepEqual(covered,Array.from({length:14},(_,index)=>index+1));
});

test('real NodeUI pointer ownership and public Recall command preserve complete run/map/RNG parity',()=>{
  const executed=[];
  for(const part of partitions.slices){
    const started=Date.now(),result=runLua(part.path,{timeout:partitions.timeoutMilliseconds});
    assert.equal(result.status,0,result.stderr+result.stdout);
    const expected=Array.from({length:part.last-part.first+1},(_,index)=>part.first+index);
    const actual=[...result.stdout.matchAll(/^RUBY_RECALL_UI_CASE (\d+)$/gm)].map(match=>Number(match[1]));
    assert.deepEqual(actual,expected,part.path);
    assert.match(result.stdout,new RegExp(`^RUBY_RECALL_UI_PASS ${expected.length}$`,'m'));
    assert.match(result.stdout,new RegExp(`^RUBY_RECALL_UI_SLICE ${part.first} ${part.last} ${expected.length}$`,'m'));
    executed.push(...actual);
    console.log(`Recall UI ${part.first}-${part.last}: ${Date.now()-started} ms`);
  }
  assert.deepEqual(executed,Array.from({length:14},(_,index)=>index+1));
});
