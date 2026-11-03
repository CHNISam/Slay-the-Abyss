import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
const path='src/lua/abyss_map_ui.lua';
function injected(source,fixture){
 const entry=join(tmpdir(),`map-size-${randomUUID()}.lua`);
 writeFileSync(entry,`package.preload.abyss_map_ui=assert(load(${luaString(source)},'@map-size-test'))\ndofile(${luaString(fixture)})`);
 try{return runLua(entry,{maxBuffer:4*1024*1024});}finally{unlinkSync(entry);}
}
const current=`    local pending={};roomSizes[control]=pending
    local ok,result=pcall(control.SetSizeDelta,control,size,size)
    local current=roomSizes[control]==pending
    roomSizes[control]=nil
    if not ok then error(result,0)end
    -- Nested setters can complete in either order; retry an overlapping write.
    if result~=false and current then roomSizes[control]={owner=fx.sizeOwner,size=size} end`;
const original=`    roomSizes[control]=nil
    if control:SetSizeDelta(size,size)~=false then roomSizes[control]={owner=fx.sizeOwner,size=size} end`;
function baseline(){
 const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
 assert.equal(source.split(current).length-1,1,'one exact changed size writer');
 return source.replace(current,original);
}
test('map size setters preserve nested write ownership and errors',()=>{
 const result=runLua('tests/lua/map_size_reentry.lua');assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/MAP_SIZE_REENTRY_PASS 24 overlap cases/);
});
test('original map size writer reproduces wrong geometry after reentry',()=>{
 const result=injected(baseline(),'tests/lua/map_size_reentry.lua');
 assert.notEqual(result.status,0);assert.match(result.stdout+result.stderr,/nested map write after success wrong icon size/);
});
test('373 ordered real MapUI frames match the original size writer',()=>{
 const before=injected(baseline(),'tests/lua/support/map_size_trace.lua');
 const after=runLua('tests/lua/support/map_size_trace.lua',{maxBuffer:4*1024*1024});
 for(const result of [before,after])assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(after.stdout,/MAP_SIZE_TRACE_PASS 373/);
 assert.equal(after.stdout,before.stdout,'ordered MapUI state/visual trace changed');
});
for(const [name,anchor,replacement,failure]of [
 ['overlap cached','result~=false and current','result~=false',/nested map write after success wrong icon size|overlapping map size promise cached/],
 ['rejected write cached','result~=false and current','current',/failed size promise survived/],
 ['nested promise retained after throw',/local current=roomSizes\[control\]==pending\r?\n    roomSizes\[control\]=nil\r?\n    if not ok then error\(result,0\)end/g,'if not ok then error(result,0)end\n    local current=roomSizes[control]==pending\n    roomSizes[control]=nil',/overlapping map size promise cached after throw|nested map write after throw wrong/],
])for(const newline of ['\n','\r\n'])test(`map size negative control ${newline.length===1?'LF':'CRLF'}: ${name}`,()=>{
 const original=readFileSync(path,'utf8');const source=original.replace(/\r?\n/g,newline);
 const count=typeof anchor==='string'?source.split(anchor).length-1:[...source.matchAll(anchor)].length;
 assert.equal(count,1,'one exact cache boundary');
 const result=injected(source.replace(anchor,replacement),'tests/lua/map_size_reentry.lua');
 assert.notEqual(result.status,0,'mutant survived');assert.match(result.stdout+result.stderr,failure);
 assert.equal(readFileSync(path,'utf8'),original);
});
