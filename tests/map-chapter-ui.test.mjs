import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

test('chapter-local map geometry, real same-table transitions and stale gestures preserve core state', () => {
  buildLuaData();
  buildUI();
  const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
  const parts=JSON.parse(read('tests/fixtures/map-chapter-partitions.json'));
  const prefix="local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 8\nlocal sliceRegistered,sliceExecuted=0,0\n";
  const before="local function test(name, fn) fn(); passed=passed+1; print('PASS '..name) end";
  const after="local function test(name, fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    fn();sliceExecuted=sliceExecuted+1;passed=passed+1\n    print('PASS '..name)\n    print('MAP_CHAPTER_CASE '..sliceRegistered)\nend";
  const footer="\nassert(sliceRegistered==38,'all thirty-eight original map groups must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'every selected map group must execute')\nprint('MAP_CHAPTER_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n";
  assert.equal(parts.base,'54c29a78fcc831f20c15b062c173773158fdf58b');
  assert.equal(parts.originalGitBlob,'895747f9158c6c14e1158bfc8d6372b6da122ffa');
  assert.equal(parts.originalSha256LF,'20cb975546649c960292ef460c50494dbc7cdbd44abda39920d657890ece6d8a');
  assert.equal(parts.entry,'tests/lua/map_chapters.lua');assert.equal(parts.total,38);
  assert.equal(parts.timeoutMilliseconds,30000);
  assert.equal(parts.prefix,prefix);assert.equal(parts.before,before);assert.equal(parts.after,after);assert.equal(parts.footer,footer);
  assert.deepEqual(parts.slices,[
    {path:'tests/lua/map_chapters.lua',first:1,last:8},
    {path:'tests/lua/map_chapters_slice_2.lua',first:9,last:16},
    {path:'tests/lua/map_chapters_slice_3.lua',first:17,last:29},
    {path:'tests/lua/map_chapters_slice_4.lua',first:30,last:38},
  ]);
  // Reverse only the exact registration/selection instrumentation. Every
  // original loop, input matrix, helper and assertion remains byte-identical.
  let original=read(parts.entry);assert(original.startsWith(prefix));assert(original.endsWith(footer));
  original=original.slice(prefix.length,-footer.length);
  assert.equal(original.split(after).length,2);original=original.replace(after,before);
  // PR295 keeps offscreen slots untouched. Reverse only the relocated visual
  // icon assertion; the original 38 state/RNG/input cases remain byte-locked.
  const oldIcon="                assert(b.x==(node.lane-(Layout.lanes+1)/2)*Theme.layout.map.columnGap)\n                assert(b.y==Layout.firstY+(row-1)*Theme.layout.map.floorGap-ui.scroll)\n                assert(b:GetChild('icon').imageId==Theme.icon.node[node.type])\n                if b.visible then\n";
  const liveIcon="                if b.visible then\n                    -- Offscreen slots retain their last projection; the real\n                    -- renderer updates and exposes the current icon on entry.\n                    assert(b.x==(node.lane-(Layout.lanes+1)/2)*Theme.layout.map.columnGap)\n                    assert(b.y==Layout.firstY+(row-1)*Theme.layout.map.floorGap-ui.scroll)\n                    assert(b:GetChild('icon').imageId==Theme.icon.node[node.type])\n";
  assert.equal(original.split(liveIcon).length,2,'one reviewed viewport projection migration');
  original=original.replace(liveIcon,oldIcon);
  assert.equal(createHash('sha256').update(original).digest('hex'),parts.originalSha256LF);
  const bytes=Buffer.from(original);assert.equal(bytes.length,parts.originalBytesLF);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),parts.originalGitBlob);
  const covered=[],executed=[];
  for(const [index,part]of parts.slices.entries()){
    if(index)assert.equal(read(part.path),`assert(loadfile('${parts.entry}'))(${part.first},${part.last})\n`);
    const expected=Array.from({length:part.last-part.first+1},(_,n)=>part.first+n);
    covered.push(...expected);
    const started=Date.now(),result=runLua(part.path,{timeout:parts.timeoutMilliseconds});
    assert.equal(result.status,0,result.stderr+result.stdout);
    const actual=[...result.stdout.matchAll(/^MAP_CHAPTER_CASE (\d+)$/gm)].map(match=>Number(match[1]));
    assert.deepEqual(actual,expected,part.path);executed.push(...actual);
    assert.match(result.stdout,new RegExp(`^LUA_MAP_CHAPTERS_PASS ${expected.length}$`,'m'));
    assert.match(result.stdout,new RegExp(`^MAP_CHAPTER_SLICE ${part.first} ${part.last} ${expected.length}$`,'m'));
    console.log(`Map chapters ${part.first}-${part.last}: ${Date.now()-started} ms`);
  }
  const all=Array.from({length:38},(_,index)=>index+1);
  assert.deepEqual(covered,all);assert.deepEqual(executed,all);
});
