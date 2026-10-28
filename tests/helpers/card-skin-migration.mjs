import assert from 'node:assert/strict';
import{readFileSync}from'node:fs';import{gunzipSync}from'node:zlib';import{createHash}from'node:crypto';
const hash=x=>createHash('sha256').update(x).digest('hex');
const bytes=readFileSync('docs/design/evidence/card-face/source-migration.json.gz');
assert.equal(hash(bytes),"47a62817005cd149de703f0295e54e7d7c7e46d6d9989b989f7e26f13ee1739b");
export const cardSkinMigration=JSON.parse(gunzipSync(bytes));
// Test-only exact inverse. Historical traces retain their complete original sources.
export function beforeCardSkin(path,source){
 if(source===null||!Object.hasOwn(cardSkinMigration.beforeSources,path))return source;
 const text=source.replaceAll('\r\n','\n'),before=cardSkinMigration.beforeSources[path];
 assert([cardSkinMigration.afterSha256[path],hash(before)].includes(hash(text)),'unreviewed integrated retirement source drift (card skin inverse): '+path);
 return before;
}
