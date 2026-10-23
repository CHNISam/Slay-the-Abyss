import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { compareNativeCandidate, requireSourceSha } from '../scripts/native-candidate-audit.mjs';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/native-candidate-audit/readback-slice.json', import.meta.url)));
function audit(change = () => {}) {
  const input = structuredClone({ ...fixture, sourceSha: fixture.provenance.sourceCommit,
    candidateBefore: fixture.provenance.candidateSha256, candidateAfter: fixture.provenance.candidateSha256, bgm: true });
  change(input); return compareNativeCandidate(input);
}
function firstText(controls) {
  for (const control of controls) {
    if (control.text?.content) return control;
    const found = firstText(control.children ?? []);
    if (found) return found;
  }
}
test('interface identity, visibility and every root input flag must match source defaults', () => {
  for (const change of [
    input => { input.actual.ui.interface.hidden = true; },
    input => { input.actual.ui.interface.name = 'WrongUi'; },
    ...['showCursor', 'blockKeys', 'blockCursor'].map(flag => input => { delete input.actual.ui.interface[flag]; }),
    input => { input.actual.ui.interface.isolateNavigation = true; },
    input => { input.actual.ui.interface.extraInputSetting = true; },
  ]) {
    const report = audit(change);
    assert.ok(report.issues.some(issue => issue.code === 'INTERFACE_MISMATCH'), JSON.stringify(report.issues));
  }
  assert.deepEqual(audit(input => {
    input.actual.ui.interface.hidden = false;
    input.actual.ui.interface.isolateNavigation = false;
  }).issues, [], 'explicit false equals the native omitted default');
});
test('hex colour spelling is tolerated only in colour fields, never text or control/interface names', () => {
  for (const change of [
    input => { firstText(input.expected.ui.controls).text.content = '#AABBCC'; firstText(input.actual.ui.interface.controls).text.content = '#aabbcc'; },
    input => { input.expected.ui.controls[0].name = '#AABBCC'; input.actual.ui.interface.controls[0].name = '#aabbcc'; },
    input => { input.expected.ui.name = '#AABBCC'; input.actual.ui.interface.name = '#aabbcc'; },
    input => {
      input.expected.ui.controls[1].children.find(control => control.kind === 'grid').itemTemplate = '#AABBCC';
      input.actual.ui.interface.controls[1].children.find(control => control.kind === 'grid').itemTemplate = '#aabbcc';
    },
    input => {
      input.expected.ui.script = { name: 'abyss_ui', values: { colour: '#AABBCC' } };
      input.actual.ui.interface.scripts = [{ name: 'abyss_ui', values: { colour: '#aabbcc' } }];
    },
  ]) assert.ok(audit(change).issues.length);
  assert.deepEqual(audit(input => {
    input.expected.ui.controls[0].colour = '#AABBCC'; input.actual.ui.interface.controls[0].colour = '#aabbcc';
  }).issues, []);
});
test('real readback slice matches fixed source, CRLF and implicit platform defaults', () => {
  const report = audit();
  assert.deepEqual(report.issues, []);
  assert.equal(report.modules[0].sourceTextIdentical, true);
  assert.notEqual(report.modules[0].actualSha256, report.modules[0].expectedSha256);
  assert.equal(report.ui.actualCount, report.ui.expectedCount);
  assert.equal(report.playtest, 'NOT_TESTED');
  assert.deepEqual(audit(input => { input.actual.scripts.scripts[0].source = '\uFEFF' + input.actual.scripts.scripts[0].source; }).issues, []);
});
test('bad module, missing/extra module and wrong UI geometry cannot pass a static-clean candidate', () => {
  for (const change of [
    input => { input.actual.scripts.scripts[0].source += '\nreturn false'; },
    input => { input.actual.scripts.scripts = []; },
    input => { input.actual.scripts.scripts.push({ ...input.actual.scripts.scripts[0], name: 'stale_fixture' }); },
    input => { input.actual.ui.interface.controls[0].size[0] += 1; },
    input => { input.actual.ui.interface.controls.reverse(); },
    input => { input.actual.template.template.children[0].kind = 'image'; },
  ]) assert.ok(audit(change).issues.length);
});
test('candidate hash changes, static faults and unmounted or wrong-signal graphs fail', () => {
  for (const change of [
    input => { input.candidateAfter = '0'.repeat(64); },
    input => { input.actual.checked.errors = 1; input.actual.checked.ok = false; },
    input => { input.actual.inspected.entities[0].graphMounts[0].enabled = 0; },
    input => { input.actual.inspected.entities[0].templateId = 1000000; },
    input => { input.actual.inspected.graphs[0].signalReferences[0].name = 'WRONG_SIGNAL'; },
  ]) assert.ok(audit(change).issues.length);
});
test('BGM requires both real native parameter records true and explicit BGM opt-in', () => {
  assert.ok(audit(input => { input.actual.parameters.records[0].value = false; }).issues.length);
  assert.ok(audit(input => { input.actual.parameters.records.pop(); }).issues.length);
  assert.ok(audit(input => { input.bgm = false; }).issues.length);
});
test('source SHA is mandatory, complete and hexadecimal; unrelated label is never accepted', () => {
  assert.equal(requireSourceSha(fixture.provenance.sourceCommit), fixture.provenance.sourceCommit);
  for (const sha of [undefined, '', 'cf6969e', 'HEAD', 'x'.repeat(40), '--help']) assert.throws(() => requireSourceSha(sha));
});
