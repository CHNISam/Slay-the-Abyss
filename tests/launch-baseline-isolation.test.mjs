import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,realpathSync,rmSync,symlinkSync,cpSync} from 'node:fs';
import {join,resolve,relative,isAbsolute} from 'node:path';
import {launchBaselineFixture} from './helpers/launch-baseline-fixture.mjs';
import {deliveryHistoricalPaths,materializeBeforeDelivery} from './helpers/delivery-source-composition.mjs';

test('launch replay owns projected test files and still rejects a live tests junction without writes',()=>{
 const paths=deliveryHistoricalPaths('pre379').filter(path=>path.startsWith('tests/'));
 assert.ok(paths.length>0,'delivery replay includes test source owners');
 const original=new Map(paths.map(path=>[path,readFileSync(path)]));
 const root=launchBaselineFixture(),canonical=realpathSync(root);
 for(const path of paths){
  const actual=realpathSync(join(root,path)),within=relative(canonical,actual);
  assert.ok(within&&!within.startsWith('..')&&!isAbsolute(within),'projected test stays in copied tree: '+path);
  assert.notEqual(actual,realpathSync(path));
  assert.deepEqual(readFileSync(path),original.get(path),'historical replay cannot edit live tests');
 }
 // Reset the other replay layers so the negative exercises containment itself.
 for(const directory of ['data','src','scripts','config','tools'])cpSync(directory,join(root,directory),{recursive:true});
 const owner=join(root,'src/lua/abyss_game_ui.lua'),before=readFileSync(owner);
 rmSync(join(root,'tests'),{recursive:true,force:true});
 symlinkSync(resolve('tests'),join(root,'tests'),'junction');
 assert.throws(()=>materializeBeforeDelivery(root),/integrated destination stays in isolated copy/);
 assert.deepEqual(readFileSync(owner),before,'reject alias before writing any historical owner');
 for(const path of paths)assert.deepEqual(readFileSync(path),original.get(path),'rejected alias cannot edit live tests');
});
