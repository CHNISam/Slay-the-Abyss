// Keep the adopted browser design's resource and state contracts in Full CI.
// These checks do not certify native UI or physical-device behavior.
import '../docs/design/reference-ui-lab/map-topology.test.mjs';
import '../docs/design/reference-ui-lab/public-assets.test.mjs';
import '../docs/design/reference-ui-lab/result-model.test.mjs';

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {checkAssets,sensitive} from '../scripts/check-license.mjs';

test('adopted public media have exact provenance inventory entries',()=>{
 const root=fileURLToPath(new URL('..',import.meta.url));const prefix='docs/design/reference-ui-lab/';
 const paths=readdirSync(new URL('../'+prefix,import.meta.url)).map(name=>prefix+name).filter(sensitive);
 const inventory=JSON.parse(readFileSync(new URL('../docs/legal/assets.json',import.meta.url),'utf8'));
 const files=Object.fromEntries(Object.entries(inventory.files).filter(([path])=>path.startsWith(prefix)));
 assert.ok(paths.length>0);assert.deepEqual(checkAssets(root,paths,{...inventory,files}),[]);
});
