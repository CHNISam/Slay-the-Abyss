import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const hash=source=>createHash('sha256').update(source).digest('hex');
// Only this complete default-policy edit may precede the immutable runner
// witnesses. Unknown or partially edited sources remain exposed to their guards.
export function preLuaTimeoutPolicySource(path,source){
 if(path!=='scripts/test-lua.mjs'||typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 if(hash(normalized)!=="57e1ad1d74a0fb53bc54c9512569f9e22d7630940106cb053f94ff1b25102703")return source;
 const policy=readFileSync(new URL('../../scripts/ci-timeout-policy.mjs',import.meta.url),'utf8').replaceAll('\r\n','\n');
 assert.equal(hash(policy),"86884e7db31c299d1b3e908a9647d46379d958122dd519f52f92f5bce4fd8c3a",'fresh exact Lua timeout policy owner');
 let previous=normalized;
 for(const [after,before]of [
  [
    "import { luaTimeoutMs } from './ci-timeout-policy.mjs';\n",
    ""
  ],
  [
    "  // Default guards include runner overhead and leave generous execution margin.\n  // Explicit caller limits, including deliberate timeout probes, stay unchanged.\n",
    "  // Quality runs 39982640775/39985958741 timed out in three different fixtures\n  // (battle UI, game UI, encounter coverage). Allow 30s per independent script,\n  // 60s for the full battle/host trees; assertions and explicit caller limits remain.\n  // Raw seven-column source maps use limb RNG arithmetic in Fengari. Keep all\n  // 128 seeds and strict restores; these three bounded fixtures need more time.\n  // The composed host runs the real 17-floor route and seven-column/raw-RNG\n  // setup; the unchanged cases exceeded 30s after that production migration.\n"
  ],
  [
    "  timeout ??= normalizedScript.endsWith('tests/lua/encounter_coverage.lua') || mapProperties ? luaTimeoutMs.veryHeavy : fixture || composedHost ? luaTimeoutMs.heavy : luaTimeoutMs.default;",
    "  timeout ??= normalizedScript.endsWith('tests/lua/encounter_coverage.lua') ? 120000 : mapProperties ? 120000 : fixture || composedHost ? 60000 : 30000;"
  ]
]){
  assert.equal(previous.split(after).length,2,'one exact Lua default-policy edit');
  previous=previous.replace(after,before);
 }
 assert.equal(hash(previous),"4bb5621b2bc70bd6a023441a0ef9cb14c1f1897b3104a8f55bbd069c41685fcd",'complete original Lua runner before timeout policy');
 return previous;
}
