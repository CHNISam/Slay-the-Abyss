import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {instrumentCardTween} from './card-tween.mjs';
const require=createRequire(import.meta.url),parse=require('luaparse').parse;
test('candidate transform instruments the real hand lifecycle and leaves production file unchanged',()=>{
 const source=readFileSync('src/lua/abyss_battle_card_view.lua','utf8');
 const output=instrumentCardTween(source);parse(output,{luaVersion:'5.3'});
 assert.match(output,/local nativeOwned=tweenLab:before/);assert.match(output,/if not nativeOwned and not \(held/);
 assert.match(output,/tweenLab:cancel\('drag'\)/);assert.match(output,/tweenLab:cancel\('battle_or_resize'\)/);
 assert.match(output,/tweenLab:removed\(entry\)/);assert.match(output,/TweenLab.recordPaint\(box\)/);
 assert.equal(readFileSync('src/lua/abyss_battle_card_view.lua','utf8'),source);
 assert.throws(()=>instrumentCardTween(source.replace('local M = {}','local M={}')),/anchor changed/);
});
test('experimental tween Lua parses as official Lua 5.3',()=>{
 parse(readFileSync('experiments/native-3d-lab/card-tween.lua','utf8'),{luaVersion:'5.3'});
});
