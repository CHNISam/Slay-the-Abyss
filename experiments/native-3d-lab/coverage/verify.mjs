import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {dirname,resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {proposalFor,assignmentIds,phases} from './mapping.mjs';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../../..');
const report=JSON.parse(readFileSync(join(here,'enemy-coverage.json')));
const rows=readFileSync(join(here,'catalog.tsv'),'utf8').trim().split(/\r?\n/).map(line=>line.split('\t')[0]);
assert.equal(rows.length,67);assert.deepEqual(report.enemies.map(r=>r.internalId),rows);
assert.deepEqual([...assignmentIds].sort(),[...rows].sort());
assert.equal(new Set(report.enemies.map(r=>r.internalId)).size,67);
for(const row of report.enemies){assert.equal(row.ruleMutation,false);assert.equal(row.runtimeStatus,'runtime-unverified');assert(existsSync(join(root,row.definitionSource)));assert.deepEqual(row.reuseGroup,proposalFor(row.internalId).reuseGroup);}
for(const phase of phases){assert(rows.includes(phase.enemyId));assert(existsSync(join(root,phase.source)));}
for(const source of report.summary.sources)assert.equal(createHash('sha256').update(readFileSync(join(root,source.path))).digest('hex'),source.sha256,source.path);
for(const id of ['acid_slime_s','spike_slime_s','torch_head','bronze_orb','snake_dagger','jaw_worm_hard','spire_shield','spire_spear','corrupt_heart'])assert(rows.includes(id),id);
assert.equal(report.summary.nativeModelCandidates+report.summary.keepShapes,67);
assert.equal(report.summary.readAnimationCandidates+report.summary.structuralOnly,report.summary.nativeModelCandidates);
assert.throws(()=>proposalFor('invented_second_form'),/Unmapped/);
console.log('coverage verified: exact 67-definition catalog; summons, four-act variants and phase references included; no rule writes');
