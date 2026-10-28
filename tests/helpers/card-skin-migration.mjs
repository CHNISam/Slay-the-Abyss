import assert from 'node:assert/strict';
import{readFileSync}from'node:fs';import{gunzipSync}from'node:zlib';import{createHash}from'node:crypto';
const hash=x=>createHash('sha256').update(x).digest('hex');
const bytes=readFileSync('docs/design/evidence/card-face/source-migration.json.gz');
assert.equal(hash(bytes),'8f57a52636d850e31909627321df53b18a789e65b4adfe80df4a31053bbe7259');
export const cardSkinMigration=JSON.parse(gunzipSync(bytes));
// Test-only exact inverse. Historical traces retain their complete original sources.
export function beforeCardSkin(path,source){
 if(source===null||!Object.hasOwn(cardSkinMigration.beforeSources,path))return source;
 const text=source.replaceAll('\r\n','\n'),before=cardSkinMigration.beforeSources[path];
 assert([cardSkinMigration.afterSha256[path],hash(before)].includes(hash(text)),'unreviewed integrated retirement source drift (card skin inverse): '+path);
 return before;
}
