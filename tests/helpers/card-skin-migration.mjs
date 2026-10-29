import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
import assert from 'node:assert/strict';
import{readFileSync}from'node:fs';import{gunzipSync}from'node:zlib';import{createHash}from'node:crypto';
const hash=x=>createHash('sha256').update(x).digest('hex');
const bytes=readFileSync('docs/design/evidence/card-face/source-migration.json.gz');
assert.equal(hash(bytes),"6f3cbd1ac94a0588d8dd991608ea09aef7fb91b5716e889d14a34b543d16bf3a");
export const cardSkinMigration=JSON.parse(gunzipSync(bytes));
// Test-only exact inverse. Historical traces retain their complete original sources.
export function beforeCardSkin(path,source){
 if(Object.hasOwn(cardSkinMigration.beforeSources,path))source=preAcceptedPr323Source(path,source);
 if(source===null||!Object.hasOwn(cardSkinMigration.beforeSources,path))return source;
 const text=source.replaceAll('\r\n','\n'),before=cardSkinMigration.beforeSources[path];
 assert([cardSkinMigration.afterSha256[path],hash(before)].includes(hash(text)),'unreviewed integrated retirement source drift (card skin inverse): '+path);
 return before;
}
