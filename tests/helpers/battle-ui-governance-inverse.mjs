import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
// Exact metadata inverse for temporary historical replay; live gates read the real configs.
import assert from 'node:assert/strict';
import {readFileSync}from'node:fs';
import {createHash}from'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(normalize(s)).digest('hex');
const bytes=readFileSync(new URL('../fixtures/battle-ui-governance-inverse.json',import.meta.url),'utf8');
assert.equal(hash(bytes),'392785f4aa6d63795bbd42c9cb354339a175deddc0aa3bcd79a273e43e217e1f','complete additive Battle governance inverse identity');
const layer=JSON.parse(bytes);
export function tryBattleGovernanceSource(path,source){
 source=preAcceptedPr323Source(path,source);
 const binding=layer.files[path];
 if(!binding||source===null||hash(source)!==binding.afterSha256)return undefined;
 assert.equal(hash(binding.before),binding.approvedBeforeSha256,'complete approved governance witness');
 return binding.before;
}
