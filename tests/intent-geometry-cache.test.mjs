import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';

test('intent geometry preserves ownership, failed writes, reentry and native lifetime',()=>{
 const result=runLua('tests/lua/intent_geometry_cache.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/INTENT_GEOMETRY_CACHE_PASS/);
});
test('real Host retains intent geometry without changing animation or the run graph',()=>{
 const result=runLua('tests/lua/intent_geometry_host.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/INTENT_GEOMETRY_HOST_PASS/);
});
const mutations=[
 ['ignored owner','painted.owner==owner and ','',/shared handle ownership was ignored/],
 ['missing alive guard',/(painted\.(?:height|y)==(?:height|y)) and control.alive~=false/g,'$1',/dead native guard was bypassed/],
 ['cached rejected setter','result~=false and current','current',/failed geometry promise survived/],
 ['cached overlapping write','result~=false and current','result~=false',/overlapping native write was incorrectly cached/],
 ['retained nested promise after throw',
  /local current=(intentSizes|intentPositions)\[control\]==pending\r?\n    \1\[control\]=nil\r?\n    if not ok then error\(result,0\) end/g,
  'if not ok then error(result,0) end\n    local current=$1[control]==pending\n    $1[control]=nil',
  /failed outer write retained a nested promise/],
];
// Exercise both checkout formats without rewriting the production file on disk.
for(const [name,anchor,replacement,failure] of mutations)for(const [format,newline] of [['LF','\n'],['CRLF','\r\n']])test(`intent geometry negative control (${format}): ${name}`,()=>{
 const path='src/lua/abyss_battle_render_actors.lua';const original=readFileSync(path,'utf8');
 const source=original.replace(/\r?\n/g,newline);
 const matches=typeof anchor==='string'?source.split(anchor).length-1:[...source.matchAll(anchor)].length;
 assert.equal(matches,2,'exactly one boundary for each native setter');
 const mutant=source.replaceAll(anchor,replacement);
 const entry=join(tmpdir(),`intent-geometry-mutant-${randomUUID()}.lua`);
 writeFileSync(entry,`package.preload['abyss_battle_render_actors']=assert(load(${luaString(mutant)},'@intent-geometry-mutant'))\ndofile('tests/lua/intent_geometry_cache.lua')\n`);
 try{
  const result=runLua(entry);assert.notEqual(result.status,0,'semantic regression must fail');
  assert.match(result.stdout+result.stderr,failure);
 }finally{unlinkSync(entry);}
 assert.equal(readFileSync(path,'utf8'),original,'negative control changed production source');
});
