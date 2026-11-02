import test from 'node:test';import assert from 'node:assert/strict';import {existsSync,readFileSync} from 'node:fs';
test('probe emits real authoring controls with bounded children and inline exact Lua',()=>{
 assert(existsSync('sample.save.json'),'probe sample must be generated');
 const save=JSON.parse(readFileSync('sample.save.json'));const root=save.assets.server.root.children[0];let count=0;
 function visit(n){count++;assert(n.children.length<=60);n.children.forEach(visit)}visit(root);
 assert(count<=400);assert.equal(save.assets.scripts[0].source,readFileSync('probe.generated.lua','utf8'));
 assert(save.assets.scripts[0].source.includes('CURVE_PROBE_READY'));
 assert(root.children.some(n=>n.name==='probe0'));
});
