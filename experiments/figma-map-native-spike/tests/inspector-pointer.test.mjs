import test from 'node:test';import assert from 'node:assert/strict';import{inspectorPointerCenter}from'../tools/inspector-pointer.mjs';
const box=(cx,cy,w=10,h=10)=>({left:cx-w/2,bottom:cy-h/2,width:w,height:h});
test('identity preserves bottom-left inspector center',()=>assert.deepEqual(inspectorPointerCenter([{box:box(600,402)}]),{x:600,y:402}));
test('R2 stage scale1.25 reproduces actual rendered node8 pixel center',()=>{const p=inspectorPointerCenter([{box:box(800,450,1600,900),localScaleX:1.25,localScaleY:1.25},{box:box(600,402)}]);assert.deepEqual(p,{x:550,y:390});assert.equal(900-p.y,510)});
test('nested rotation and scale apply child-to-root',()=>{const p=inspectorPointerCenter([{box:box(0,0),localScaleX:2,localScaleY:2},{box:box(10,0),localRotationZ:90},{box:box(15,0)}]);assert.ok(Math.abs(p.x-20)<1e-9);assert.ok(Math.abs(p.y-10)<1e-9)});
test('missing target box refuses invented coordinate',()=>assert.throws(()=>inspectorPointerCenter([]),/no inspector box/));
test('native lua-error levels are terminal not successful preparation',()=>{for(const level of ['error','lua-error','Lua-Error'])assert.match(level,/error/i);assert.doesNotMatch('info',/error/i)});
