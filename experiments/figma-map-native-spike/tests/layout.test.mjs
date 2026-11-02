import test from'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';
const save=JSON.parse(readFileSync('scene.save.json'));const root=save.assets.server.root.children[0];
const byName=new Map();let count=0;function walk(n){count++;byName.set(n.name,n);assert(n.children.length<=60,n.name);n.children.forEach(walk)}walk(root);
test('complete native schema and bounded children',()=>assert.equal(count,JSON.parse(readFileSync('scene-inventory.json')).controls));
test('R2 lost layer title cannot regress to clipped 35px native box',()=>{const n=byName.get('figmaTitle');for(const t of Object.values(n.transformByPlatform))assert(t.size.y>=50);assert.equal(n.fontSize,24)});
test('token preserves rotated native square diamond shell rather than whole-star substitution',()=>{const n=byName.get('tokenOuter');assert.equal(n.children[0].imageId,100001);for(const t of Object.values(n.children[0].transformByPlatform))assert.equal(t.rotation.z,45)});
test('single source script exactly equals save inline Lua',()=>assert.equal(save.assets.scripts[0].source,readFileSync('scene.generated.lua','utf8')));
test('fixture does not call unsupported native coroutine API',()=>assert.doesNotMatch(readFileSync('scene.lua','utf8')+readFileSync('scenario.lua','utf8'),/\bcoroutine\s*\./));
test('readonly notice and return share the same scaled stage',()=>{const stage=byName.get('stage');assert(stage.children.some(c=>c.name==='previewReturn'),'return must not live in unscaled mapRoot');});
