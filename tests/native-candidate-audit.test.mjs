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

test('native omitted opaque white text matches explicit white, while other missing colours fail', () => {
  assert.deepEqual(audit(input => {
    firstText(input.expected.ui.controls).text.colour = '#FFFFFF';
    delete firstText(input.actual.ui.interface.controls).text.colour;
  }).issues, []);
  for (const colour of ['#ECE6DA', '#000000', '#fffffe']) {
    const report = audit(input => {
      firstText(input.expected.ui.controls).text.colour = colour;
      delete firstText(input.actual.ui.interface.controls).text.colour;
    });
    assert.ok(report.issues.some(issue => issue.code === 'UI_MISMATCH'));
  }
  assert.ok(audit(input => {
    firstText(input.expected.ui.controls).text.colour = '#FFFFFF';
    delete firstText(input.actual.ui.interface.controls).text.colour;
    firstText(input.actual.ui.interface.controls).text.opacity = 0.8;
  }).issues.some(issue => issue.code === 'UI_MISMATCH'));
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
test('ordinary source that declares BGM disabled requires two correctly typed false records', () => {
  const ordinary = change => audit(input => {
    input.bgm = false;
    input.expected.uiBgmParameter = { name: 'nativeBgmEnabled', type: 'boolean', value: false };
    input.expected.graphs = input.expected.graphs.filter(graph => graph.name !== '_GSTS_ABYSS_BGM');
    input.actual.inspected.graphs = input.actual.inspected.graphs.filter(graph => graph.name !== '_GSTS_ABYSS_BGM');
    for (const parameter of input.actual.parameters.records) parameter.value = false;
    change?.(input);
  });
  assert.deepEqual(ordinary().issues, []);
  for (const change of [
    input => { input.actual.parameters.records = []; },
    input => { input.actual.parameters.records.pop(); },
    input => { input.actual.parameters.records[0].type = 1; },
    input => { input.actual.parameters.records[0].code = 1; },
    input => { input.actual.parameters.records[0].section = 8; },
    input => { input.actual.parameters.records[0].value = true; },
  ]) assert.ok(ordinary(change).issues.some(issue => issue.code === 'BGM_PARAMETER'));
  assert.deepEqual(ordinary(input => { delete input.expected.uiBgmParameter; input.actual.parameters.records = []; }).issues, [], 'older source without parameter remains auditable');
});
test('source SHA is mandatory, complete and hexadecimal; unrelated label is never accepted', () => {
  assert.equal(requireSourceSha(fixture.provenance.sourceCommit), fixture.provenance.sourceCommit);
  for (const sha of [undefined, '', 'cf6969e', 'HEAD', 'x'.repeat(40), '--help']) assert.throws(() => requireSourceSha(sha));
});

test('native image and text alpha use exact ARGB byte encoding, including opaque defaults', () => {
  for (const opacity of [0, 0.001, 0.16, 0.32, 0.45, 0.5, 0.55, 0.85, 0.96, 0.999, 1]) {
    const decoded = Math.round(opacity * 255) / 255;
    assert.deepEqual(audit(input => {
      input.expected.ui.controls[0].opacity = opacity;
      input.actual.ui.interface.controls[0].opacity = decoded;
      const source = firstText(input.expected.ui.controls).text;
      const actual = firstText(input.actual.ui.interface.controls).text;
      source.background = actual.background = '#000000';
      source.outlineColour = actual.outlineColour = '#000000';
      for (const field of ['opacity', 'backgroundOpacity', 'outlineOpacity']) {
        source[field] = opacity; actual[field] = decoded;
      }
      if (decoded === 1) {
        delete input.actual.ui.interface.controls[0].opacity;
        delete actual.opacity;
      }
    }).issues, [], `alpha ${opacity}`);
  }
});

test('alpha encoding cannot hide wrong bytes, invalid readback or unrelated float changes', () => {
  for (const change of [
    input => { input.expected.ui.controls[0].opacity = 0.5; input.actual.ui.interface.controls[0].opacity = 127 / 255; },
    input => { input.expected.ui.controls[0].opacity = 0.5; input.actual.ui.interface.controls[0].opacity = 0.5; },
    input => { input.expected.ui.controls[0].opacity = 1; input.actual.ui.interface.controls[0].opacity = 0.999; },
    ...[-0.1, 1.1, NaN, Infinity].map(value => input => { input.expected.ui.controls[0].opacity = 0.5; input.actual.ui.interface.controls[0].opacity = value; }),
    ...['opacity', 'backgroundOpacity', 'outlineOpacity'].map(field => input => {
      firstText(input.expected.ui.controls).text.background = firstText(input.actual.ui.interface.controls).text.background = '#000000';
      firstText(input.expected.ui.controls).text.outlineColour = firstText(input.actual.ui.interface.controls).text.outlineColour = '#000000';
      firstText(input.expected.ui.controls).text[field] = 0.5;
      firstText(input.actual.ui.interface.controls).text[field] = 127 / 255;
    }),
    input => { firstText(input.expected.ui.controls).text.fontSize = 0.5; firstText(input.actual.ui.interface.controls).text.fontSize = 128 / 255; },
    input => {
      input.expected.ui.controls[0].unknown = { opacity: 0.5 };
      input.actual.ui.interface.controls[0].unknown = { opacity: 128 / 255 };
    },
    input => {
      input.expected.ui.script = { name: 'abyss_ui', values: { opacity: 0.5 } };
      input.actual.ui.interface.scripts = [{ name: 'abyss_ui', values: { opacity: 128 / 255 } }];
    },
  ]) assert.ok(audit(change).issues.length);
});
