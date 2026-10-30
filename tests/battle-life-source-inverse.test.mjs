import {preRound2UiSource,round2UiAddedPaths,prepareRound2UiModuleRetirement} from './helpers/round2-ui-source-inverse.mjs';
import test from 'node:test';
import {preRelicCompletionSource} from './helpers/relic-completion-inverse.mjs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {tmpdir} from 'node:os';
import {battleLifeSourceLayer as proof, battleLifeAddedPaths, preBattleLifeSource, preBattleLifeOuterSource,
  prepareBattleLifeModuleRetirement} from './helpers/battle-life-source-inverse.mjs';
import {pr323AcceptedSourceInverse, requirePr323Source, preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import {preCombatVfxUpgradeSource} from './helpers/combat-vfx-upgrade-inverse.mjs';
import {eventProductionInverse, requireEventProductionSource} from './helpers/event-production-source-inverse.mjs';

const hash = value => value === null ? null : createHash('sha256').update(value).digest('hex');
const read = path => preBattleLifeOuterSource(path,readFileSync(path, 'utf8').replaceAll('\r\n', '\n'));
const put = (directory, path, content) => {
  const target = join(directory, path); mkdirSync(dirname(target), {recursive: true}); writeFileSync(target, content);
};

test('battle-life inverse recovers exact complete base sources and preserves genuine module absence', () => {
  assert.ok(Object.keys(proof.files).length > 0);
  for (const [path, binding] of Object.entries(proof.files)) {
    const live = read(path), previous = preBattleLifeSource(path, live);
    assert.equal(hash(live), binding.afterSha256, 'frozen live source: ' + path);
    assert.equal(hash(previous), binding.beforeSha256, 'complete base source: ' + path);
    assert.equal(preBattleLifeSource(path, live.replaceAll('\n', '\r\n')), previous, 'native CRLF: ' + path);
    assert.equal(preBattleLifeSource(path, previous), previous, 'idempotent base source: ' + path);
    assert.equal(preAcceptedPr323Source(path, live) === null, binding.beforeSha256 === null,
      'new modules stay absent through old composition: ' + path);
    if (pr323AcceptedSourceInverse.files[path]) requirePr323Source(path, live);
    if (eventProductionInverse.files[path]) requireEventProductionSource(path, live);
  }
});

test('partial, foreign and future source bytes remain visible to unchanged strict guards', () => {
  for (const [path, binding] of Object.entries(proof.files)) {
    const live = read(path);
    for (const mutant of [live + '\n-- unknown future change\n', live.slice(1), 'return {}\n']) {
      assert.equal(preBattleLifeSource(path, mutant), mutant, 'no wildcard projection: ' + path);
      if (pr323AcceptedSourceInverse.files[path]) assert.throws(() => requirePr323Source(path, mutant), /unreviewed integrated/);
      if (eventProductionInverse.files[path]) assert.throws(() => requireEventProductionSource(path, mutant), /unreviewed integrated/);
    }
    assert.equal(preBattleLifeSource(path, undefined), undefined);
    if (binding.beforeSha256 === null) assert.equal(preAcceptedPr323Source(path, live), null);
  }
  assert.equal(preBattleLifeSource('src/lua/unregistered.lua', 'return {}\n'), 'return {}\n');
});

test('historical cleanup removes only complete new modules after validating the whole inventory', () => {
  assert.ok(battleLifeAddedPaths.length > 0);
  const directory = mkdtempSync(join(tmpdir(), 'abyss-battle-life-inverse-'));
  try {
    put(directory, 'keep.txt', 'keep');
    for (const path of battleLifeAddedPaths) put(directory, path, read(path));
    const last = battleLifeAddedPaths.at(-1);
    put(directory, last, read(last) + '\n-- unknown destination\n');
    assert.throws(() => prepareBattleLifeModuleRetirement(directory), /unreviewed battle-life added module destination/);
    for (const path of battleLifeAddedPaths) assert.ok(existsSync(join(directory, path)), 'failed validation deleted ' + path);
    put(directory, last, read(last));
    const retire = prepareBattleLifeModuleRetirement(directory);
    for (const path of battleLifeAddedPaths) assert.ok(existsSync(join(directory, path)), 'preparation performed deletion');
    retire();
    for (const path of battleLifeAddedPaths) assert.equal(existsSync(join(directory, path)), false);
    assert.equal(readFileSync(join(directory, 'keep.txt'), 'utf8'), 'keep');
    prepareBattleLifeModuleRetirement(directory)();
    assert.throws(() => prepareBattleLifeModuleRetirement(process.cwd()), /separate historical destination/);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('round-two copied responsibilities retire atomically with the existing historical module cleanup',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-round2-ui-inverse-'));
 try{
  for(const path of [...battleLifeAddedPaths,...round2UiAddedPaths])put(directory,path,readFileSync(path,'utf8'));
  put(directory,'keep.txt','keep');
  const last=round2UiAddedPaths.at(-1);
  put(directory,last,readFileSync(last,'utf8')+'\n-- drift\n');
  assert.throws(()=>prepareBattleLifeModuleRetirement(directory),/unreviewed round-two UI added module destination/);
  for(const path of [...battleLifeAddedPaths,...round2UiAddedPaths])assert.ok(existsSync(join(directory,path)),'no removal before all identities validate');
  put(directory,last,readFileSync(last,'utf8'));
  const retire=prepareBattleLifeModuleRetirement(directory);
  for(const path of round2UiAddedPaths)assert.ok(existsSync(join(directory,path)),'preparation must not remove copied UI module');
  retire();
  for(const path of [...battleLifeAddedPaths,...round2UiAddedPaths])assert.equal(existsSync(join(directory,path)),false,'only validated new module removed');
  assert.equal(readFileSync(join(directory,'keep.txt'),'utf8'),'keep');
  prepareRound2UiModuleRetirement(directory)();
  assert.throws(()=>prepareRound2UiModuleRetirement(process.cwd()),/separate historical destination/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
