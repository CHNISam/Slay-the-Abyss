import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { compareNativeCandidate } from '../scripts/native-candidate-audit.mjs';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/native-candidate-audit/readback-slice.json', import.meta.url)));
function audit(change) {
  const input = structuredClone({ ...fixture, sourceSha: fixture.provenance.sourceCommit,
    candidateBefore: fixture.provenance.candidateSha256, candidateAfter: fixture.provenance.candidateSha256, bgm: true });
  change(input);
  return compareNativeCandidate(input);
}
function rejects(change, code) {
  const result = audit(change);
  assert.equal(result.ok, false);
  assert.ok(result.issues.some(issue => issue.code === code), JSON.stringify(result.issues));
}

test('root script parameters and unknown metadata never inherit geometry tolerance', () => {
  for (const key of ['threshold', 'position', 'opacity']) rejects(input => {
    input.expected.ui.script = { name: 'abyss_ui', values: { [key]: 0 } };
    input.actual.ui.interface.scripts = [{ name: 'abyss_ui', values: { [key]: 0.00005 } }];
  }, 'INTERFACE_MISMATCH');
  rejects(input => {
    input.expected.ui.unknown = { position: [1, 2] };
    input.actual.ui.interface.unknown = { position: [1.00005, 2] };
  }, 'INTERFACE_MISMATCH');
});

test('discrete UI IDs and grid counts compare exactly', () => {
  rejects(input => { input.actual.ui.interface.controls[0].image += 0.00005; }, 'UI_MISMATCH');
  rejects(input => { input.actual.ui.interface.controls[1].children.find(control => control.grid).grid.columns += 0.00005; }, 'UI_MISMATCH');
});

test('opaque control and template metadata remain exact even with geometry-like field names', () => {
  for (const template of [false, true]) rejects(input => {
    const source = template ? input.expected.template : input.expected.ui.controls[0];
    const actual = template ? input.actual.template.template : input.actual.ui.interface.controls[0];
    source.script = { values: { position: [0, 0], opacity: 0 } };
    actual.script = { values: { position: [0.00005, 0], opacity: 0 } };
  }, template ? 'TEMPLATE_MISMATCH' : 'UI_MISMATCH');
});

test('documented native UI float fields retain finite precision tolerance', () => {
  for (const change of [
    input => { input.actual.ui.interface.controls[0].size[0] += 0.00005; },
    input => { input.actual.ui.interface.controls[1].children[3].position[1] += 0.00005; },
    input => { input.actual.ui.interface.controls[1].children[3].text.fontSize += 0.00005; },
    input => { input.actual.ui.interface.controls[1].children[3].text.minFontSize += 0.00005; },
    ...['itemSize', 'spacing', 'padding'].map(field => input => { input.actual.ui.interface.controls[1].children.find(control => control.grid).grid[field][0] += 0.00005; }),
    input => { input.actual.template.template.children[0].size[0] += 0.00005; },
  ]) assert.deepEqual(audit(change).issues, []);
  rejects(input => { input.actual.ui.interface.controls[0].size[0] += 0.001; }, 'UI_MISMATCH');
  rejects(input => { input.actual.ui.interface.controls[0].size[0] = Infinity; }, 'UI_MISMATCH');
  rejects(input => { input.actual.ui.interface.controls[1].children[0].opacity += 0.00005; }, 'UI_MISMATCH');
});

for (const value of [undefined, null, 0, -1, 0.5, 22.5, NaN, Infinity, -Infinity, '22', 'invalid', Number.MAX_SAFE_INTEGER + 1]) {
  test(`graph nodeCount rejects ${String(value)} instead of certifying nonempty payload`, () => {
    rejects(input => { input.actual.inspected.graphs[0].nodeCount = value; }, 'GRAPH_MISSING');
  });
}
test('missing graph nodeCount fails closed; positive safe integer remains accepted', () => {
  rejects(input => { delete input.actual.inspected.graphs[0].nodeCount; }, 'GRAPH_MISSING');
  assert.deepEqual(audit(input => { input.actual.inspected.graphs[0].nodeCount = 1; }).issues, []);
});
