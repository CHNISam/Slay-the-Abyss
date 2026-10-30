import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {historicalPresentationFixtures} from './helpers/historical-presentation-runner.mjs';
import {bossUiFaultFixture as fixture,preBossUiFaultFixtureSource as project} from './helpers/boss-ui-fault-fixture-inverse.mjs';
import {pr323AcceptedSourceInverse as proof,requirePr323Source,preAcceptedPr323Source,preOriginalPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const current=readFileSync(fixture.path,'utf8').replaceAll('\r\n','\n');

test('one exact Boss fault-input hunk restores its immutable whole source and every PR323 binding still resolves',()=>{
 assert.equal(fixture.hunks.length,1);assert.equal(hash(current),fixture.afterSha256);
 const previous=project(fixture.path,current);assert.equal(hash(previous),fixture.beforeSha256);
 assert.equal(project(fixture.path,current.replaceAll('\n','\r\n')),previous);
 assert.equal(project(fixture.path,previous),previous);
 requirePr323Source(fixture.path,previous);
 assert.equal(proof.files[fixture.path].afterSha256,fixture.beforeSha256);
 for(const [path,binding]of Object.entries(proof.files)){
  const live=readFileSync(path,'utf8');requirePr323Source(path,live);
  for(const [restore,target]of [[preAcceptedPr323Source,'accepted'],[preOriginalPr323Source,'original']])
   assert.equal(restore(path,live),binding[target+'Source'],path+' complete '+target+' witness');
 }
});

test('deleted duplicated moved partial and unrelated Boss edits cannot borrow the reviewed inverse',()=>{
 const hunk=fixture.hunks[0],after=hunk.after.split('\n'),lines=current.split('\n');
 const mutants=[current+'\n-- unrelated drift\n',current.slice(1),current.replace('local count = 0','local count = 1'),current.replace('assert(removed==3','assert(removed==2')];
 for(const replacement of [[],[...after,...after],[hunk.before.split('\n')[0]],['-- partial fault input']]){
  const changed=[...lines];changed.splice(hunk.at,after.length,...replacement);mutants.push(changed.join('\n'));
 }
 const moved=[...lines];moved.splice(hunk.at,after.length);moved.push(...after);mutants.push(moved.join('\n'));
 for(const mutant of mutants){
  assert.notEqual(mutant,current);assert.equal(project(fixture.path,mutant),mutant,'unrecognized bytes remain visible');
  assert.throws(()=>requirePr323Source(fixture.path,mutant),/unreviewed integrated/);
  assert.equal(preAcceptedPr323Source(fixture.path,mutant),mutant);
  assert.equal(preOriginalPr323Source(fixture.path,mutant),mutant);
 }
 assert.equal(project('other.lua',current),current);
 assert.equal(project(fixture.path,null),null);
});

test('current raw Boss UI still executes all seven real production groups including the explicit content fault',()=>{
 assert.ok(!historicalPresentationFixtures.includes(fixture.path));
 buildLuaData();const result=runLua(fixture.path);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_GAME_UI_BOSS_TREASURE 7\/7/);
});
