import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
import {preRetirementSource,retirementSources} from './helpers/presentation-announcement-retirement.mjs';

const path='data/presentation/ui_theme.json';
const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
test('formal launch and content glyphs compose without changing either historical source',()=>{
 const before=preFormalEntrySource(path,source);
 assert.equal(hash(source),'f88fac509e27f23db8e7f65c50236377fd7c230356695987e51f93881f6ec128');
 assert.equal(hash(before),'992e36ac0923209eb0ae09eac564e2685b0768a5cbbe211762e6b62b723478cf');
 assert.deepEqual(JSON.parse(before).icon.relic,JSON.parse(source).icon.relic);
 assert.equal(preRetirementSource(path,source),retirementSources.beforeSources[path]);
 assert.equal(preRetirementSource(path,source.replaceAll('\n','\r\n')),retirementSources.beforeSources[path]);
});
test('both complete source identities reject missing renamed moved or changed content and launch fields',()=>{
 const moved=JSON.parse(source),glyph=moved.icon.relic.molten_egg;
 delete moved.icon.relic.molten_egg;moved.icon.relic={molten_egg:glyph,...moved.icon.relic};
 for(const mutant of [source.replace('"molten_egg"','"wrong_egg"'),
  source.replace('"odd_mushroom"','"wrong_mushroom"'),
  source.replace('"characterPortraits"','"wrong_portraits"'),
  source.replace('"hutao"','"wrong_character"'),JSON.stringify(moved,null,2)+'\n']){
  assert.throws(()=>preFormalEntrySource(path,mutant),{code:'ERR_ASSERTION'});
  assert.throws(()=>preRetirementSource(path,mutant),{code:'ERR_ASSERTION'});
 }
});
