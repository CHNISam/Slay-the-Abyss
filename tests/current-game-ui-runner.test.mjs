import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {currentGameUiFixture,currentGameUiGroups,currentGameUiNames,validateCurrentGameUiGroups,inspectCurrentGameUiSource,verifyCurrentGameUiGroup,runCurrentGameUi} from './helpers/current-game-ui-runner.mjs';
const source=readFileSync(currentGameUiFixture,'utf8').replaceAll('\r\n','\n');
const output=group=>group.map(i=>`CURRENT_GAME_UI_CASE\t${i}\t${currentGameUiNames[i-1]}`).join('\n')+`\nLUA_GAME_UI_GROUP_PASS ${group.length}\n`;
test('current entry grouping locks the original exact 16 identities and full bodies including seeds',()=>{
 assert.equal(inspectCurrentGameUiSource(source).length,16);
 assert.equal(inspectCurrentGameUiSource(source.replaceAll('\n','\r\n')).length,16);
 assert.throws(()=>inspectCurrentGameUiSource(source.replace('version.visible and version.text','not version.visible and version.text')),/complete case bodies/);
 assert.throws(()=>inspectCurrentGameUiSource(source.replace('test("menu shows','notATest("menu shows')),/exact 16/);
 assert.throws(()=>inspectCurrentGameUiSource(source.replace(currentGameUiNames[1],currentGameUiNames[0])),/case identities/);
});
test('plans reject missing, duplicate, reordered and empty original groups',()=>{
 validateCurrentGameUiGroups(currentGameUiGroups);
 for(const plan of [currentGameUiGroups.slice(1),[...currentGameUiGroups,[16]],[[2,1,3,4],...currentGameUiGroups.slice(1)],[[],...currentGameUiGroups]])assert.throws(()=>validateCurrentGameUiGroups(plan));
});
test('group receipts reject missing, duplicate, skipped, renamed and fabricated total markers',()=>{
 const group=currentGameUiGroups[0],good=output(group);verifyCurrentGameUiGroup(good,group);
 for(const bad of [output(group.slice(1)),good+`CURRENT_GAME_UI_CASE\t1\t${currentGameUiNames[0]}\n`,good.replace('CURRENT_GAME_UI_CASE\t2','CURRENT_GAME_UI_CASE\t3'),good.replace(currentGameUiNames[0],'renamed'),good+'LUA_GAME_UI_PASS 16\n',good+`LUA_GAME_UI_GROUP_PASS ${group.length}\n`])assert.throws(()=>verifyCurrentGameUiGroup(bad,group));
});
test('real wrapper producer covers all groups once under one decreasing original deadline',()=>{
 let calls=0,last=60001;
 const result=runCurrentGameUi((wrapper,options)=>{
  const group=currentGameUiGroups[calls++];
  assert(readFileSync(wrapper,'utf8').includes('ABYSS_CURRENT_ENTRY_GROUP='+toLua(group)));
  assert(options.timeout>0&&options.timeout<=last);last=options.timeout;
  return {status:0,stdout:output(group),stderr:'',signal:null};
 },currentGameUiFixture);
 assert.equal(calls,4);assert.equal(result.status,0);
 assert.equal(result.stdout.match(/^CURRENT_GAME_UI_CASE\t/gm).length,16);
 assert.equal(result.stdout.match(/^LUA_GAME_UI_PASS 16$/gm).length,1);
});
test('aggregate refuses a child failure or skipped group rather than certifying 16',()=>{
 const failed=runCurrentGameUi(()=>({status:1,stdout:'',stderr:'deliberate'}),currentGameUiFixture);
 assert.equal(failed.status,1);assert.doesNotMatch(failed.stdout,/LUA_GAME_UI_PASS 16/);
 assert.throws(()=>runCurrentGameUi(()=>({status:0,stdout:output(currentGameUiGroups[1]),stderr:''}),currentGameUiFixture),/missing, duplicate/);
});
test('startup and child execution consume the same total budget, never four new deadlines',()=>{
 assert.throws(()=>runCurrentGameUi(()=>{Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,20);return {status:0,stdout:output(currentGameUiGroups[0]),stderr:''};},currentGameUiFixture,{timeout:10}),/total deadline exhausted/);
 for(const timeout of [0,-1,60001,Infinity])assert.throws(()=>runCurrentGameUi(()=>{throw Error('must not run')},currentGameUiFixture,{timeout}),/deadline cannot be extended/);
 assert.throws(()=>runCurrentGameUi(()=>{},currentGameUiFixture,{caseName:'only-one'}),/all original/);
});
