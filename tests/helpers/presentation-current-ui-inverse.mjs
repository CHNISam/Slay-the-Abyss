import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

const hash = value => createHash('sha256').update(value).digest('hex');
const bytes = readFileSync('tests/fixtures/presentation-current-ui-inverse.json.gz');
assert.equal(hash(bytes), 'db61265d1133a98c077bc155a4254a7e3565d4c96324eba17a28f9f9f25b382a');
export const integratedUiSources = JSON.parse(gunzipSync(bytes));

// The two health repairs sit after Task77's immutable source bindings. Its
// historical layer must still prove those original bytes, while the live trace
// below independently checks the repaired production sources.
export function beforeUiHealthRepair(path, source) {
  const text = source.replaceAll('\r\n', '\n');
  let before, expected;
  if (path === 'data/presentation/ui_theme.json' && hash(text) === 'b73b66261a053ca31edad7d68f1ac93eb522e73447c727ae9436f8a3c86446e1') {
    before = text.replace('"enemyRow": {\n      "y": 44,', '"enemyRow": {\n      "y": 64,');
    expected = 'e0e9a35f5f284f486b01542ef0f124c2a3a4ea2234c23890398266e8f4b54ac4';
  } else if (path === 'src/lua/abyss_battle_intent_view.lua' && hash(text) === '876117c6bada615fe3c07c11142dd533c81ee91d69ac1c0a880d0c38d6bf327c') {
    before = text.replace("    -- A source UNKNOWN face stays unknown even when its help explains a\n    -- supported summon effect. Detail rows must not reveal a replacement face.\n    if face.kind == 'unknown' then return {'unknown'} end\n", '');
    expected = '61c236146d14861542ac6c7a610ffe0531723d5804e0c8aea15cb82eb1447abf';
  } else return text;
  assert.equal(hash(before), expected, 'complete pre-repair UI identity recovered');
  return before;
}

// Historical replay only: exact, complete source identities bind every hunk.
// Existing formal-entry/content inverses remain responsible for earlier layers.
export function preIntegratedUiSource(path, source) {
  if (source === null) return source;
  const normalized = source.replaceAll('\r\n', '\n');
  const binding = integratedUiSources.files[path];
  if (!binding || hash(normalized) !== binding.afterSha256) return normalized;
  const lines = normalized.split('\n');
  for (const edit of [...binding.edits].reverse()) {
    assert.deepEqual(lines.slice(edit.at, edit.at + edit.after.length), edit.after);
    lines.splice(edit.at, edit.after.length, ...edit.before);
  }
  const before = lines.join('\n');
  assert.equal(hash(before), binding.beforeSha256, 'complete historical UI source recovered: ' + path);
  return before;
}
